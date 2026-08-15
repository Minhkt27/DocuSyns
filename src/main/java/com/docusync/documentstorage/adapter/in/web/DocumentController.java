package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.application.domain.model.DocumentVersion;
import com.docusync.documentstorage.application.port.in.LockDocumentUseCase;
import com.docusync.documentstorage.application.port.in.ManageDocumentUseCase;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

import java.io.IOException;
import java.io.InputStream;
import java.util.List;

@RestController
@RequestMapping("/api/v1/documents")
@RequiredArgsConstructor
public class DocumentController {

    private final ManageDocumentUseCase manageDocumentUseCase;
    private final LockDocumentUseCase lockDocumentUseCase;

    @PostMapping("/{id}/lock")
    public ResponseEntity<Void> lockDocument(@PathVariable("id") Long documentId,
                                             @RequestAttribute("userId") Long userId) {
        lockDocumentUseCase.lockDocument(documentId, userId);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/unlock")
    public ResponseEntity<Void> unlockDocument(@PathVariable("id") Long documentId,
                                               @RequestAttribute("userId") Long userId,
                                               @RequestAttribute("userRole") String userRole) {
        boolean force = "ADMIN".equals(userRole);
        lockDocumentUseCase.unlockDocument(documentId, userId, force);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/upload")
    public ResponseEntity<DocumentVersion> uploadVersion(@PathVariable("id") Long documentId,
                                                         @RequestParam("file") MultipartFile file,
                                                         @RequestParam(value = "note", required = false) String note,
                                                         @RequestAttribute("userId") Long userId) throws IOException {
        DocumentVersion version = manageDocumentUseCase.uploadNewVersion(
                documentId, 
                userId, 
                file.getOriginalFilename(), 
                file.getInputStream(), 
                file.getSize(),
                note
        );
        return ResponseEntity.ok(version);
    }

    @GetMapping
    public ResponseEntity<com.docusync.documentstorage.application.domain.model.PageResult<com.docusync.documentstorage.application.domain.model.Document>> getDocuments(
            @RequestParam(value = "folderId", required = false) Long folderId,
            @RequestParam(value = "searchQuery", required = false) String searchQuery,
            @RequestParam(value = "myOnly", required = false, defaultValue = "false") boolean myOnly,
            @RequestParam(value = "page", required = false, defaultValue = "0") int page,
            @RequestParam(value = "size", required = false, defaultValue = "20") int size,
            @RequestAttribute("userId") Long userId) {
        
        com.docusync.documentstorage.application.domain.model.PageResult<com.docusync.documentstorage.application.domain.model.Document> docs;
        
        if (folderId != null) {
            if (myOnly) {
                docs = manageDocumentUseCase.getDocumentsByFolderAndUser(folderId, userId, searchQuery, page, size);
            } else {
                docs = manageDocumentUseCase.getDocumentsByFolder(folderId, searchQuery, page, size);
            }
        } else {
            if (myOnly) {
                docs = manageDocumentUseCase.getDocumentsByUser(userId, searchQuery, page, size);
            } else {
                docs = manageDocumentUseCase.getAllDocuments(searchQuery, page, size);
            }
        }
        
        return ResponseEntity.ok(docs);
    }

    @PostMapping
    public ResponseEntity<com.docusync.documentstorage.application.domain.model.Document> createDocument(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "folderId", required = false) Long folderId,
            @RequestAttribute("userId") Long userId) throws IOException {
        com.docusync.documentstorage.application.domain.model.Document doc = manageDocumentUseCase.createDocument(
                userId,
                file.getOriginalFilename(),
                file.getOriginalFilename(),
                file.getInputStream(),
                file.getSize(),
                folderId
        );
        return ResponseEntity.ok(doc);
    }

    @GetMapping("/{id}/download")
    public ResponseEntity<Resource> downloadDocument(
            @PathVariable("id") Long documentId,
            @RequestAttribute("userId") Long userId) {
        
        com.docusync.documentstorage.application.domain.model.FileDownload fileDownload = manageDocumentUseCase.downloadDocument(documentId, userId);
        InputStreamResource resource = new InputStreamResource(fileDownload.stream());
        
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + fileDownload.fileName() + "\"")
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(resource);
    }

    @GetMapping("/{id}/versions")
    public ResponseEntity<List<DocumentVersion>> getVersionHistory(@PathVariable("id") Long documentId) {
        List<DocumentVersion> history = manageDocumentUseCase.getVersionHistory(documentId);
        return ResponseEntity.ok(history);
    }

    @GetMapping("/{id}/versions/{versionId}/download")
    public ResponseEntity<Resource> downloadSpecificVersion(
            @PathVariable("id") Long documentId,
            @PathVariable("versionId") Long versionId,
            @RequestAttribute("userId") Long userId) {
        
        com.docusync.documentstorage.application.domain.model.FileDownload fileDownload = manageDocumentUseCase.downloadSpecificVersion(documentId, versionId, userId);
        InputStreamResource resource = new InputStreamResource(fileDownload.stream());
        
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + fileDownload.fileName() + "\"")
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(resource);
    }

    @PostMapping("/{id}/versions/{versionId}/pin")
    public ResponseEntity<Void> pinVersion(
            @PathVariable("id") Long documentId,
            @PathVariable("versionId") Long versionId,
            @RequestAttribute("userId") Long userId) {
        manageDocumentUseCase.setVersionPinned(documentId, versionId, userId, true);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/versions/{versionId}/unpin")
    public ResponseEntity<Void> unpinVersion(
            @PathVariable("id") Long documentId,
            @PathVariable("versionId") Long versionId,
            @RequestAttribute("userId") Long userId) {
        manageDocumentUseCase.setVersionPinned(documentId, versionId, userId, false);
        return ResponseEntity.ok().build();
    }

    @PostMapping("/{id}/rollback")
    public ResponseEntity<DocumentVersion> rollbackToVersion(
            @PathVariable("id") Long documentId,
            @RequestParam("versionId") Long versionId,
            @RequestAttribute("userId") Long userId) {
        
        DocumentVersion version = manageDocumentUseCase.rollbackToVersion(documentId, userId, versionId);
        return ResponseEntity.ok(version);
    }

    @PutMapping("/{id}/trash")
    public ResponseEntity<Void> moveToTrash(@PathVariable("id") Long documentId,
                                            @RequestAttribute("userId") Long userId,
                                            @RequestAttribute("userRole") String userRole) {
        if ("USER".equals(userRole)) {
            return ResponseEntity.status(403).build();
        }
        manageDocumentUseCase.moveDocumentToTrash(documentId, userId);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/{id}/restore")
    public ResponseEntity<Void> restoreFromTrash(@PathVariable("id") Long documentId,
                                                 @RequestAttribute("userId") Long userId,
                                                 @RequestAttribute("userRole") String userRole) {
        if ("USER".equals(userRole)) {
            return ResponseEntity.status(403).build();
        }
        manageDocumentUseCase.restoreDocumentFromTrash(documentId, userId);
        return ResponseEntity.ok().build();
    }
}
