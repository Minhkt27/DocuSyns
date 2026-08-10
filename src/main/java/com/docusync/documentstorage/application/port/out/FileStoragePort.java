package com.docusync.documentstorage.application.port.out;

import java.io.InputStream;

public interface FileStoragePort {
    String uploadFile(String fileName, InputStream content, String mimeType);
    InputStream downloadFile(String storageFileId);
    void deleteFile(String storageFileId);
}
