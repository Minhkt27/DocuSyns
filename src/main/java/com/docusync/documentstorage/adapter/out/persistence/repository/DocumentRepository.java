package com.docusync.documentstorage.adapter.out.persistence.repository;

import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentEntity;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DocumentRepository extends JpaRepository<DocumentEntity, Long> {
    Page<DocumentEntity> findByFolderIdAndIsDeleted(Long folderId, boolean isDeleted, Pageable pageable);
    Page<DocumentEntity> findByFolderIdAndCreatedByAndIsDeleted(Long folderId, Long createdBy, boolean isDeleted, Pageable pageable);
    Page<DocumentEntity> findByCreatedByAndIsDeleted(Long createdBy, boolean isDeleted, Pageable pageable);
    Page<DocumentEntity> findByIsDeleted(boolean isDeleted, Pageable pageable);

    Page<DocumentEntity> findByTitleContainingIgnoreCaseAndIsDeleted(String title, boolean isDeleted, Pageable pageable);
    Page<DocumentEntity> findByFolderIdAndTitleContainingIgnoreCaseAndIsDeleted(Long folderId, String title, boolean isDeleted, Pageable pageable);
    Page<DocumentEntity> findByFolderIdAndCreatedByAndTitleContainingIgnoreCaseAndIsDeleted(Long folderId, Long createdBy, String title, boolean isDeleted, Pageable pageable);
    Page<DocumentEntity> findByCreatedByAndTitleContainingIgnoreCaseAndIsDeleted(Long createdBy, String title, boolean isDeleted, Pageable pageable);
}
