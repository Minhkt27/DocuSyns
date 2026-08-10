package com.docusync.documentstorage.application.domain.model;

public record DocumentLock(
    Long id,
    Long documentId,
    Long lockedBy,
    LockStatus status
) {
    public enum LockStatus {
        LOCKED, RELEASED
    }
}
