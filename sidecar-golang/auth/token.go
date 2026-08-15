// Package auth holds the JWT the Flutter app hands the sidecar after login,
// so uploader requests can authenticate as the real signed-in user instead
// of a hardcoded demo token.
package auth

import (
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"sync"
)

var (
	mu    sync.RWMutex
	token string
)

// Set stores the current JWT. Called by the local /auth HTTP handler.
func Set(t string) {
	mu.Lock()
	defer mu.Unlock()
	token = t
}

// Get returns the current JWT, or "" if the Flutter app hasn't authenticated
// the sidecar yet.
func Get() string {
	mu.RLock()
	defer mu.RUnlock()
	return token
}

type authRequest struct {
	Token string `json:"token"`
}

// Handler receives {"token": "..."} from the Flutter app after login and
// stores it for the uploader to use. The sidecar only ever listens on
// 127.0.0.1 (see main.go), so this is trusted local IPC, not a public API -
// but we still reject anything that didn't arrive via loopback as
// defense-in-depth in case the bind address is ever widened by mistake.
func Handler(w http.ResponseWriter, r *http.Request) {
	host := r.RemoteAddr
	if idx := strings.LastIndex(host, ":"); idx != -1 {
		host = host[:idx]
	}
	if host != "127.0.0.1" && host != "::1" {
		http.Error(w, "forbidden", http.StatusForbidden)
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req authRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	Set(req.Token)
	log.Println("Auth token received from client.")
	w.WriteHeader(http.StatusOK)
}
