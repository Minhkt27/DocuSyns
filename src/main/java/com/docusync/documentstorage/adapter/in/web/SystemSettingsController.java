package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.application.domain.model.SystemSettings;
import com.docusync.documentstorage.application.service.SystemSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/settings")
@RequiredArgsConstructor
public class SystemSettingsController {

    private final SystemSettingsService service;

    @GetMapping
    public ResponseEntity<SystemSettings> getSettings() {
        return ResponseEntity.ok(service.getSettings());
    }

    @PutMapping
    public ResponseEntity<SystemSettings> updateSettings(@RequestBody UpdateSettingsRequest request,
            @RequestAttribute(name = "userRole", required = false) String userRole) {
        System.out.println("UPDATE SETTINGS CALLED. Role: " + userRole + ", Request: " + request);
        if (!"ADMIN".equals(userRole)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        return ResponseEntity
                .ok(service.updateSettings(request.getMaxVersionsPerFile(), request.getTrashRetentionDays()));
    }

    public static class UpdateSettingsRequest {
        private Integer maxVersionsPerFile;
        private Integer trashRetentionDays;

        public UpdateSettingsRequest() {
        }

        public Integer getMaxVersionsPerFile() {
            return maxVersionsPerFile;
        }

        public void setMaxVersionsPerFile(Integer maxVersionsPerFile) {
            this.maxVersionsPerFile = maxVersionsPerFile;
        }

        public Integer getTrashRetentionDays() {
            return trashRetentionDays;
        }

        public void setTrashRetentionDays(Integer trashRetentionDays) {
            this.trashRetentionDays = trashRetentionDays;
        }
    }
}
