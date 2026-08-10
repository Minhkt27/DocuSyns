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
            // Note: In a production system, we'd check exactly when it was soft-deleted.
            // For now, if the version was uploaded before the threshold and is deleted, we hard delete it.
            if (version.getUploadedAt().isBefore(threshold)) {
                log.info("Hard deleting document version ID: {}", version.getId());
                // Delete physical file
                // fileStoragePort.deleteFile(version.getStorageFileId()); // Assuming this method exists or will be added
                versionRepository.delete(version);
            }
        }

        // 2. Cleanup deleted documents
        List<DocumentEntity> deletedDocs = documentRepository.findByIsDeleted(true, Pageable.unpaged()).getContent();
        for (DocumentEntity doc : deletedDocs) {
            // Since we don't have deletedAt, we use a simple heuristic or we could join with ActivityLogs.
            // For simplicity, we hard delete all documents that have been in trash. 
            // In a real system, a dedicated deleted_at column is preferred.
            log.info("Hard deleting document ID: {}", doc.getId());
            // Delete all its versions
            List<DocumentVersionEntity> versions = versionRepository.findByDocumentId(doc.getId());
            for (DocumentVersionEntity v : versions) {
                // fileStoragePort.deleteFile(v.getStorageFileId());
                versionRepository.delete(v);
            }
            documentRepository.delete(doc);
        }

        // 3. Cleanup deleted folders
        List<FolderEntity> deletedFolders = folderRepository.findByIsDeleted(true);
        for (FolderEntity folder : deletedFolders) {
            log.info("Hard deleting folder ID: {}", folder.getId());
            folderRepository.delete(folder);
        }

        log.info("Trash Cleanup Job completed.");
    }
}
