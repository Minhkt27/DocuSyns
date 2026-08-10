package watcher

import (
	"docusync-sidecar/uploader"
	"docusync-sidecar/websocket"
	"log"
	"time"

	"github.com/fsnotify/fsnotify"
)

func StartWatching(dir string) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer watcher.Close()

	err = watcher.Add(dir)
	if err != nil {
		log.Println("Failed to watch directory, it might not exist yet:", err)
		// For demo, we don't fatal here if folder doesn't exist
	} else {
	    log.Println("Watching directory:", dir)
	}

	// Debounce map
	events := make(map[string]time.Time)

	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			if event.Op&fsnotify.Write == fsnotify.Write {
				events[event.Name] = time.Now()
				// Simple debounce logic
				go func(filename string) {
					time.Sleep(2 * time.Second)
					if time.Since(events[filename]) >= 2*time.Second {
						log.Println("File modified & debounced:", filename)
						websocket.BroadcastMessage("Uploading file: " + filename)
						uploader.UploadFile(filename)
						websocket.BroadcastMessage("Upload completed: " + filename)
					}
				}(event.Name)
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			log.Println("error:", err)
		}
	}
}
