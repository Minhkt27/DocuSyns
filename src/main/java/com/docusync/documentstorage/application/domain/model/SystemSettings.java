package com.docusync.documentstorage.application.domain.model;

public record SystemSettings(
    Long id,
    Integer maxVersionsPerFile,
    Integer trashRetentionDays,
    String clientAppVersion,
    String clientAppUrl
) {}
