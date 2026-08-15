package com.docusync.documentstorage.adapter.out.persistence.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "documents")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DocumentEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "document_code", unique = true, nullable = false)
    private String documentCode;

    @Column(nullable = false)
    private String title;

    @Column(name = "current_version_id")
    private Long currentVersionId;

    @Column(name = "created_by", nullable = false)
    private Long createdBy;

    @Column(name = "folder_id")
    private Long folderId;

    @Column(name = "is_deleted", nullable = false, columnDefinition = "boolean default false")
    @Builder.Default
    private boolean isDeleted = false;

    @Column(name = "deleted_at")
    private java.time.LocalDateTime deletedAt;

    @Column(name = "created_at")
    private java.time.LocalDateTime createdAt;
}
