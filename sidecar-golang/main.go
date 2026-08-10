package main

import (
	"docusync-sidecar/watcher"
	"docusync-sidecar/websocket"
	"fmt"
	"log"
	"net/http"
)

func main() {
	fmt.Println("Starting DocuSync Sidecar Service...")
	
	// Start Websocket server
	go func() {
		http.HandleFunc("/ws", websocket.HandleConnections)
		log.Println("WebSocket server listening on :8081")
		err := http.ListenAndServe(":8081", nil)
		if err != nil {
			log.Fatal("ListenAndServe: ", err)
		}
	}()

	// Start file watcher
	watchDir := "./sync_folder" // In real app, this is dynamic
	watcher.StartWatching(watchDir)
}
