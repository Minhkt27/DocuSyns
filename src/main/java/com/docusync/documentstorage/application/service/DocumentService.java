package com.docusync.documentstorage.application.service;

import com.docusync.documentstorage.application.domain.model.Document;
import com.docusync.documentstorage.application.domain.model.DocumentLock;
import com.docusync.documentstorage.application.domain.model.DocumentVersion;
import com.docusync.documentstorage.application.domain.model.PageResult;
import com.docusync.documentstorage.application.domain.model.FileDownload;
import com.docusync.documentstorage.application.port.in.ManageDocumentUseCase;
import com.docusync.documentstorage.application.port.out.DocumentLockPort;
import com.docusync.documentstorage.application.port.out.DocumentPersistencePort;
import com.docusync.documentstorage.application.port.out.FileStoragePort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.InputStream;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DocumentService implements ManageDocumentUseCase {

    private final DocumentPersistencePort documentPersistencePort;
    private final DocumentLockPort documentLockPort;
    private final FileStoragePort fileStoragePort;
    private final ActivityLogService activityLogService;
    private final SystemSettingsService systemSettingsService;

    @Override
    @Transactional
    public DocumentVersion uploadNewVersion(Long documentId, Long userId, String fileName, InputStream content, Long fileSize, String note) {
        validateFileType(fileName);
        
        Document document = documentPersistencePort.findDocumentById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        // Verify Lock
        DocumentLock lock = documentLockPort.getActiveLockForDocument(documentId)
                .orElseThrow(() -> new RuntimeException("Document is not locked. Lock it before uploading."));
        
        if (!lock.lockedBy().equals(userId)) {
            throw new SecurityException("User does not hold the lock for this document");
        }

        // Upload to storage
        String storageFileId = fileStoragePort.uploadFile(fileName, content, "application/octet-stream");

        // Enforce Max Versions Limit
        int maxVersions = systemSettingsService.getSettings().maxVersionsPerFile();
        List<DocumentVersion> activeVersions = documentPersistencePort.findDocumentVersionsByDocumentId(documentId);
        
        // We are adding 1 new version, so we can keep at most (maxVersions - 1) existing versions
        if (activeVersions.size() >= maxVersions) {
            int versionsToKeep = Math.max(0, maxVersions - 1);
            if (versionsToKeep < activeVersions.size()) {
                List<DocumentVersion> versionsToDelete = activeVersions.subList(versionsToKeep, activeVersions.size());
                for (DocumentVersion v : versionsToDelete) {
                    DocumentVersion deletedV = new DocumentVersion(v.id(), v.documentId(), v.versionNumber(), v.storageFileId(), v.fileName(), v.fileSize(), v.uploadedBy(), v.uploadedAt(), v.note(), true);
                    documentPersistencePort.saveDocumentVersion(deletedV);
                }
            }
        }

        // Save Version
        DocumentVersion version = new DocumentVersion(null, documentId, getNextVersion(documentId), storageFileId, fileName, fileSize, userId, java.time.LocalDateTime.now(), note, false);
        version = documentPersistencePort.saveDocumentVersion(version);

        // Update Document Current Version
        Document updatedDocument = new Document(document.id(), document.documentCode(), document.title(), version.id(), document.createdBy(), document.folderId(), document.isDeleted(), document.lockedBy(), document.lockedByName());
        documentPersistencePort.saveDocument(updatedDocument);

        // Auto release lock after upload
        documentLockPort.releaseLock(documentId, userId, false);

        activityLogService.logActivity(userId, "UPLOAD_VERSION", documentId, "DOCUMENT");

        return version;
    }

    @Override
    @Transactional
    public DocumentVersion rollbackToVersion(Long documentId, Long userId, Long versionId) {
        Document document = documentPersistencePort.findDocumentById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));

        // Only Admin or PM should be able to rollback. We can check role at controller level, but here we just verify lock/access.
        DocumentLock lock = documentLockPort.getActiveLockForDocument(documentId)
                .orElseThrow(() -> new RuntimeException("Document is not locked. Lock it before rollback."));
        
        if (!lock.lockedBy().equals(userId)) {
            throw new SecurityException("User does not hold the lock for this document");
        }

        DocumentVersion version = documentPersistencePort.findDocumentVersionById(versionId)
                .orElseThrow(() -> new RuntimeException("Version not found"));

        if (!version.documentId().equals(documentId)) {
            throw new IllegalArgumentException("Version does not belong to this document");
        }

        Document updatedDocument = new Document(document.id(), document.documentCode(), document.title(), version.id(), document.createdBy(), document.folderId(), document.isDeleted(), document.lockedBy(), document.lockedByName());
        documentPersistencePort.saveDocument(updatedDocument);

        documentLockPort.releaseLock(documentId, userId, false);

        activityLogService.logActivity(userId, "ROLLBACK_VERSION", documentId, "DOCUMENT");

        return version;
    }

    @Override
    public List<DocumentVersion> getVersionHistory(Long documentId) {
        return documentPersistencePort.findDocumentVersionsByDocumentId(documentId);
    }

    @Override
    public FileDownload downloadSpecificVersion(Long documentId, Long versionId, Long userId) {
        DocumentVersion version = documentPersistencePort.findDocumentVersionById(versionId)
                .orElseThrow(() -> new RuntimeException("Version not found"));
                
        if (!version.documentId().equals(documentId)) {
            throw new IllegalArgumentException("Version does not belong to this document");
        }
        
        return new FileDownload(fileStoragePort.downloadFile(version.storageFileId()), version.fileName());
    }

    private Integer getNextVersion(Long documentId) {
        Integer maxVersion = documentPersistencePort.findMaxVersionNumberByDocumentId(documentId);
        return maxVersion + 1;
    }

    @Override
    public PageResult<Document> getAllDocuments(String searchQuery, int page, int size) {
        return documentPersistencePort.findAllDocuments(searchQuery, page, size);
    }

    @Override
    public PageResult<Document> getDocumentsByFolder(Long folderId, String searchQuery, int page, int size) {
        return documentPersistencePort.findDocumentsByFolderId(folderId, searchQuery, page, size);
    }

    @Override
    public PageResult<Document> getDocumentsByFolderAndUser(Long folderId, Long userId, String searchQuery, int page, int size) {
        return documentPersistencePort.findDocumentsByFolderIdAndCreatedBy(folderId, userId, searchQuery, page, size);
    }

    @Override
    public PageResult<Document> getDocumentsByUser(Long userId, String searchQuery, int page, int size) {
        return documentPersistencePort.findDocumentsByCreatedBy(userId, searchQuery, page, size);
    }

    @Override
    @Transactional
    public Document createDocument(Long userId, String title, String fileName, InputStream content, Long fileSize, Long folderId) {
        validateFileType(fileName);
        
        String storageFileId = fileStoragePort.uploadFile(fileName, content, "application/octet-stream");
        
        // 1. Create Document with folderId
        Document document = new Document(null, "DOC-" + System.currentTimeMillis(), title, null, userId, folderId, false, null, null);
        document = documentPersistencePort.saveDocument(document);

        // 2. Create Version
        DocumentVersion version = new DocumentVersion(null, document.id(), 1, storageFileId, fileName, fileSize, userId, java.time.LocalDateTime.now(), "Initial Upload", false);
        version = documentPersistencePort.saveDocumentVersion(version);

        // 3. Update Document with current version
        Document updatedDocument = new Document(document.id(), document.documentCode(), document.title(), version.id(), document.createdBy(), document.folderId(), document.isDeleted(), document.lockedBy(), document.lockedByName());
        updatedDocument = documentPersistencePort.saveDocument(updatedDocument);

        activityLogService.logActivity(userId, "CREATE_DOCUMENT", updatedDocument.id(), "DOCUMENT");

        return updatedDocument;
    }

    @Override
    public FileDownload downloadDocument(Long documentId, Long userId) {
        Document document = documentPersistencePort.findDocumentById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));
        
        if (document.currentVersionId() == null) {
            throw new RuntimeException("Document has no versions");
        }
        
        DocumentVersion version = documentPersistencePort.findDocumentVersionById(document.currentVersionId())
                .orElseThrow(() -> new RuntimeException("Version not found"));
                
        return new FileDownload(fileStoragePort.downloadFile(version.storageFileId()), version.fileName());
    }

    private void validateFileType(String fileName) {
        if (fileName == null || !fileName.contains(".")) return;
        
        String extension = fileName.substring(fileName.lastIndexOf(".")).toLowerCase();
        List<String> blacklist = List.of(
            ".exe", ".bat", ".cmd", ".msi", ".vbs", ".vbe", ".wsf", ".wsh", ".ps1", ".scr", ".pif", ".com", ".cpl", ".dll",
            ".sh", ".bash", ".app", ".dmg",
            ".php", ".php5", ".phtml", ".jsp", ".jspx", ".asp", ".aspx", ".py", ".rb", ".pl", ".cgi", ".war",
            ".js", ".jse", ".jar"
        );
        
        if (blacklist.contains(extension)) {
            throw new IllegalArgumentException("File type " + extension + " is not allowed for security reasons.");
        }
    }

    @Override
    @Transactional
    public void moveDocumentToTrash(Long documentId, Long userId) {
        Document document = documentPersistencePort.findDocumentById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));
                
        if (document.lockedBy() != null) {
            throw new RuntimeException("Cannot delete document because it is currently locked.");
        }
        
        Document updatedDocument = new Document(
            document.id(), document.documentCode(), document.title(), 
            document.currentVersionId(), document.createdBy(), document.folderId(), true, document.lockedBy(), document.lockedByName()
        );
        documentPersistencePort.saveDocument(updatedDocument);
        activityLogService.logActivity(userId, "TRASH_DOCUMENT", documentId, "DOCUMENT");
    }

    @Override
    @Transactional
    public void restoreDocumentFromTrash(Long documentId, Long userId) {
        Document document = documentPersistencePort.findDocumentById(documentId)
                .orElseThrow(() -> new RuntimeException("Document not found"));
        
        Document updatedDocument = new Document(
            document.id(), document.documentCode(), document.title(), 
            document.currentVersionId(), document.createdBy(), document.folderId(), false, document.lockedBy(), document.lockedByName()
        );
        documentPersistencePort.saveDocument(updatedDocument);
        activityLogService.logActivity(userId, "RESTORE_DOCUMENT", documentId, "DOCUMENT");
    }
}
