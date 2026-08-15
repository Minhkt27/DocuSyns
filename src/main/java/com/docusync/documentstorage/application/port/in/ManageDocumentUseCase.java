package com.docusync.documentstorage.application.port.in;

import com.docusync.documentstorage.application.domain.model.Document;
import com.docusync.documentstorage.application.domain.model.DocumentVersion;
import com.docusync.documentstorage.application.domain.model.PageResult;
import com.docusync.documentstorage.application.domain.model.FileDownload;
import java.io.InputStream;
import java.util.List;

public interface ManageDocumentUseCase {
    DocumentVersion uploadNewVersion(Long documentId, Long userId, String fileName, InputStream content, Long fileSize, String note);
    DocumentVersion rollbackToVersion(Long documentId, Long userId, Long versionId);
    List<DocumentVersion> getVersionHistory(Long documentId);
    FileDownload downloadSpecificVersion(Long documentId, Long versionId, Long userId);
    PageResult<Document> getAllDocuments(String searchQuery, int page, int size);
    PageResult<Document> getDocumentsByFolder(Long folderId, String searchQuery, int page, int size);
    PageResult<Document> getDocumentsByFolderAndUser(Long folderId, Long userId, String searchQuery, int page, int size);
    PageResult<Document> getDocumentsByUser(Long userId, String searchQuery, int page, int size);
    Document createDocument(Long userId, String title, String fileName, InputStream content, Long fileSize, Long folderId);
    FileDownload downloadDocument(Long documentId, Long userId);
    void moveDocumentToTrash(Long documentId, Long userId);
    void restoreDocumentFromTrash(Long documentId, Long userId);
    List<Document> getTrashedDocuments();
    List<Document> searchDocuments(String keyword, Long userId, boolean myOnly);
    void setVersionPinned(Long documentId, Long versionId, Long userId, boolean pinned);
}
