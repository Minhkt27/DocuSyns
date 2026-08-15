package com.docusync.auth.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Value("${docusync.cors.allowed-origins:}")
    private String allowedOrigins;

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        // The Flutter client is a Windows desktop app and is not subject to CORS.
        // This is only relevant if a browser-based client is ever added; keep it
        // locked down to an explicit allow-list instead of "*".
        String[] origins = allowedOrigins.isBlank()
                ? new String[0]
                : allowedOrigins.split("\\s*,\\s*");

        registry.addMapping("/**")
                .allowedOrigins(origins)
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*");
    }
}
