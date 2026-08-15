package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.application.domain.model.SystemSettings;
import com.docusync.documentstorage.application.service.SystemSettingsService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/settings")
@RequiredArgsConstructor
@Slf4j
public class SystemSettingsController {

    private final SystemSettingsService service;

    @GetMapping
    public ResponseEntity<SystemSettings> getSettings() {
        return ResponseEntity.ok(service.getSettings());
    }

    @PutMapping
    public ResponseEntity<SystemSettings> updateSettings(@RequestBody UpdateSettingsRequest request,
                                                         @RequestAttribute(name="userRole", required=false) String userRole) {
        log.info("Update settings called. Role: {}, Request: {}", userRole, request);
        if (!"ADMIN".equals(userRole)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        return ResponseEntity.ok(service.updateSettings(request.getMaxVersionsPerFile(), request.getTrashRetentionDays(), request.getClientAppVersion(), request.getClientAppUrl()));
    }

    public static class UpdateSettingsRequest {
        private Integer maxVersionsPerFile;
        private Integer trashRetentionDays;
        private String clientAppVersion;
        private String clientAppUrl;

        public UpdateSettingsRequest() {}

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

        public String getClientAppVersion() {
            return clientAppVersion;
        }

        public void setClientAppVersion(String clientAppVersion) {
            this.clientAppVersion = clientAppVersion;
        }

        public String getClientAppUrl() {
            return clientAppUrl;
        }

        public void setClientAppUrl(String clientAppUrl) {
            this.clientAppUrl = clientAppUrl;
        }
    }
}
