package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.adapter.out.persistence.entity.ActivityLogEntity;
import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentEntity;
import com.docusync.documentstorage.adapter.out.persistence.entity.FolderEntity;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentRepository;
import com.docusync.documentstorage.adapter.out.persistence.repository.FolderRepository;
import com.docusync.documentstorage.application.service.ActivityLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/activities")
@RequiredArgsConstructor
public class ActivityLogController {

    private final ActivityLogService activityLogService;
    private final com.docusync.auth.repository.UserRepository userRepository;
    private final DocumentRepository documentRepository;
    private final FolderRepository folderRepository;

    @GetMapping
    public ResponseEntity<List<ActivityLogDTO>> getRecentActivities() {
        List<ActivityLogEntity> logs = activityLogService.getRecentActivities();

        List<Long> userIds = logs.stream().map(ActivityLogEntity::getUserId).distinct().toList();
        Map<Long, String> userNames = new HashMap<>();
        userRepository.findAllById(userIds).forEach(u -> userNames.put(u.getId(), u.getFullName()));

        List<Long> documentIds = logs.stream()
                .filter(l -> "DOCUMENT".equals(l.getTargetType()))
                .map(ActivityLogEntity::getTargetId)
                .distinct().toList();
        Map<Long, String> documentTitles = new HashMap<>();
        if (!documentIds.isEmpty()) {
            documentRepository.findAllById(documentIds).forEach(d -> documentTitles.put(d.getId(), d.getTitle()));
        }

        List<Long> folderIds = logs.stream()
                .filter(l -> "FOLDER".equals(l.getTargetType()))
                .map(ActivityLogEntity::getTargetId)
                .distinct().toList();
        Map<Long, String> folderNames = new HashMap<>();
        if (!folderIds.isEmpty()) {
            folderRepository.findAllById(folderIds).forEach(f -> folderNames.put(f.getId(), f.getName()));
        }

        List<ActivityLogDTO> dtos = logs.stream().map(log -> {
            String userName = userNames.getOrDefault(log.getUserId(), "User " + log.getUserId());

            String targetName;
            if ("DOCUMENT".equals(log.getTargetType())) {
                targetName = documentTitles.get(log.getTargetId());
            } else if ("FOLDER".equals(log.getTargetType())) {
                targetName = folderNames.get(log.getTargetId());
            } else {
                targetName = null;
            }
            if (targetName == null) {
                // Target was hard-deleted since this log entry was created.
                targetName = (log.getTargetType() != null ? log.getTargetType() : "item") + " #" + log.getTargetId();
            }

            return new ActivityLogDTO(
                    log.getId(),
                    log.getUserId(),
                    userName,
                    log.getAction(),
                    log.getTargetId(),
                    log.getTargetType(),
                    targetName,
                    log.getCreatedAt()
            );
        }).toList();
        return ResponseEntity.ok(dtos);
    }

    @lombok.Data
    @lombok.AllArgsConstructor
    public static class ActivityLogDTO {
        private Long id;
        private Long userId;
        private String userName;
        private String action;
        private Long targetId;
        private String targetType;
        private String targetName;
        private java.time.LocalDateTime createdAt;
    }
}
