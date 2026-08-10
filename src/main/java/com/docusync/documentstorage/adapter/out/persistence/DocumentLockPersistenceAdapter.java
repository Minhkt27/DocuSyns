package com.docusync.documentstorage.adapter.out.persistence;

import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentLockEntity;
import com.docusync.documentstorage.adapter.out.persistence.mapper.DocumentMapper;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentLockRepository;
import com.docusync.documentstorage.application.domain.model.DocumentLock;
import com.docusync.documentstorage.application.port.out.DocumentLockPort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Optional;

@Component
@RequiredArgsConstructor
public class DocumentLockPersistenceAdapter implements DocumentLockPort {

    private final DocumentLockRepository lockRepository;
    private final DocumentMapper mapper;

    @Override
    public DocumentLock acquireLock(DocumentLock lock) {
        DocumentLockEntity entity = mapper.toEntity(lock);
        return mapper.toDomain(lockRepository.save(entity));
    }

    @Override
    public void releaseLock(Long documentId, Long userId, boolean force) {
        lockRepository.findByDocumentIdAndStatus(documentId, DocumentLockEntity.LockStatus.LOCKED)
            .ifPresent(lock -> {
                if (force || lock.getLockedBy().equals(userId)) {
                    lock.setStatus(DocumentLockEntity.LockStatus.RELEASED);
                    lockRepository.save(lock);
                } else {
                    throw new RuntimeException("User does not own the lock");
                }
            });
    }

    @Override
    public Optional<DocumentLock> getActiveLockForDocument(Long documentId) {
        return lockRepository.findByDocumentIdAndStatus(documentId, DocumentLockEntity.LockStatus.LOCKED)
                .map(mapper::toDomain);
    }
}
