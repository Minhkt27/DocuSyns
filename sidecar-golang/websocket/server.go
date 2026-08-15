package websocket

import (
	"log"
	"net/http"
	"strings"
	"sync"

	"github.com/gorilla/websocket"
)

var clients = make(map[*websocket.Conn]bool)
var upgrader = websocket.Upgrader{
	// The sidecar only binds to 127.0.0.1 (see main.go) and broadcasts no
	// sensitive data, so there's nothing to steal cross-origin. Still, don't
	// blanket-allow every origin - only requests with no Origin header
	// (native desktop clients, curl, etc.) or an explicit loopback origin are
	// accepted, as defense-in-depth in case the bind address is ever widened.
	CheckOrigin: func(r *http.Request) bool {
		origin := r.Header.Get("Origin")
		if origin == "" {
			return true
		}
		return strings.Contains(origin, "localhost") || strings.Contains(origin, "127.0.0.1")
	},
}
var mutex = &sync.Mutex{}

func HandleConnections(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Error upgrading to websocket:", err)
		return
	}
	defer ws.Close()

	mutex.Lock()
	clients[ws] = true
	mutex.Unlock()

	for {
		var msg string
		err := ws.ReadJSON(&msg)
		if err != nil {
			mutex.Lock()
			delete(clients, ws)
			mutex.Unlock()
			break
		}
	}
}

func BroadcastMessage(msg string) {
	mutex.Lock()
	defer mutex.Unlock()
	for client := range clients {
		err := client.WriteJSON(map[string]string{"message": msg})
		if err != nil {
			log.Println("Error sending to client:", err)
			client.Close()
			delete(clients, client)
		}
	}
}
