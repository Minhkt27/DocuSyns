package com.docusync.documentstorage.adapter.out.external;

import com.docusync.documentstorage.application.port.out.FileStoragePort;
import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.http.InputStreamContent;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.JsonFactory;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.drive.Drive;
import com.google.api.services.drive.DriveScopes;
import com.google.api.services.drive.model.File;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.GoogleCredentials;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.util.Collections;

@Component
public class GoogleDriveStorageAdapter implements FileStoragePort {

    private static final String APPLICATION_NAME = "DocuSync Storage App";
    private static final JsonFactory JSON_FACTORY = GsonFactory.getDefaultInstance();
    private static final String FOLDER_ID = "1m7Kn3haTw-wr9GKFGz0nrHBS_cAy_Tx2";

    private Drive driveService;

    @PostConstruct
    public void init() {
        try {
            final NetHttpTransport HTTP_TRANSPORT = GoogleNetHttpTransport.newTrustedTransport();
            InputStream credentialsStream = getClass().getResourceAsStream("/google-credentials.json");
            
            if (credentialsStream == null) {
                System.err.println("google-credentials.json not found in resources!");
                return;
            }

            GoogleCredentials credentials = GoogleCredentials.fromStream(credentialsStream)
                    .createScoped(Collections.singletonList(DriveScopes.DRIVE_FILE));

            driveService = new Drive.Builder(HTTP_TRANSPORT, JSON_FACTORY, new HttpCredentialsAdapter(credentials))
                    .setApplicationName(APPLICATION_NAME)
                    .build();
            
            System.out.println("Google Drive API initialized successfully.");
        } catch (Exception e) {
            System.err.println("Error initializing Google Drive API: " + e.getMessage());
        }
    }

    @Override
    public String uploadFile(String fileName, InputStream content, String mimeType) {
        try {
            File fileMetadata = new File();
            fileMetadata.setName(fileName);
            fileMetadata.setParents(Collections.singletonList(FOLDER_ID));

            InputStreamContent mediaContent = new InputStreamContent(mimeType, content);

            File file = driveService.files().create(fileMetadata, mediaContent)
                    .setFields("id")
                    .execute();
            
            System.out.println("File uploaded to Google Drive. ID: " + file.getId());
            return file.getId();
        } catch (Exception e) {
            throw new RuntimeException("Failed to upload file to Google Drive", e);
        }
    }

    @Override
    public InputStream downloadFile(String storageFileId) {
        try {
            return driveService.files().get(storageFileId).executeMediaAsInputStream();
        } catch (Exception e) {
            throw new RuntimeException("Failed to download file from Google Drive", e);
        }
    }

    @Override
    public void deleteFile(String storageFileId) {
        try {
            driveService.files().delete(storageFileId).execute();
            System.out.println("File deleted from Google Drive. ID: " + storageFileId);
        } catch (Exception e) {
            throw new RuntimeException("Failed to delete file from Google Drive", e);
        }
    }
}
