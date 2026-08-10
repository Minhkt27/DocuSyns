package uploader

import (
	"bytes"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
)

func UploadFile(filename string) {
	// 1. Open file
	file, err := os.Open(filename)
	if err != nil {
		log.Println("Error opening file:", err)
		return
	}
	defer file.Close()

	// 2. Prepare multipart body
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("file", filepath.Base(filename))
	if err != nil {
		log.Println("Error creating form file:", err)
		return
	}
	io.Copy(part, file)
	writer.Close()

	// 3. Send HTTP request to Spring Boot (documentId=1 for demo)
	apiUrl := os.Getenv("API_URL")
	if apiUrl == "" {
		apiUrl = "http://localhost:8080"
	}
	req, err := http.NewRequest("POST", apiUrl+"/api/v1/documents/1/upload", body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req.Header.Set("Authorization", "Bearer mock-jwt-token-user-1")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Println("Error uploading file:", err)
		return
	}
	defer resp.Body.Close()

	log.Println("Upload API response status:", resp.Status)
}
