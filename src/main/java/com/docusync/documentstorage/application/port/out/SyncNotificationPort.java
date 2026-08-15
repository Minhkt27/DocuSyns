package com.docusync.documentstorage.application.port.out;

/**
 * Notifies connected sidecars that a document's content changed, so they can
 * pull down a fresh copy if it's one they have synced locally.
 */
public interface SyncNotificationPort {
    /**
     * @param folderId the document's folder, or null if it's at the root.
     *                 Sidecars use it to recognize brand-new documents
     *                 created inside a folder they sync, even though they
     *                 don't yet have that documentId in their own manifest.
     */
    void notifyDocumentChanged(Long documentId, Long versionId, Long folderId);
}
