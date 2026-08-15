package com.docusync.documentstorage.application.service;

import com.docusync.documentstorage.adapter.out.persistence.entity.ActivityLogEntity;
import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentEntity;
import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentVersionEntity;
import com.docusync.documentstorage.adapter.out.persistence.entity.FolderEntity;
import com.docusync.documentstorage.adapter.out.persistence.repository.ActivityLogRepository;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentRepository;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentVersionRepository;
import com.docusync.documentstorage.adapter.out.persistence.repository.FolderRepository;
import com.docusync.documentstorage.application.domain.model.SystemSettings;
import com.docusync.documentstorage.application.port.out.FileStoragePort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class TrashCleanupJob {

    private final SystemSettingsService systemSettingsService;
    private final DocumentRepository documentRepository;
    private final FolderRepository folderRepository;
    private final DocumentVersionRepository versionRepository;
    private final FileStoragePort fileStoragePort;

    // Run every night at 2:00 AM
    @Scheduled(cron = "0 0 2 * * ?")
    @Transactional
    public void cleanupTrash() {
        log.info("Starting scheduled Trash Cleanup Job...");
        SystemSettings settings = systemSettingsService.getSettings();
        int retentionDays = settings.trashRetentionDays();

        LocalDateTime threshold = LocalDateTime.now().minusDays(retentionDays);

        // 1. Cleanup old versions
        List<DocumentVersionEntity> deletedVersions = versionRepository.findByIsDeletedTrue();
        for (DocumentVersionEntity version : deletedVersions) {
            if (version.isPinned()) {
                continue; // pinned versions are never purged, regardless of age
            }
            // Note: In a production system, we'd check exactly when it was soft-deleted.
            // For now, if the version was uploaded before the threshold and is deleted, we hard delete it.
            if (version.getUploadedAt().isBefore(threshold)) {
                log.info("Hard deleting document version ID: {}", version.getId());
                deletePhysicalFile(version.getStorageFileId());
                versionRepository.delete(version);
            }
        }

        // 2. Cleanup deleted documents past the retention threshold
        List<DocumentEntity> deletedDocs = documentRepository.findByIsDeleted(true, Pageable.unpaged()).getContent();
        for (DocumentEntity doc : deletedDocs) {
            if (doc.getDeletedAt() == null || doc.getDeletedAt().isAfter(threshold)) {
                continue;
            }
            log.info("Hard deleting document ID: {}", doc.getId());
            // Delete all its versions
            List<DocumentVersionEntity> versions = versionRepository.findByDocumentId(doc.getId());
            for (DocumentVersionEntity v : versions) {
                deletePhysicalFile(v.getStorageFileId());
                versionRepository.delete(v);
            }
            documentRepository.delete(doc);
        }

        // 3. Cleanup deleted folders past the retention threshold
        List<FolderEntity> deletedFolders = folderRepository.findByIsDeleted(true);
        for (FolderEntity folder : deletedFolders) {
            if (folder.getDeletedAt() == null || folder.getDeletedAt().isAfter(threshold)) {
                continue;
            }
            log.info("Hard deleting folder ID: {}", folder.getId());
            folderRepository.delete(folder);
        }

        log.info("Trash Cleanup Job completed.");
    }

    private void deletePhysicalFile(String storageFileId) {
        try {
            fileStoragePort.deleteFile(storageFileId);
        } catch (Exception e) {
            // Don't let a missing/unreachable physical file abort the whole cleanup run.
            log.warn("Failed to delete physical file for storageFileId {}: {}", storageFileId, e.getMessage());
        }
    }
}
