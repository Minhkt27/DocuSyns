$body = @{
    maxVersionsPerFile = 10
    trashRetentionDays = 60
} | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer mock-jwt-token-admin"
    "Content-Type" = "application/json"
}

Invoke-RestMethod -Uri "http://localhost:8080/api/v1/settings" -Method Put -Headers $headers -Body $body
