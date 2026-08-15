package uploader

import (
	"bytes"
	"docusync-sidecar/auth"
	"docusync-sidecar/manifest"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

const maxRetries = 3

type documentResponse struct {
	Id               int64  `json:"id"`
	CurrentVersionId *int64 `json:"currentVersionId"` // present only on the create-document response
}

// UploadFile uploads the local file at absPath (relPath relative to the
// watched sync folder) to the backend - creating a new document the first
// time a file is seen, or a new version on subsequent changes, based on
// what's recorded in the manifest.
func UploadFile(absPath, relPath string, m *manifest.Manifest) {
	token := auth.Get()
	if token == "" {
		log.Println("No auth token yet (Flutter app hasn't logged in) - skipping upload for", relPath)
		return
	}

	apiUrl := os.Getenv("API_URL")
	if apiUrl == "" {
		apiUrl = "http://localhost:8080"
	}

	entry, known := m.Get(relPath)
	documentId := entry.DocumentId

	var url string
	if known {
		url = fmt.Sprintf("%s/api/v1/documents/%d/upload", apiUrl, documentId)
	} else {
		relDir := filepath.ToSlash(filepath.Dir(relPath))
		if relDir == "." {
			relDir = ""
		}
		folderId, err := resolveFolderId(apiUrl, token, relDir, m)
		if err != nil {
			log.Println("Cannot sync", relPath, "- failed to resolve its server folder:", err)
			return
		}
		url = fmt.Sprintf("%s/api/v1/documents?folderId=%d", apiUrl, folderId)
	}

	var lastErr error
	for attempt := 1; attempt <= maxRetries; attempt++ {
		// Uploading a new version requires holding the document's lock (same
		// rule the manual upload flow in the app follows) - a document being
		// actively edited by a human via the app is left alone; this attempt
		// simply fails and retries, and the file will be picked up again on
		// the next local save regardless.
		if known {
			if err := setLock(apiUrl, documentId, token, true); err != nil {
				lastErr = fmt.Errorf("lock failed: %w", err)
				log.Printf("Upload attempt %d/%d for %s failed: %v", attempt, maxRetries, relPath, lastErr)
				time.Sleep(time.Duration(attempt) * time.Second)
				continue
			}
		}

		body, contentType, err := buildMultipartBody(absPath)
		if err != nil {
			log.Println("Error preparing upload body for", relPath, ":", err)
			return
		}

		result, err := doUpload(url, contentType, body, token)

		if known {
			// Best-effort: always release the lock we just took, whether the
			// upload succeeded or not, so the document doesn't stay locked.
			if unlockErr := setLock(apiUrl, documentId, token, false); unlockErr != nil {
				log.Println("Warning: failed to unlock document", documentId, "after sync:", unlockErr)
			}
		}

		if err == nil {
			if !known {
				versionId := int64(0)
				if result.CurrentVersionId != nil {
					versionId = *result.CurrentVersionId
				}
				if setErr := m.Set(relPath, result.Id, versionId); setErr != nil {
					log.Println("Warning: failed to persist manifest entry for", relPath, ":", setErr)
				}
				log.Println("Created new document", result.Id, "for", relPath)
			} else {
				if setErr := m.Set(relPath, documentId, result.Id); setErr != nil {
					log.Println("Warning: failed to persist manifest entry for", relPath, ":", setErr)
				}
				log.Println("Uploaded new version of document", documentId, "for", relPath)
			}
			return
		}

		lastErr = err
		log.Printf("Upload attempt %d/%d for %s failed: %v", attempt, maxRetries, relPath, err)
		time.Sleep(time.Duration(attempt) * time.Second)
	}

	log.Println("Giving up uploading", relPath, "after", maxRetries, "attempts:", lastErr)
}

// resolveFolderId returns the server folderId for the local subfolder at
// relDir (empty string = sync root). If relDir isn't mapped yet, it walks up
// to the nearest mapped ancestor and creates the missing folders on the
// server one level at a time, recording each in the manifest as it goes.
// Creating a subfolder requires ADMIN/PROJECT_MANAGER on the backend
// (see FolderService.createFolder) - a permission failure here is returned
// as an error rather than retried, since retrying won't change the outcome.
func resolveFolderId(apiUrl, token, relDir string, m *manifest.Manifest) (int64, error) {
	relDir = filepath.ToSlash(relDir)
	if relDir == "." {
		relDir = ""
	}

	if id, ok := m.GetFolder(relDir); ok {
		return id, nil
	}
	if relDir == "" {
		return 0, fmt.Errorf("sync root folder not configured (SYNC_FOLDER_ID missing)")
	}

	parentDir := filepath.ToSlash(filepath.Dir(relDir))
	if parentDir == "." {
		parentDir = ""
	}
	parentId, err := resolveFolderId(apiUrl, token, parentDir, m)
	if err != nil {
		return 0, err
	}

	name := filepath.Base(relDir)
	newId, err := createFolder(apiUrl, token, parentId, name)
	if err != nil {
		return 0, fmt.Errorf("create folder %q on server: %w (does this account have ADMIN/PROJECT_MANAGER role?)", name, err)
	}
	if setErr := m.SetFolder(relDir, newId); setErr != nil {
		log.Println("Warning: failed to persist folder mapping for", relDir, ":", setErr)
	}
	log.Println("Created server folder for", relDir, "(id", newId, ")")
	return newId, nil
}

func createFolder(apiUrl, token string, parentId int64, name string) (int64, error) {
	payload, err := json.Marshal(map[string]any{"name": name, "parentId": parentId})
	if err != nil {
		return 0, err
	}

	req, err := http.NewRequest("POST", apiUrl+"/api/v1/folders", bytes.NewReader(payload))
	if err != nil {
		return 0, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return 0, fmt.Errorf("unexpected status %s", resp.Status)
	}

	var parsed struct {
		Id int64 `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return 0, err
	}
	return parsed.Id, nil
}

// setLock locks (lock=true) or unlocks (lock=false) a document. Any non-2xx
// response (e.g. "already locked by another user") is returned as an error.
func setLock(apiUrl string, documentId int64, token string, lock bool) error {
	action := "unlock"
	if lock {
		action = "lock"
	}
	url := fmt.Sprintf("%s/api/v1/documents/%d/%s", apiUrl, documentId, action)

	req, err := http.NewRequest("POST", url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("unexpected status %s", resp.Status)
	}
	return nil
}

func buildMultipartBody(absPath string) (*bytes.Buffer, string, error) {
	file, err := os.Open(absPath)
	if err != nil {
		return nil, "", err
	}
	defer file.Close()

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("file", filepath.Base(absPath))
	if err != nil {
		return nil, "", err
	}
	if _, err := io.Copy(part, file); err != nil {
		return nil, "", err
	}
	if err := writer.Close(); err != nil {
		return nil, "", err
	}
	return body, writer.FormDataContentType(), nil
}

func doUpload(url, contentType string, body *bytes.Buffer, token string) (documentResponse, error) {
	req, err := http.NewRequest("POST", url, body)
	if err != nil {
		return documentResponse{}, err
	}
	req.Header.Set("Content-Type", contentType)
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return documentResponse{}, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return documentResponse{}, fmt.Errorf("unexpected status %s", resp.Status)
	}

	var parsed documentResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return documentResponse{}, err
	}
	return parsed, nil
}
