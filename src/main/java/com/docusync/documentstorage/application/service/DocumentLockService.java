package com.docusync.documentstorage.application.service;

import com.docusync.documentstorage.application.domain.model.DocumentLock;
import com.docusync.documentstorage.application.port.in.LockDocumentUseCase;
import com.docusync.documentstorage.application.port.out.DocumentLockPort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DocumentLockService implements LockDocumentUseCase {

    private final DocumentLockPort documentLockPort;

    @Override
    @Transactional
    public void lockDocument(Long documentId, Long userId) {
        // IDOR Check should be performed here (omitted for brevity)
        
        documentLockPort.getActiveLockForDocument(documentId).ifPresent(lock -> {
            throw new RuntimeException("Document is already locked by user: " + lock.lockedBy());
        });

        DocumentLock newLock = new DocumentLock(null, documentId, userId, DocumentLock.LockStatus.LOCKED);
        documentLockPort.acquireLock(newLock);
    }

    @Override
    @Transactional
    public void unlockDocument(Long documentId, Long userId, boolean force) {
        documentLockPort.releaseLock(documentId, userId, force);
    }
}
