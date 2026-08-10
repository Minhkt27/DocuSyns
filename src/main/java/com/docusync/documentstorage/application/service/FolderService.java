package com.docusync.documentstorage.application.service;

import com.docusync.documentstorage.adapter.out.persistence.entity.FolderEntity;
import com.docusync.documentstorage.adapter.out.persistence.mapper.DocumentMapper;
import com.docusync.documentstorage.adapter.out.persistence.repository.FolderRepository;
import com.docusync.documentstorage.application.domain.model.Folder;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class FolderService {

    private final FolderRepository folderRepository;
    private final DocumentMapper mapper;
    private final ActivityLogService activityLogService;

    @Transactional
    public Folder createFolder(String name, Long parentId, Long userId, String role) {
        // Root folder (parentId == null) can only be created by ADMIN
        if (parentId == null && !"ADMIN".equals(role)) {
            throw new SecurityException("Only Admin can create root project folders.");
        }

        // Sub-folders can be created by ADMIN or PROJECT_MANAGER
        if (parentId != null && !"ADMIN".equals(role) && !"PROJECT_MANAGER".equals(role)) {
            throw new SecurityException("Only Admin or Project Manager can create sub-folders.");
        }

        // If parentId is provided, verify it exists
        if (parentId != null) {
            folderRepository.findById(parentId)
                .orElseThrow(() -> new RuntimeException("Parent folder not found with id: " + parentId));
        }

        FolderEntity entity = FolderEntity.builder()
            .name(name)
            .parentId(parentId)
            .createdBy(userId)
            .createdAt(LocalDateTime.now())
            .isDeleted(false)
            .build();

        FolderEntity savedEntity = folderRepository.save(entity);
        activityLogService.logActivity(userId, "CREATE_FOLDER", savedEntity.getId(), "FOLDER");
        return mapper.toDomain(savedEntity);
    }

    public List<Folder> getRootFolders() {
        return folderRepository.findByParentIdIsNullAndIsDeleted(false).stream().map(mapper::toDomain).toList();
    }

    public List<Folder> getSubFolders(Long parentId) {
        return folderRepository.findByParentIdAndIsDeleted(parentId, false).stream().map(mapper::toDomain).toList();
    }

    public Folder getFolderById(Long folderId) {
        return folderRepository.findById(folderId)
            .map(mapper::toDomain)
            .orElseThrow(() -> new RuntimeException("Folder not found with id: " + folderId));
    }

    @Transactional
    public void moveFolderToTrash(Long folderId, Long userId) {
        FolderEntity entity = folderRepository.findById(folderId)
                .orElseThrow(() -> new RuntimeException("Folder not found"));
        entity.setDeleted(true);
        folderRepository.save(entity);
        activityLogService.logActivity(userId, "TRASH_FOLDER", folderId, "FOLDER");
    }

    @Transactional
    public void restoreFolderFromTrash(Long folderId, Long userId) {
        FolderEntity entity = folderRepository.findById(folderId)
                .orElseThrow(() -> new RuntimeException("Folder not found"));
        entity.setDeleted(false);
        folderRepository.save(entity);
        activityLogService.logActivity(userId, "RESTORE_FOLDER", folderId, "FOLDER");
    }
}
