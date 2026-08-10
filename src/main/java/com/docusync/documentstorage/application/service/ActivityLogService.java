package com.docusync.documentstorage.application.service;

import com.docusync.documentstorage.adapter.out.persistence.entity.ActivityLogEntity;
import com.docusync.documentstorage.adapter.out.persistence.repository.ActivityLogRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class ActivityLogService {

    private final ActivityLogRepository repository;

    public void logActivity(Long userId, String action, Long targetId, String targetType) {
        ActivityLogEntity log = ActivityLogEntity.builder()
                .userId(userId)
                .action(action)
                .targetId(targetId)
                .targetType(targetType)
                .createdAt(LocalDateTime.now())
                .build();
        repository.save(log);
    }

    public List<ActivityLogEntity> getRecentActivities() {
        return repository.findTop50ByOrderByCreatedAtDesc();
    }
}
