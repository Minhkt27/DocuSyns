package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.application.domain.model.Folder;
import com.docusync.documentstorage.application.service.FolderService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/folders")
@RequiredArgsConstructor
public class FolderController {

    private final FolderService folderService;

    @PostMapping
    public ResponseEntity<?> createFolder(
            @RequestBody Map<String, Object> body,
            @RequestAttribute("userId") Long userId,
            @RequestAttribute("userRole") String userRole) {

        String name = (String) body.get("name");
        Long parentId = body.get("parentId") != null ? ((Number) body.get("parentId")).longValue() : null;

        try {
            Folder folder = folderService.createFolder(name, parentId, userId, userRole);
            return ResponseEntity.ok(folder);
        } catch (SecurityException e) {
            return ResponseEntity.status(403).body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping
    public ResponseEntity<List<Folder>> getFolders(
            @RequestParam(value = "parentId", required = false) Long parentId) {
        List<Folder> folders;
        if (parentId == null) {
            folders = folderService.getRootFolders();
        } else {
            folders = folderService.getSubFolders(parentId);
        }
        return ResponseEntity.ok(folders);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Folder> getFolderById(@PathVariable("id") Long folderId) {
        return ResponseEntity.ok(folderService.getFolderById(folderId));
    }

    @PutMapping("/{id}/trash")
    public ResponseEntity<Void> moveToTrash(@PathVariable("id") Long folderId,
                                            @RequestAttribute("userId") Long userId,
                                            @RequestAttribute("userRole") String userRole) {
        if ("USER".equals(userRole)) {
            return ResponseEntity.status(403).build();
        }
        folderService.moveFolderToTrash(folderId, userId);
        return ResponseEntity.ok().build();
    }

    @PutMapping("/{id}/restore")
    public ResponseEntity<Void> restoreFromTrash(@PathVariable("id") Long folderId,
                                                 @RequestAttribute("userId") Long userId,
                                                 @RequestAttribute("userRole") String userRole) {
        if ("USER".equals(userRole)) {
            return ResponseEntity.status(403).build();
        }
        folderService.restoreFolderFromTrash(folderId, userId);
        return ResponseEntity.ok().build();
    }
}
