package com.docusync.documentstorage.adapter.out.persistence.repository;

import com.docusync.documentstorage.adapter.out.persistence.entity.ActivityLogEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ActivityLogRepository extends JpaRepository<ActivityLogEntity, Long> {
    List<ActivityLogEntity> findTop50ByOrderByCreatedAtDesc();
}
