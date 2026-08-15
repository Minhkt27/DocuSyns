package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.application.domain.model.Document;
import com.docusync.documentstorage.application.domain.model.Folder;
import com.docusync.documentstorage.application.port.in.ManageDocumentUseCase;
import com.docusync.documentstorage.application.service.FolderService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/trash")
@RequiredArgsConstructor
public class TrashController {

    private final ManageDocumentUseCase manageDocumentUseCase;
    private final FolderService folderService;

    @GetMapping
    public ResponseEntity<Map<String, Object>> getTrashItems(@RequestAttribute("userRole") String userRole) {
        if ("USER".equals(userRole)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        java.util.List<Document> trashedDocs = manageDocumentUseCase.getTrashedDocuments();
        java.util.List<Folder> trashedFolders = folderService.getTrashedFolders();

        Map<String, Object> response = new HashMap<>();
        response.put("documents", trashedDocs);
        response.put("folders", trashedFolders);
        return ResponseEntity.ok(response);
    }
}
