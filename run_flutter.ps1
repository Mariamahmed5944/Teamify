# Kill anything on port 8080 first, then run Flutter
$pid8080 = (netstat -ano | findstr ":8080 " | findstr "LISTENING" | ForEach-Object { ($_ -split '\s+')[-1] }) | Select-Object -First 1
if ($pid8080) {
    Write-Host "Killing PID $pid8080 on port 8080..."
    taskkill /PID $pid8080 /F
    Start-Sleep -Seconds 1
}
flutter run -d chrome --web-port=8080 --dart-define=API_BASE_URL=http://localhost:5022
