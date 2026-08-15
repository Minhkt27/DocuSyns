package com.docusync.documentstorage.adapter.out.persistence.mapper;

import com.docusync.documentstorage.adapter.out.persistence.entity.*;
import com.docusync.documentstorage.application.domain.model.*;
import org.springframework.stereotype.Component;

@Component
public class DocumentMapper {

    public Document toDomain(DocumentEntity entity, Long lockedBy, String lockedByName) {
        if (entity == null) return null;
        return new Document(
            entity.getId(),
            entity.getDocumentCode(),
            entity.getTitle(),
            entity.getCurrentVersionId(),
            entity.getCreatedBy(),
            entity.getFolderId(),
            entity.isDeleted(),
            lockedBy,
            lockedByName,
            entity.getDeletedAt(),
            entity.getCreatedAt()
        );
    }

    public DocumentEntity toEntity(Document domain) {
        if (domain == null) return null;
        return DocumentEntity.builder()
            .id(domain.id())
            .documentCode(domain.documentCode())
            .title(domain.title())
            .currentVersionId(domain.currentVersionId())
            .createdBy(domain.createdBy())
            .folderId(domain.folderId())
            .isDeleted(domain.isDeleted())
            .deletedAt(domain.deletedAt())
            .createdAt(domain.createdAt())
            .build();
    }

    public DocumentVersion toDomain(DocumentVersionEntity entity) {
        if (entity == null) return null;
        return new DocumentVersion(
            entity.getId(),
            entity.getDocumentId(),
            entity.getVersionNumber(),
            entity.getStorageFileId(),
            entity.getFileName(),
            entity.getFileSize(),
            entity.getUploadedBy(),
            entity.getUploadedAt(),
            entity.getNote(),
            entity.isDeleted(),
            entity.isPinned()
        );
    }

    public DocumentVersionEntity toEntity(DocumentVersion domain) {
        if (domain == null) return null;
        return DocumentVersionEntity.builder()
            .id(domain.id())
            .documentId(domain.documentId())
            .versionNumber(domain.versionNumber())
            .storageFileId(domain.storageFileId())
            .fileName(domain.fileName())
            .fileSize(domain.fileSize())
            .uploadedBy(domain.uploadedBy())
            .uploadedAt(domain.uploadedAt())
            .pinned(domain.pinned())
            .note(domain.note())
            .isDeleted(domain.isDeleted())
            .build();
    }

    public DocumentLock toDomain(DocumentLockEntity entity) {
        if (entity == null) return null;
        return new DocumentLock(
            entity.getId(),
            entity.getDocumentId(),
            entity.getLockedBy(),
            DocumentLock.LockStatus.valueOf(entity.getStatus().name())
        );
    }

    public DocumentLockEntity toEntity(DocumentLock domain) {
        if (domain == null) return null;
        return DocumentLockEntity.builder()
            .id(domain.id())
            .documentId(domain.documentId())
            .lockedBy(domain.lockedBy())
            .status(DocumentLockEntity.LockStatus.valueOf(domain.status().name()))
            .build();
    }

    // Folder mappings
    public Folder toDomain(FolderEntity entity) {
        if (entity == null) return null;
        return new Folder(
            entity.getId(),
            entity.getName(),
            entity.getParentId(),
            entity.getCreatedBy(),
            entity.getCreatedAt(),
            entity.isDeleted(),
            entity.getDeletedAt()
        );
    }

    public FolderEntity toEntity(Folder domain) {
        if (domain == null) return null;
        return FolderEntity.builder()
            .id(domain.id())
            .name(domain.name())
            .parentId(domain.parentId())
            .createdBy(domain.createdBy())
            .createdAt(domain.createdAt())
            .isDeleted(domain.isDeleted())
            .deletedAt(domain.deletedAt())
            .build();
    }
}
