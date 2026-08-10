package com.docusync.documentstorage.adapter.out.persistence.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "system_settings")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SystemSettingsEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "max_versions_per_file", nullable = false)
    @Builder.Default
    private Integer maxVersionsPerFile = 5;

    @Column(name = "trash_retention_days", nullable = false)
    @Builder.Default
    private Integer trashRetentionDays = 30;
}
