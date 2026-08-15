// Package initialpull performs the one-time "sync this project folder to my
// machine" download: when a user first picks a server folder to sync,
// everything already in it (subfolders and documents, recursively) gets
// mirrored to the local sync folder before live watching starts.
package initialpull

import (
	"docusync-sidecar/manifest"
	localws "docusync-sidecar/websocket"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

type folderDTO struct {
	Id   int64  `json:"id"`
	Name string `json:"name"`
}

type documentDTO struct {
	Id               int64  `json:"id"`
	Title            string `json:"title"`
	CurrentVersionId int64  `json:"currentVersionId"`
}

type pageResult struct {
	Content []documentDTO `json:"content"`
	HasNext bool          `json:"hasNext"`
}

// Run recursively downloads every subfolder and document beneath
// rootFolderId into localDir, mirroring the server's structure, and records
// everything in the manifest. Safe to call on every startup - it's a no-op
// once the root folder mapping is already recorded (i.e. after the first
// successful run).
func Run(apiUrl, token string, rootFolderId int64, localDir string, m *manifest.Manifest) error {
	if _, ok := m.GetFolder(""); ok {
		return nil
	}

	if err := m.SetFolder("", rootFolderId); err != nil {
		return fmt.Errorf("recording root folder mapping: %w", err)
	}

	localws.BroadcastMessage("Downloading existing files for the first time...")
	if err := pullFolder(apiUrl, token, rootFolderId, "", localDir, m); err != nil {
		return err
	}
	localws.BroadcastMessage("Initial download complete.")
	return nil
}

func pullFolder(apiUrl, token string, folderId int64, relDir, localDir string, m *manifest.Manifest) error {
	subfolders, err := listFolders(apiUrl, token, folderId)
	if err != nil {
		return fmt.Errorf("listing subfolders of folder %d: %w", folderId, err)
	}
	for _, f := range subfolders {
		childRelDir := f.Name
		if relDir != "" {
			childRelDir = relDir + "/" + f.Name
		}
		if err := os.MkdirAll(filepath.Join(localDir, filepath.FromSlash(childRelDir)), 0o755); err != nil {
			return err
		}
		if setErr := m.SetFolder(childRelDir, f.Id); setErr != nil {
			log.Println("Warning: failed to persist folder mapping for", childRelDir, ":", setErr)
		}
		if err := pullFolder(apiUrl, token, f.Id, childRelDir, localDir, m); err != nil {
			return err
		}
	}

	docs, err := listDocuments(apiUrl, token, folderId)
	if err != nil {
		return fmt.Errorf("listing documents of folder %d: %w", folderId, err)
	}
	for _, d := range docs {
		relPath := d.Title
		if relDir != "" {
			relPath = relDir + "/" + d.Title
		}
		absPath := filepath.Join(localDir, filepath.FromSlash(relPath))
		if err := downloadDocument(apiUrl, token, d.Id, absPath); err != nil {
			log.Println("Warning: failed to download", relPath, ":", err)
			continue
		}
		m.SuppressNextWrite(relPath)
		if setErr := m.Set(relPath, d.Id, d.CurrentVersionId); setErr != nil {
			log.Println("Warning: failed to persist manifest entry for", relPath, ":", setErr)
		}
		log.Println("Pulled", relPath)
	}
	return nil
}

func downloadDocument(apiUrl, token string, documentId int64, absPath string) error {
	req, err := http.NewRequest("GET", fmt.Sprintf("%s/api/v1/documents/%d/download", apiUrl, documentId), nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 60 * time.Second}
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
	out, err := os.Create(absPath)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

func listFolders(apiUrl, token string, parentId int64) ([]folderDTO, error) {
	var result []folderDTO
	url := fmt.Sprintf("%s/api/v1/folders?parentId=%d", apiUrl, parentId)
	if err := getJSON(token, url, &result); err != nil {
		return nil, err
	}
	return result, nil
}

func listDocuments(apiUrl, token string, folderId int64) ([]documentDTO, error) {
	var all []documentDTO
	page := 0
	for {
		url := fmt.Sprintf("%s/api/v1/documents?folderId=%d&page=%d&size=50", apiUrl, folderId, page)
		var result pageResult
		if err := getJSON(token, url, &result); err != nil {
			return nil, err
		}
		all = append(all, result.Content...)
		if !result.HasNext {
			break
		}
		page++
	}
	return all, nil
}

func getJSON(token, url string, out any) error {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("unexpected status %s", resp.Status)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}
