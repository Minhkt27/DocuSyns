package com.docusync.documentstorage.adapter.out.persistence.repository;

import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentLockEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

import java.util.List;

public interface DocumentLockRepository extends JpaRepository<DocumentLockEntity, Long> {
    Optional<DocumentLockEntity> findByDocumentIdAndStatus(Long documentId, DocumentLockEntity.LockStatus status);
    List<DocumentLockEntity> findByDocumentIdInAndStatus(List<Long> documentIds, DocumentLockEntity.LockStatus status);
}
