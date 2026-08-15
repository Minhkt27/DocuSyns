package com.docusync.auth.service;

import com.docusync.auth.config.JwtTokenProvider;
import com.docusync.auth.dto.AuthResponse;
import com.docusync.auth.dto.LoginRequest;
import com.docusync.documentstorage.adapter.out.persistence.entity.UserEntity;
import com.docusync.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final RefreshTokenService refreshTokenService;

    public AuthResponse login(LoginRequest request) {
        UserEntity user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new RuntimeException("Invalid password");
        }

        if (!user.isActive()) {
            throw new RuntimeException("User account is disabled");
        }

        String token = tokenProvider.generateToken(user.getId(), user.getRole());
        String refreshToken = refreshTokenService.issue(user.getId());

        return new AuthResponse(token, refreshToken, user.getId(), user.getEmail(), user.getFullName(), user.getRole());
    }

    /**
     * Exchanges a still-valid refresh token for a new access token, rotating
     * the refresh token in the process. Used at app startup so "remember me"
     * doesn't require storing the user's password.
     */
    public AuthResponse refresh(String rawRefreshToken) {
        RefreshTokenService.IssuedToken rotated = refreshTokenService.rotate(rawRefreshToken);

        UserEntity user = userRepository.findById(rotated.userId())
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!user.isActive()) {
            throw new RuntimeException("User account is disabled");
        }

        String token = tokenProvider.generateToken(user.getId(), user.getRole());

        return new AuthResponse(token, rotated.rawToken(), user.getId(), user.getEmail(), user.getFullName(), user.getRole());
    }

    public void logout(String rawRefreshToken) {
        refreshTokenService.revoke(rawRefreshToken);
    }
}
