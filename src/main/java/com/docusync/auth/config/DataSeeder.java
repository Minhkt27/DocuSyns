package com.docusync.auth.config;

import com.docusync.documentstorage.adapter.out.persistence.entity.UserEntity;
import com.docusync.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
@RequiredArgsConstructor
public class DataSeeder {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${docusync.seed.default-password:123456}")
    private String defaultPassword;

    @Bean
    public CommandLineRunner initDatabase() {
        return args -> {
            if (userRepository.count() == 0) {
                userRepository.save(UserEntity.builder()
                        .email("admin")
                        .passwordHash(passwordEncoder.encode(defaultPassword))
                        .fullName("System Admin")
                        .role("ADMIN")
                        .misaEmployeeId("admin-001")
                        .isActive(true)
                        .build());

                userRepository.save(UserEntity.builder()
                        .email("pm")
                        .passwordHash(passwordEncoder.encode(defaultPassword))
                        .fullName("Project Manager")
                        .role("PROJECT_MANAGER")
                        .misaEmployeeId("pm-001")
                        .isActive(true)
                        .build());

                userRepository.save(UserEntity.builder()
                        .email("employee")
                        .passwordHash(passwordEncoder.encode(defaultPassword))
                        .fullName("Regular Employee")
                        .role("USER")
                        .misaEmployeeId("user-001")
                        .isActive(true)
                        .build());
            }
        };
    }
}
