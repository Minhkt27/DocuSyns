package com.docusync.documentstorage.application.service;

import com.docusync.documentstorage.application.domain.model.DocumentLock;
import com.docusync.documentstorage.application.port.in.LockDocumentUseCase;
import com.docusync.documentstorage.application.port.out.DocumentLockPort;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class DocumentLockService implements LockDocumentUseCase {

    private final DocumentLockPort documentLockPort;

    @Override
    @Transactional(isolation = Isolation.SERIALIZABLE)
    public void lockDocument(Long documentId, Long userId) {
        // DocuSync is an internal shared-drive system: any authenticated employee
        // is allowed to lock any document by design (no per-document ownership ACL).

        documentLockPort.getActiveLockForDocument(documentId).ifPresent(lock -> {
            throw new RuntimeException("Document is already locked by user: " + lock.lockedBy());
        });

        // SERIALIZABLE isolation makes Postgres detect the check-then-insert race
        // between two concurrent lock attempts on the same document and abort the
        // loser's transaction; translate that into the same "already locked" error.
        try {
            DocumentLock newLock = new DocumentLock(null, documentId, userId, DocumentLock.LockStatus.LOCKED);
            documentLockPort.acquireLock(newLock);
        } catch (CannotAcquireLockException | DataIntegrityViolationException e) {
            throw new RuntimeException("Document is already locked by another user");
        }
    }

    @Override
    @Transactional
    public void unlockDocument(Long documentId, Long userId, boolean force) {
        documentLockPort.releaseLock(documentId, userId, force);
    }
}
