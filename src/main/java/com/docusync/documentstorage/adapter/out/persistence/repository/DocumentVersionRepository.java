package com.docusync.documentstorage.adapter.out.persistence.repository;

import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentVersionEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface DocumentVersionRepository extends JpaRepository<DocumentVersionEntity, Long> {
    List<DocumentVersionEntity> findByDocumentId(Long documentId);
    List<DocumentVersionEntity> findByDocumentIdAndIsDeletedFalse(Long documentId);
    List<DocumentVersionEntity> findByDocumentIdAndIsDeletedFalseOrderByVersionNumberDesc(Long documentId);
    DocumentVersionEntity findTopByDocumentIdAndIsDeletedFalseOrderByVersionNumberDesc(Long documentId);
    List<DocumentVersionEntity> findByIsDeletedTrue();
}
