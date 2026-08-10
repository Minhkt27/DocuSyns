package com.docusync.documentstorage.adapter.out.persistence;

import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentEntity;
import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentVersionEntity;
import com.docusync.documentstorage.adapter.out.persistence.mapper.DocumentMapper;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentRepository;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentVersionRepository;
import com.docusync.documentstorage.application.domain.model.Document;
import com.docusync.documentstorage.application.domain.model.DocumentVersion;
import com.docusync.documentstorage.application.domain.model.PageResult;
import com.docusync.documentstorage.application.port.out.DocumentPersistencePort;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class DocumentPersistenceAdapter implements DocumentPersistencePort {

    private final DocumentRepository documentRepository;
    private final DocumentVersionRepository versionRepository;
    private final com.docusync.documentstorage.adapter.out.persistence.repository.DocumentLockRepository lockRepository;
    private final com.docusync.auth.repository.UserRepository userRepository;
    private final DocumentMapper mapper;

    @Override
    public Document saveDocument(Document document) {
        DocumentEntity entity = mapper.toEntity(document);
        return mapper.toDomain(documentRepository.save(entity), document.lockedBy(), document.lockedByName());
    }

    @Override
    public Optional<Document> findDocumentById(Long id) {
        return documentRepository.findById(id).map(entity -> {
            Long lockedBy = lockRepository.findByDocumentIdAndStatus(id, com.docusync.documentstorage.adapter.out.persistence.entity.DocumentLockEntity.LockStatus.LOCKED)
                .map(com.docusync.documentstorage.adapter.out.persistence.entity.DocumentLockEntity::getLockedBy).orElse(null);
            String lockedByName = null;
            if (lockedBy != null) {
                lockedByName = userRepository.findById(lockedBy).map(com.docusync.documentstorage.adapter.out.persistence.entity.UserEntity::getFullName).orElse(null);
            }
            return mapper.toDomain(entity, lockedBy, lockedByName);
        });
    }

    @Override
    public DocumentVersion saveDocumentVersion(DocumentVersion version) {
        DocumentVersionEntity entity = mapper.toEntity(version);
        return mapper.toDomain(versionRepository.save(entity));
    }

    @Override
    public Optional<DocumentVersion> findDocumentVersionById(Long id) {
        return versionRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<DocumentVersion> findDocumentVersionsByDocumentId(Long documentId) {
        return versionRepository.findByDocumentIdAndIsDeletedFalseOrderByVersionNumberDesc(documentId)
                .stream().map(mapper::toDomain).toList();
    }

    @Override
    public Integer findMaxVersionNumberByDocumentId(Long documentId) {
        DocumentVersionEntity entity = versionRepository.findTopByDocumentIdAndIsDeletedFalseOrderByVersionNumberDesc(documentId);
        return entity != null ? entity.getVersionNumber() : 0;
    }

    private PageResult<Document> toPageResult(Page<DocumentEntity> page) {
        List<DocumentEntity> entities = page.getContent();
        List<Long> docIds = entities.stream().map(DocumentEntity::getId).toList();
        
        java.util.Map<Long, Long> lockMap = new java.util.HashMap<>();
        if (!docIds.isEmpty()) {
            lockRepository.findByDocumentIdInAndStatus(docIds, com.docusync.documentstorage.adapter.out.persistence.entity.DocumentLockEntity.LockStatus.LOCKED)
                .forEach(lock -> lockMap.put(lock.getDocumentId(), lock.getLockedBy()));
        }
        
        java.util.Map<Long, String> userMap = new java.util.HashMap<>();
        if (!lockMap.isEmpty()) {
            java.util.List<Long> userIds = lockMap.values().stream().distinct().toList();
            userRepository.findAllById(userIds)
                .forEach(user -> userMap.put(user.getId(), user.getFullName()));
        }
        
        List<Document> content = entities.stream()
            .map(e -> {
                Long lockedBy = lockMap.get(e.getId());
                String lockedByName = lockedBy != null ? userMap.get(lockedBy) : null;
                return mapper.toDomain(e, lockedBy, lockedByName);
            })
            .toList();
        return new PageResult<>(
                content,
                page.getNumber(),
                page.getTotalPages(),
                page.getTotalElements(),
                page.hasNext()
        );
    }

    @Override
    public PageResult<Document> findAllDocuments(String searchQuery, int page, int size) {
        org.springframework.data.domain.Sort sort = org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "currentVersionId");
        Pageable pageable = PageRequest.of(page, size, sort);
        if (searchQuery != null && !searchQuery.trim().isEmpty()) {
            return toPageResult(documentRepository.findByTitleContainingIgnoreCaseAndIsDeleted(searchQuery.trim(), false, pageable));
        }
        return toPageResult(documentRepository.findByIsDeleted(false, pageable));
    }

    @Override
    public PageResult<Document> findDocumentsByFolderId(Long folderId, String searchQuery, int page, int size) {
        org.springframework.data.domain.Sort sort = org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "currentVersionId");
        Pageable pageable = PageRequest.of(page, size, sort);
        if (searchQuery != null && !searchQuery.trim().isEmpty()) {
            return toPageResult(documentRepository.findByFolderIdAndTitleContainingIgnoreCaseAndIsDeleted(folderId, searchQuery.trim(), false, pageable));
        }
        return toPageResult(documentRepository.findByFolderIdAndIsDeleted(folderId, false, pageable));
    }

    @Override
    public PageResult<Document> findDocumentsByFolderIdAndCreatedBy(Long folderId, Long createdBy, String searchQuery, int page, int size) {
        org.springframework.data.domain.Sort sort = org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "currentVersionId");
        Pageable pageable = PageRequest.of(page, size, sort);
        if (searchQuery != null && !searchQuery.trim().isEmpty()) {
            return toPageResult(documentRepository.findByFolderIdAndCreatedByAndTitleContainingIgnoreCaseAndIsDeleted(folderId, createdBy, searchQuery.trim(), false, pageable));
        }
        return toPageResult(documentRepository.findByFolderIdAndCreatedByAndIsDeleted(folderId, createdBy, false, pageable));
    }

    @Override
    public PageResult<Document> findDocumentsByCreatedBy(Long createdBy, String searchQuery, int page, int size) {
        org.springframework.data.domain.Sort sort = org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.DESC, "currentVersionId");
        Pageable pageable = PageRequest.of(page, size, sort);
        if (searchQuery != null && !searchQuery.trim().isEmpty()) {
            return toPageResult(documentRepository.findByCreatedByAndTitleContainingIgnoreCaseAndIsDeleted(createdBy, searchQuery.trim(), false, pageable));
        }
        return toPageResult(documentRepository.findByCreatedByAndIsDeleted(createdBy, false, pageable));
    }
}
