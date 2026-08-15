package com.docusync.documentstorage.application.domain.model;

import java.time.LocalDateTime;

public record Document(
    Long id,
    String documentCode,
    String title,
    Long currentVersionId,
    Long createdBy,
    Long folderId,
    boolean isDeleted,
    Long lockedBy,
    String lockedByName,
    LocalDateTime deletedAt,
    LocalDateTime createdAt
) {}
