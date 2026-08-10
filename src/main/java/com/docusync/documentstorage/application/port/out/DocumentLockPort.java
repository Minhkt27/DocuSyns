package com.docusync.documentstorage.application.port.out;

import com.docusync.documentstorage.application.domain.model.DocumentLock;
import java.util.Optional;

public interface DocumentLockPort {
    DocumentLock acquireLock(DocumentLock lock);
    void releaseLock(Long documentId, Long userId, boolean force);
    Optional<DocumentLock> getActiveLockForDocument(Long documentId);
}
