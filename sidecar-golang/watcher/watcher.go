package watcher

import (
	"docusync-sidecar/manifest"
	"docusync-sidecar/uploader"
	"docusync-sidecar/websocket"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
)

const debounceDelay = 2 * time.Second

// StartWatching watches dir - and every subdirectory beneath it - for file
// changes, uploading them via the uploader package, debounced so rapid
// successive saves of the same file only trigger one upload. Create and
// Write events on files are treated the same way (content needs syncing
// either way); Remove/Rename are intentionally not auto-synced to the
// backend yet - only logged - to avoid ever deleting a server-side document
// as a side effect of a local file move.
func StartWatching(dir string, m *manifest.Manifest) {
	fsWatcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer fsWatcher.Close()

	addRecursive(fsWatcher, dir)

	var mu sync.Mutex
	timers := make(map[string]*time.Timer)

	triggerUpload := func(absPath string) {
		relPath, err := filepath.Rel(dir, absPath)
		if err != nil {
			relPath = filepath.Base(absPath)
		}

		log.Println("File changed & debounced:", relPath)
		websocket.BroadcastMessage("Uploading file: " + relPath)
		uploader.UploadFile(absPath, relPath, m)
		websocket.BroadcastMessage("Upload completed: " + relPath)
	}

	for {
		select {
		case event, ok := <-fsWatcher.Events:
			if !ok {
				return
			}

			// Skip the manifest file itself and any other dotfiles/dot-dirs
			// before scheduling anything, so the sidecar never reacts to its
			// own writes.
			if strings.HasPrefix(filepath.Base(event.Name), ".") {
				continue
			}

			// Skip writes that down-sync itself just made to this file -
			// otherwise every downloaded update would immediately bounce
			// back into a pointless re-upload of the same content.
			if relPath, err := filepath.Rel(dir, event.Name); err == nil && m.IsSuppressed(relPath) {
				continue
			}

			if event.Op&fsnotify.Create == fsnotify.Create {
				if info, statErr := os.Stat(event.Name); statErr == nil && info.IsDir() {
					// fsnotify only watches one directory level per Add call,
					// so a newly created subfolder (and anything nested
					// inside it) needs to be registered explicitly.
					addRecursive(fsWatcher, event.Name)
					continue
				}
			}

			if event.Op&(fsnotify.Write|fsnotify.Create) == 0 {
				continue
			}

			name := event.Name
			mu.Lock()
			if t, exists := timers[name]; exists {
				t.Reset(debounceDelay)
			} else {
				timers[name] = time.AfterFunc(debounceDelay, func() {
					mu.Lock()
					delete(timers, name)
					mu.Unlock()
					triggerUpload(name)
				})
			}
			mu.Unlock()

		case err, ok := <-fsWatcher.Errors:
			if !ok {
				return
			}
			log.Println("error:", err)
		}
	}
}

// addRecursive registers root and every subdirectory beneath it with the
// watcher. Hidden directories (e.g. ".git") are skipped entirely.
func addRecursive(fsWatcher *fsnotify.Watcher, root string) {
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			// Keep walking even if one entry is unreadable (e.g. permission
			// denied on a single subfolder) rather than aborting the sync.
			return nil
		}
		if !d.IsDir() {
			return nil
		}
		if path != root && strings.HasPrefix(d.Name(), ".") {
			return filepath.SkipDir
		}
		if addErr := fsWatcher.Add(path); addErr != nil {
			log.Println("Failed to watch directory", path, ":", addErr)
		} else {
			log.Println("Watching directory:", path)
		}
		return nil
	})
	if err != nil {
		log.Println("Failed to walk directory", root, ":", err)
	}
}
