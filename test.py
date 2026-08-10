import urllib.request
import json

url = "http://localhost:8080/api/v1/settings"
data = json.dumps({
    "maxVersionsPerFile": 10,
    "trashRetentionDays": 60
}).encode("utf-8")

req = urllib.request.Request(url, data=data, method="PUT")
req.add_header("Content-Type", "application/json")
req.add_header("Authorization", "Bearer mock-jwt-token-admin")

try:
    response = urllib.request.urlopen(req)
    print("STATUS:", response.status)
    print("BODY:", response.read().decode("utf-8"))
except Exception as e:
    print("ERROR:", e)
    if hasattr(e, 'read'):
        print("ERROR BODY:", e.read().decode("utf-8"))
