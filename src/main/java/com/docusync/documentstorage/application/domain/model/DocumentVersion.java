package com.docusync.documentstorage.application.domain.model;

public record DocumentVersion(
    Long id,
    Long documentId,
    Integer versionNumber,
    String storageFileId,
    String fileName,
    Long fileSize,
    Long uploadedBy,
    java.time.LocalDateTime uploadedAt,
    String note,
    boolean isDeleted
) {}
