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
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/search")
@RequiredArgsConstructor
public class SearchController {

    private final DocumentRepository documentRepository;
    private final FolderRepository folderRepository;

    @GetMapping
    public ResponseEntity<Map<String, Object>> search(
            @RequestParam("q") String query,
            @RequestParam(value = "myOnly", required = false, defaultValue = "false") boolean myOnly,
            @RequestAttribute("userId") Long userId) {
            
        if (query == null || query.trim().isEmpty()) {
            return ResponseEntity.ok(Map.of("documents", List.of(), "folders", List.of()));
        }

        String keyword = query.trim();
        List<DocumentEntity> docs;
        List<FolderEntity> folders;

        if (myOnly) {
            docs = documentRepository.findByCreatedByAndTitleContainingIgnoreCaseAndIsDeleted(userId, keyword, false, Pageable.unpaged()).getContent();
            folders = folderRepository.findByNameContainingIgnoreCaseAndCreatedByAndIsDeleted(keyword, userId, false);
        } else {
            docs = documentRepository.findByTitleContainingIgnoreCaseAndIsDeleted(keyword, false, Pageable.unpaged()).getContent();
            folders = folderRepository.findByNameContainingIgnoreCaseAndIsDeleted(keyword, false);
        }

        Map<String, Object> response = new HashMap<>();
        response.put("documents", docs);
        response.put("folders", folders);

        return ResponseEntity.ok(response);
    }
}
