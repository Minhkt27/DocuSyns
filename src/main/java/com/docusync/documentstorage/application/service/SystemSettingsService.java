package com.docusync.documentstorage.application.service;

import com.docusync.documentstorage.adapter.out.persistence.entity.SystemSettingsEntity;
import com.docusync.documentstorage.adapter.out.persistence.repository.SystemSettingsRepository;
import com.docusync.documentstorage.application.domain.model.SystemSettings;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SystemSettingsService {

    private final SystemSettingsRepository repository;

    @Transactional(readOnly = true)
    public SystemSettings getSettings() {
        SystemSettingsEntity entity = repository.findAll().stream().findFirst().orElseGet(() -> {
            SystemSettingsEntity defaultEntity = new SystemSettingsEntity();
            return defaultEntity;
        });
        Long id = entity.getId() != null ? entity.getId() : 1L;
        return new SystemSettings(id, entity.getMaxVersionsPerFile(), entity.getTrashRetentionDays());
    }

    @Transactional
    public SystemSettings updateSettings(Integer maxVersionsPerFile, Integer trashRetentionDays) {
        SystemSettingsEntity entity = repository.findAll().stream().findFirst().orElse(new SystemSettingsEntity());
        entity.setMaxVersionsPerFile(maxVersionsPerFile);
        entity.setTrashRetentionDays(trashRetentionDays);
        entity = repository.save(entity);
        return new SystemSettings(entity.getId(), entity.getMaxVersionsPerFile(), entity.getTrashRetentionDays());
    }
}
