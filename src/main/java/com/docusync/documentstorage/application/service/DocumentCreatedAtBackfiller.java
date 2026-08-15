package com.docusync.documentstorage.application.service;

import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentEntity;
import com.docusync.documentstorage.adapter.out.persistence.entity.DocumentVersionEntity;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentRepository;
import com.docusync.documentstorage.adapter.out.persistence.repository.DocumentVersionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

/**
 * One-time (per-startup, idempotent) backfill for documents created before
 * the createdAt column existed. Uses the earliest version's uploadedAt as a
 * stand-in for the document's real creation time; falls back to "now" only
 * if a document somehow has no versions at all.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DocumentCreatedAtBackfiller implements CommandLineRunner {

    private final DocumentRepository documentRepository;
    private final DocumentVersionRepository versionRepository;

    @Override
    public void run(String... args) {
        List<DocumentEntity> toBackfill = documentRepository.findAll().stream()
                .filter(d -> d.getCreatedAt() == null)
                .toList();

        if (toBackfill.isEmpty()) return;

        log.info("Backfilling createdAt for {} document(s)...", toBackfill.size());
        for (DocumentEntity doc : toBackfill) {
            DocumentVersionEntity firstVersion = versionRepository.findTopByDocumentIdOrderByVersionNumberAsc(doc.getId());
            doc.setCreatedAt(firstVersion != null ? firstVersion.getUploadedAt() : LocalDateTime.now());
            documentRepository.save(doc);
        }
    }
}
