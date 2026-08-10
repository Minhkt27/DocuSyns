package com.docusync.documentstorage.adapter.out.persistence.repository;

import com.docusync.documentstorage.adapter.out.persistence.entity.FolderEntity;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FolderRepository extends JpaRepository<FolderEntity, Long> {
    List<FolderEntity> findByParentIdIsNullAndIsDeleted(boolean isDeleted);
    List<FolderEntity> findByParentIdAndIsDeleted(Long parentId, boolean isDeleted);
    List<FolderEntity> findByNameContainingIgnoreCaseAndIsDeleted(String name, boolean isDeleted);
    List<FolderEntity> findByIsDeleted(boolean isDeleted);
}
