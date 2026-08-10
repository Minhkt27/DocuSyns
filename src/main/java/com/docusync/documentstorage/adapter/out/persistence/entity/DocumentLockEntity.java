package com.docusync.documentstorage.adapter.out.persistence.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "document_locks")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DocumentLockEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "document_id", nullable = false)
    private Long documentId;

    @Column(name = "locked_by", nullable = false)
    private Long lockedBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private LockStatus status;

    public enum LockStatus {
        LOCKED, RELEASED
    }
}
