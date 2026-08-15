package com.docusync.documentstorage.adapter.in.websocket;

import com.docusync.documentstorage.application.port.out.SyncNotificationPort;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Broadcasts "a document's content changed" events to every connected
 * sidecar so it can pull down a fresh copy if that document is one it has
 * synced locally. Deliberately dumb/one-directional (server -> clients
 * only, no per-client subscription tracking) - each sidecar decides for
 * itself, from its own manifest, whether a given documentId is relevant.
 */
@Component
@Slf4j
public class SyncWebSocketHandler extends TextWebSocketHandler implements SyncNotificationPort {

    private final Set<WebSocketSession> sessions = ConcurrentHashMap.newKeySet();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        sessions.add(session);
        log.info("Sync WebSocket client connected: {}", session.getId());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session);
        log.info("Sync WebSocket client disconnected: {}", session.getId());
    }

    @Override
    public void notifyDocumentChanged(Long documentId, Long versionId, Long folderId) {
        String folderJson = folderId == null ? "null" : folderId.toString();
        String json = String.format("{\"documentId\":%d,\"versionId\":%d,\"folderId\":%s}", documentId, versionId, folderJson);
        TextMessage message = new TextMessage(json);
        for (WebSocketSession session : sessions) {
            try {
                if (session.isOpen()) {
                    session.sendMessage(message);
                }
            } catch (IOException e) {
                log.warn("Failed to send sync broadcast to session {}: {}", session.getId(), e.getMessage());
            }
        }
    }
}
