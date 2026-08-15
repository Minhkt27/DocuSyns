package main

import (
	"docusync-sidecar/auth"
	"docusync-sidecar/downsync"
	"docusync-sidecar/initialpull"
	"docusync-sidecar/manifest"
	"docusync-sidecar/watcher"
	"docusync-sidecar/websocket"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	fmt.Println("Starting DocuSync Sidecar Service...")

	// Local server: websocket status broadcast + auth token bridge. Bound to
	// 127.0.0.1 only - this process is a local companion to the Flutter
	// desktop app, never meant to be reachable over the network.
	go func() {
		mux := http.NewServeMux()
		mux.HandleFunc("/ws", websocket.HandleConnections)
		mux.HandleFunc("/auth", auth.Handler)
		log.Println("Local server listening on 127.0.0.1:8081")
		err := http.ListenAndServe("127.0.0.1:8081", mux)
		if err != nil {
			log.Fatal("ListenAndServe: ", err)
		}
	}()

	watchDir := os.Getenv("SYNC_FOLDER")
	if watchDir == "" {
		watchDir = "./sync_folder" // fallback for local/manual runs
	}

	m, err := manifest.Load(watchDir)
	if err != nil {
		log.Fatal("Failed to load sync manifest: ", err)
	}

	apiUrl := os.Getenv("API_URL")
	if apiUrl == "" {
		apiUrl = "http://localhost:8080"
	}

	log.Println("Waiting for auth token from the Flutter app...")
	token := waitForToken()
	log.Println("Got auth token, continuing startup.")

	if folderIdStr := os.Getenv("SYNC_FOLDER_ID"); folderIdStr != "" {
		folderId, parseErr := strconv.ParseInt(folderIdStr, 10, 64)
		if parseErr != nil {
			log.Println("Warning: SYNC_FOLDER_ID is not a valid number, skipping initial pull:", parseErr)
		} else if pullErr := initialpull.Run(apiUrl, token, folderId, watchDir, m); pullErr != nil {
			log.Println("Warning: initial pull failed (will continue watching anyway):", pullErr)
		}
	} else {
		log.Println("Warning: SYNC_FOLDER_ID not set - new local files won't be uploaded until a project folder is selected in Settings.")
	}

	downsync.Start(apiUrl, watchDir, m)
	watcher.StartWatching(watchDir, m)
}

// waitForToken blocks until the Flutter app has pushed a JWT via /auth,
// polling since that happens asynchronously shortly after this process starts.
func waitForToken() string {
	for {
		if token := auth.Get(); token != "" {
			return token
		}
		time.Sleep(500 * time.Millisecond)
	}
}
