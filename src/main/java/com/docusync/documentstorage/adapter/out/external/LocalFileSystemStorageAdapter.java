package com.docusync.documentstorage.adapter.out.external;

import com.docusync.documentstorage.application.port.out.FileStoragePort;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

@Component
@Primary
@Slf4j
public class LocalFileSystemStorageAdapter implements FileStoragePort {

    private static final String STORAGE_DIR = "/app/local_storage/";

    public LocalFileSystemStorageAdapter() {
        File dir = new File(STORAGE_DIR);
        if (!dir.exists()) {
            dir.mkdirs();
        }
    }

    @Override
    public String uploadFile(String fileName, InputStream content, String mimeType) {
        try {
            // Fix Path Traversal: Use only UUID for the physical filename on disk.
            String fileId = UUID.randomUUID().toString();
            Path filePath = Paths.get(STORAGE_DIR, fileId);
            Files.copy(content, filePath);
            log.info("File saved locally: {}", filePath);
            return fileId;
        } catch (Exception e) {
            throw new RuntimeException("Failed to save file locally", e);
        }
    }

    @Override
    public InputStream downloadFile(String storageFileId) {
        try {
            Path filePath = Paths.get(STORAGE_DIR, storageFileId);
            return new FileInputStream(filePath.toFile());
        } catch (Exception e) {
            throw new RuntimeException("Failed to read local file", e);
        }
    }

    @Override
    public void deleteFile(String storageFileId) {
        try {
            Path filePath = Paths.get(STORAGE_DIR, storageFileId);
            Files.deleteIfExists(filePath);
        } catch (Exception e) {
            throw new RuntimeException("Failed to delete local file", e);
        }
    }
}
