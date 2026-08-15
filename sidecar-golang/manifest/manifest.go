// Package manifest persists the mapping between locally-watched files and
// the backend document/version they correspond to, plus the mapping between
// local subfolders and their server-side folder, so the sidecar knows
// whether to create a new document/folder or update an existing one for a
// given local path.
package manifest

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"
)

const fileName = ".docusync-manifest.json"
const suppressWindow = 5 * time.Second

// FileEntry records which backend document (and which of its versions) a
// local file was last synced as.
type FileEntry struct {
	DocumentId int64 `json:"documentId"`
	VersionId  int64 `json:"versionId"`
}

type Manifest struct {
	mu      sync.Mutex
	path    string
	Files   map[string]FileEntry `json:"files"`
	Folders map[string]int64     `json:"folders"` // relative folder path -> server folderId

	suppressMu sync.Mutex
	suppressed map[string]time.Time // relPath -> expiry; in-memory only, not persisted
}

// Load reads the manifest from <dir>/.docusync-manifest.json, creating an
// empty one in memory if it doesn't exist yet (nothing is written to disk
// until the first Set/SetFolder call).
func Load(dir string) (*Manifest, error) {
	m := &Manifest{
		path:       filepath.Join(dir, fileName),
		Files:      make(map[string]FileEntry),
		Folders:    make(map[string]int64),
		suppressed: make(map[string]time.Time),
	}

	data, err := os.ReadFile(m.path)
	if os.IsNotExist(err) {
		return m, nil
	}
	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal(data, m); err != nil {
		return nil, err
	}
	if m.Files == nil {
		m.Files = make(map[string]FileEntry)
	}
	if m.Folders == nil {
		m.Folders = make(map[string]int64)
	}
	return m, nil
}

// Get returns the entry previously recorded for relPath, if any.
func (m *Manifest) Get(relPath string) (FileEntry, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	entry, ok := m.Files[relPath]
	return entry, ok
}

// FindPathByDocumentId reverse-looks-up the relative path synced for a given
// documentId. Manifests are small (one machine's worth of synced files), so
// a linear scan is fine.
func (m *Manifest) FindPathByDocumentId(documentId int64) (string, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for relPath, entry := range m.Files {
		if entry.DocumentId == documentId {
			return relPath, true
		}
	}
	return "", false
}

// Set records the document/version for relPath and persists the manifest to
// disk atomically (write to a temp file, then rename over the real one) so a
// crash mid-write can't corrupt it.
func (m *Manifest) Set(relPath string, documentId, versionId int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.Files[relPath] = FileEntry{DocumentId: documentId, VersionId: versionId}
	return m.saveLocked()
}

// FindFolderPath reverse-looks-up the relative local folder path mapped to a
// given server folderId. Used when a change broadcast names a folderId the
// sidecar doesn't have a documentId for yet (a brand-new document), so it
// can figure out where locally to place the download.
func (m *Manifest) FindFolderPath(folderId int64) (string, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	for relPath, id := range m.Folders {
		if id == folderId {
			return relPath, true
		}
	}
	return "", false
}

// GetFolder returns the server folderId mapped to relFolderPath, if any.
// The empty string represents the sync root itself.
func (m *Manifest) GetFolder(relFolderPath string) (int64, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	id, ok := m.Folders[relFolderPath]
	return id, ok
}

// SetFolder records the server folderId for relFolderPath and persists it.
func (m *Manifest) SetFolder(relFolderPath string, folderId int64) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.Folders[relFolderPath] = folderId
	return m.saveLocked()
}

func (m *Manifest) saveLocked() error {
	data, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}

	tmpPath := m.path + ".tmp"
	if err := os.WriteFile(tmpPath, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmpPath, m.path)
}

// SuppressNextWrite marks relPath so the next fsnotify Write/Create event
// the watcher sees for it (within a few seconds) is ignored. Used right
// before down-sync writes a file to disk, so that write doesn't bounce back
// into an unnecessary re-upload.
func (m *Manifest) SuppressNextWrite(relPath string) {
	m.suppressMu.Lock()
	defer m.suppressMu.Unlock()
	m.suppressed[relPath] = time.Now().Add(suppressWindow)
}

// IsSuppressed reports whether relPath was written by down-sync within the
// last few seconds. Not one-shot on purpose: a single down-sync write can
// produce more than one fsnotify event (e.g. Create then Write), and all of
// them need to be ignored, not just the first.
func (m *Manifest) IsSuppressed(relPath string) bool {
	m.suppressMu.Lock()
	defer m.suppressMu.Unlock()
	expiry, ok := m.suppressed[relPath]
	if !ok {
		return false
	}
	if time.Now().After(expiry) {
		delete(m.suppressed, relPath)
		return false
	}
	return true
}
