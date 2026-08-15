package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.application.domain.model.Document;
import com.docusync.documentstorage.application.domain.model.Folder;
import com.docusync.documentstorage.application.port.in.ManageDocumentUseCase;
import com.docusync.documentstorage.application.service.FolderService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/search")
@RequiredArgsConstructor
public class SearchController {

    private final ManageDocumentUseCase manageDocumentUseCase;
    private final FolderService folderService;

    @GetMapping
    public ResponseEntity<Map<String, Object>> search(
            @RequestParam("q") String query,
            @RequestParam(value = "myOnly", required = false, defaultValue = "false") boolean myOnly,
            @RequestAttribute("userId") Long userId) {

        if (query == null || query.trim().isEmpty()) {
            return ResponseEntity.ok(Map.of("documents", List.of(), "folders", List.of()));
        }

        String keyword = query.trim();
        List<Document> docs = manageDocumentUseCase.searchDocuments(keyword, userId, myOnly);
        List<Folder> folders = folderService.searchFolders(keyword, userId, myOnly);

        Map<String, Object> response = new HashMap<>();
        response.put("documents", docs);
        response.put("folders", folders);

        return ResponseEntity.ok(response);
    }
}
