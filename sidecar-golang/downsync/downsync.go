// Package downsync connects to the backend's /ws/sync endpoint and, for any
// document the local manifest already has synced, pulls down a fresh copy
// whenever someone else changes it - the receiving half of real-time sync,
// complementing uploader's send half.
package downsync

import (
	"docusync-sidecar/auth"
	"docusync-sidecar/manifest"
	localws "docusync-sidecar/websocket"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

type changeEvent struct {
	DocumentId int64  `json:"documentId"`
	VersionId  int64  `json:"versionId"`
	FolderId   *int64 `json:"folderId"`
}

type documentDTO struct {
	Id    int64  `json:"id"`
	Title string `json:"title"`
}

type pageResult struct {
	Content []documentDTO `json:"content"`
	HasNext bool          `json:"hasNext"`
}

// Start runs the down-sync client loop in the background for the lifetime
// of the process, reconnecting with backoff whenever the connection drops
// or the backend isn't reachable yet.
func Start(apiUrl, dir string, m *manifest.Manifest) {
	go run(apiUrl, dir, m)
}

func run(apiUrl, dir string, m *manifest.Manifest) {
	attempt := 0
	for {
		token := auth.Get()
		if token == "" {
			time.Sleep(2 * time.Second)
			continue
		}

		wsURL := toWebSocketURL(apiUrl) + "/ws/sync"
		header := http.Header{}
		header.Set("Authorization", "Bearer "+token)

		conn, _, err := websocket.DefaultDialer.Dial(wsURL, header)
		if err != nil {
			attempt = min(attempt+1, 6)
			delay := time.Duration(attempt*2) * time.Second
			log.Println("downsync: connect failed, retrying in", delay, ":", err)
			time.Sleep(delay)
			continue
		}
		attempt = 0
		log.Println("downsync: connected")

		for {
			_, msg, readErr := conn.ReadMessage()
			if readErr != nil {
				log.Println("downsync: connection lost:", readErr)
				break
			}
			handleMessage(apiUrl, dir, m, msg)
		}
		conn.Close()
		time.Sleep(2 * time.Second)
	}
}

func handleMessage(apiUrl, dir string, m *manifest.Manifest, raw []byte) {
	var evt changeEvent
	if err := json.Unmarshal(raw, &evt); err != nil {
		return
	}

	token := auth.Get()
	if token == "" {
		return
	}

	relPath, ok := m.FindPathByDocumentId(evt.DocumentId)
	if !ok {
		// Not a document we've synced before - it may be a brand-new document
		// that someone else just created inside a folder we're syncing, which
		// won't be in our manifest yet even though it's relevant to us.
		handleNewDocument(apiUrl, dir, m, evt)
		return
	}

	entry, _ := m.Get(relPath)
	if entry.VersionId == evt.VersionId {
		return // already up to date - most often this is our own upload echoing back
	}

	absPath := filepath.Join(dir, filepath.FromSlash(relPath))
	if err := downloadTo(apiUrl, token, evt.DocumentId, absPath, m, relPath); err != nil {
		log.Println("downsync: failed to download document", evt.DocumentId, ":", err)
		return
	}

	if setErr := m.Set(relPath, evt.DocumentId, evt.VersionId); setErr != nil {
		log.Println("downsync: warning, failed to persist manifest entry:", setErr)
	}
	localws.BroadcastMessage("Downloaded update: " + relPath)
	log.Println("downsync: updated", relPath, "to version", evt.VersionId)
}

// handleNewDocument covers a document that this machine has never seen
// before. If its folder is one we're syncing (per the manifest's folder
// mappings), it's downloaded into the matching local subfolder; otherwise
// it belongs to some other part of the document tree and is ignored.
func handleNewDocument(apiUrl, dir string, m *manifest.Manifest, evt changeEvent) {
	if evt.FolderId == nil {
		return // root-level document; sync is always scoped to one project folder
	}

	folderRelPath, ok := m.FindFolderPath(*evt.FolderId)
	if !ok {
		return // not a folder this machine syncs
	}

	token := auth.Get()
	if token == "" {
		return
	}

	title, err := findDocumentTitle(apiUrl, token, *evt.FolderId, evt.DocumentId)
	if err != nil {
		log.Println("downsync: failed to look up new document", evt.DocumentId, ":", err)
		return
	}

	relPath := title
	if folderRelPath != "" {
		relPath = folderRelPath + "/" + title
	}
	absPath := filepath.Join(dir, filepath.FromSlash(relPath))

	if err := downloadTo(apiUrl, token, evt.DocumentId, absPath, m, relPath); err != nil {
		log.Println("downsync: failed to download new document", evt.DocumentId, ":", err)
		return
	}

	if setErr := m.Set(relPath, evt.DocumentId, evt.VersionId); setErr != nil {
		log.Println("downsync: warning, failed to persist manifest entry:", setErr)
	}
	localws.BroadcastMessage("Downloaded new file: " + relPath)
	log.Println("downsync: pulled new document", relPath)
}

// findDocumentTitle looks up the filename for a documentId by paging through
// the folder's document listing - the down-sync broadcast only carries ids,
// not the title needed to name the local file.
func findDocumentTitle(apiUrl, token string, folderId, documentId int64) (string, error) {
	page := 0
	for {
		url := fmt.Sprintf("%s/api/v1/documents?folderId=%d&page=%d&size=50", apiUrl, folderId, page)
		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			return "", err
		}
		req.Header.Set("Authorization", "Bearer "+token)

		client := &http.Client{Timeout: 15 * time.Second}
		resp, err := client.Do(req)
		if err != nil {
			return "", err
		}
		var result pageResult
		decodeErr := json.NewDecoder(resp.Body).Decode(&result)
		resp.Body.Close()
		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			return "", fmt.Errorf("unexpected status %s", resp.Status)
		}
		if decodeErr != nil {
			return "", decodeErr
		}

		for _, d := range result.Content {
			if d.Id == documentId {
				return d.Title, nil
			}
		}
		if !result.HasNext {
			return "", fmt.Errorf("document %d not found in folder %d", documentId, folderId)
		}
		page++
	}
}

func downloadTo(apiUrl, token string, documentId int64, absPath string, m *manifest.Manifest, relPath string) error {
	req, err := http.NewRequest("GET", fmt.Sprintf("%s/api/v1/documents/%d/download", apiUrl, documentId), nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("unexpected status %s", resp.Status)
	}

	if err := os.MkdirAll(filepath.Dir(absPath), 0o755); err != nil {
		return err
	}

	// Mark this path as down-sync-owned before writing, so the watcher
	// ignores the fsnotify event(s) this write is about to generate instead
	// of re-uploading the content we just downloaded.
	m.SuppressNextWrite(relPath)

	out, err := os.Create(absPath)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

func toWebSocketURL(apiUrl string) string {
	if strings.HasPrefix(apiUrl, "https://") {
		return "wss://" + strings.TrimPrefix(apiUrl, "https://")
	}
	return "ws://" + strings.TrimPrefix(apiUrl, "http://")
}
