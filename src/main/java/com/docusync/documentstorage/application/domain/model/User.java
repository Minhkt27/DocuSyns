package com.docusync.documentstorage.application.domain.model;

public record User(
    Long id,
    String misaEmployeeId,
    String email,
    String fullName,
    String role
) {}
