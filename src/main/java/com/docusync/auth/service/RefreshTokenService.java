package com.docusync.auth.service;

import com.docusync.documentstorage.adapter.out.persistence.entity.RefreshTokenEntity;
import com.docusync.documentstorage.adapter.out.persistence.repository.RefreshTokenRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;

/**
 * Issues, rotates and revokes long-lived refresh tokens so "remember me"
 * no longer needs to store the user's raw password client-side. Only the
 * SHA-256 hash of a token is persisted, mirroring how passwords are hashed.
 */
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final RefreshTokenRepository repository;

    @Value("${docusync.refresh-token.expiry-days:30}")
    private long expiryDays;

    public record IssuedToken(Long userId, String rawToken) {}

    @Transactional
    public String issue(Long userId) {
        String rawToken = generateRawToken();
        RefreshTokenEntity entity = RefreshTokenEntity.builder()
                .userId(userId)
                .tokenHash(hash(rawToken))
                .expiresAt(LocalDateTime.now().plusDays(expiryDays))
                .revoked(false)
                .createdAt(LocalDateTime.now())
                .build();
        repository.save(entity);
        return rawToken;
    }

    /**
     * Validates the given refresh token, revokes it, and issues a new one
     * (rotation) - so a stolen-and-reused token is invalidated the next
     * time the legitimate owner refreshes.
     */
    @Transactional
    public IssuedToken rotate(String rawToken) {
        RefreshTokenEntity entity = repository.findByTokenHashAndRevokedFalse(hash(rawToken))
                .orElseThrow(() -> new SecurityException("Invalid refresh token"));

        if (entity.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new SecurityException("Refresh token expired");
        }

        entity.setRevoked(true);
        repository.save(entity);

        String newRawToken = issue(entity.getUserId());
        return new IssuedToken(entity.getUserId(), newRawToken);
    }

    @Transactional
    public void revoke(String rawToken) {
        repository.findByTokenHashAndRevokedFalse(hash(rawToken))
                .ifPresent(entity -> {
                    entity.setRevoked(true);
                    repository.save(entity);
                });
    }

    private String generateRawToken() {
        byte[] bytes = new byte[32];
        SECURE_RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hash(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(hashed);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
