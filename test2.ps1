$response = Invoke-WebRequest -Uri 'http://localhost:8080/api/v1/documents' -Method Get -Headers @{'Authorization'='Bearer mock-jwt-token-admin'}
Write-Output $response.Content
