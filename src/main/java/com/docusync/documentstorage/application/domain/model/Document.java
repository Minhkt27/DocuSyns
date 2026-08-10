package com.docusync.documentstorage.application.domain.model;

public record Document(
    Long id,
    String documentCode,
    String title,
    Long currentVersionId,
    Long createdBy,
    Long folderId,
    boolean isDeleted,
    Long lockedBy,
    String lockedByName
) {}
