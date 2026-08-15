package com.docusync.documentstorage.adapter.in.websocket;

import com.docusync.auth.config.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.server.ServerHttpRequest;
import org.springframework.http.server.ServerHttpResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.WebSocketHandler;
import org.springframework.web.socket.server.HandshakeInterceptor;

import java.util.Map;

/**
 * Validates the JWT passed in the Authorization header of the WebSocket
 * upgrade request (gorilla/websocket and web_socket_channel both support
 * setting arbitrary headers on connect, same as any REST call). This
 * endpoint is excluded from the normal JwtAuthFilter chain (see
 * SecurityConfig) since the handshake itself is the auth check here.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class SyncHandshakeInterceptor implements HandshakeInterceptor {

    private final JwtTokenProvider tokenProvider;

    @Override
    public boolean beforeHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                    WebSocketHandler wsHandler, Map<String, Object> attributes) {
        String authHeader = request.getHeaders().getFirst("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            response.setStatusCode(org.springframework.http.HttpStatus.UNAUTHORIZED);
            return false;
        }

        String token = authHeader.substring(7);
        if (!tokenProvider.validateToken(token)) {
            response.setStatusCode(org.springframework.http.HttpStatus.UNAUTHORIZED);
            return false;
        }

        attributes.put("userId", tokenProvider.getUserIdFromJWT(token));
        return true;
    }

    @Override
    public void afterHandshake(ServerHttpRequest request, ServerHttpResponse response,
                                WebSocketHandler wsHandler, Exception exception) {
        if (exception != null) {
            log.warn("WebSocket handshake failed: {}", exception.getMessage());
        }
    }
}
