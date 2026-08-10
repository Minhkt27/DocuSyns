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

        return new AuthResponse(token, user.getId(), user.getEmail(), user.getFullName(), user.getRole());
    }
}
