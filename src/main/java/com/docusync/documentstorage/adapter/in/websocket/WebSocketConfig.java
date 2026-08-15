package com.docusync.documentstorage.adapter.in.websocket;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketConfigurer {

    private final SyncWebSocketHandler syncWebSocketHandler;
    private final SyncHandshakeInterceptor syncHandshakeInterceptor;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        // No setAllowedOrigins() call: Spring's Origin check only applies when
        // a browser sends an Origin header, which the Go sidecar's plain
        // WebSocket client never does - so the default (restrictive) setting
        // doesn't affect it, and there's no browser client to worry about.
        registry.addHandler(syncWebSocketHandler, "/ws/sync")
                .addInterceptors(syncHandshakeInterceptor);
    }
}
