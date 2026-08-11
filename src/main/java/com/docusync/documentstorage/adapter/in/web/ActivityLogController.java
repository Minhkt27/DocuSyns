package com.docusync.documentstorage.adapter.in.web;

import com.docusync.documentstorage.adapter.out.persistence.entity.ActivityLogEntity;
import com.docusync.documentstorage.application.service.ActivityLogService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/activities")
@RequiredArgsConstructor
public class ActivityLogController {

    private final ActivityLogService activityLogService;
    private final com.docusync.auth.repository.UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<ActivityLogDTO>> getRecentActivities() {
        List<ActivityLogEntity> logs = activityLogService.getRecentActivities();
        List<ActivityLogDTO> dtos = logs.stream().map(log -> {
            String userName = userRepository.findById(log.getUserId())
                    .map(u -> u.getFullName())
                    .orElse("User " + log.getUserId());
            return new ActivityLogDTO(
                    log.getId(),
                    log.getUserId(),
                    userName,
                    log.getAction(),
                    log.getTargetId(),
                    log.getTargetType(),
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
        private java.time.LocalDateTime createdAt;
    }
}
