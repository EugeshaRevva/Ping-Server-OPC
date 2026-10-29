$servers = @(
    "172.16.2.1",
    "172.16.2.6",
    "172.16.2.3",
    "172.16.2.5",
    "172.16.2.7",
    "172.16.2.13",
    "172.16.2.15",
    "172.16.2.25"
)

Write-Host "=== Ping check servers OPS ===" -ForegroundColor Cyan
Write-Host ""

foreach ($server in $servers) {
    $ping = Test-Connection -ComputerName $server -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if ($ping) {
        Write-Host "$server - Server available" -ForegroundColor Green
    }
    else {
        Write-Host "$server - Server unavailable" -ForegroundColor Red
    }
}

Read-Host "Press enter..."
