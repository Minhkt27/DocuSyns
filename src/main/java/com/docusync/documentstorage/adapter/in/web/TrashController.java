package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentEntity;
import com.docusync.documentstorage.adapter.out.persistence.entity.FolderEntity;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentRepository;
import com.docusync.documentstorage.adapter.out.persistence.repository.FolderRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/trash")
@RequiredArgsConstructor
public class TrashController {

    private final DocumentRepository documentRepository;
    private final FolderRepository folderRepository;

    @GetMapping
    public ResponseEntity<Map<String, Object>> getTrashItems() {
        List<DocumentEntity> trashedDocs = documentRepository.findByIsDeleted(true, Pageable.unpaged()).getContent();
        List<FolderEntity> trashedFolders = folderRepository.findByIsDeleted(true);

        Map<String, Object> response = new HashMap<>();
        response.put("documents", trashedDocs);
        response.put("folders", trashedFolders);
        return ResponseEntity.ok(response);
    }
}
