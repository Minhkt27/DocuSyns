package com.docusync.documentstorage.application.domain.model;

import java.time.LocalDateTime;

public record Folder(
    Long id,
    String name,
    Long parentId,
    Long createdBy,
    LocalDateTime createdAt,
    boolean isDeleted
) {}
