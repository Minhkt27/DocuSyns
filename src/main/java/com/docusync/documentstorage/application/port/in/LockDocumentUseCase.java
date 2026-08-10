package com.docusync.documentstorage.application.port.in;

public interface LockDocumentUseCase {
    void lockDocument(Long documentId, Long userId);
    void unlockDocument(Long documentId, Long userId, boolean force);
}
