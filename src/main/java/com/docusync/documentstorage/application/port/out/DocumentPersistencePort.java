package com.docusync.documentstorage.application.port.out;

import com.docusync.documentstorage.application.domain.model.Document;
import com.docusync.documentstorage.application.domain.model.DocumentVersion;
import java.util.List;
import java.util.Optional;

import com.docusync.documentstorage.application.domain.model.PageResult;

public interface DocumentPersistencePort {
    Document saveDocument(Document document);
    Optional<Document> findDocumentById(Long id);
    DocumentVersion saveDocumentVersion(DocumentVersion version);
    Optional<DocumentVersion> findDocumentVersionById(Long id);
    List<DocumentVersion> findDocumentVersionsByDocumentId(Long documentId);
    Integer findMaxVersionNumberByDocumentId(Long documentId);
    PageResult<Document> findAllDocuments(String searchQuery, int page, int size);
    PageResult<Document> findDocumentsByFolderId(Long folderId, String searchQuery, int page, int size);
    PageResult<Document> findDocumentsByFolderIdAndCreatedBy(Long folderId, Long createdBy, String searchQuery, int page, int size);
    PageResult<Document> findDocumentsByCreatedBy(Long createdBy, String searchQuery, int page, int size);
}
