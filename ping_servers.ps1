$servers = @(
    @{IP = "172.16.2.1"; Name = "DataBase OLTP"; SID = "OPS2PRI2"},
    @{IP = "172.16.2.6"; Name = "Kerio VPN, Web-servers"; SID = "N/A"},
    @{IP = "172.16.2.3"; Name = "Web-server AutomaticWorkplace, JIRA"; SID = "N/A"},
    @{IP = "172.16.2.5"; Name = "Standby Database OLTP"; SID = "OPS2SB3"},
    @{IP = "172.16.2.7"; Name = "DataBase Warehouse"; SID = "OPSWH2"},
    @{IP = "172.16.2.13"; Name = "DataBase Warehouse"; SID = "OPSWH2"},
    @{IP = "172.16.2.15"; Name = "Standby Database OLTP"; SID = "OPS2SB3"},
    @{IP = "172.16.2.25"; Name = "Test Stand"; SID = "N/A"}
)

Write-Host "`t=== Ping check servers OPS ===" -ForegroundColor Yellow
Write-Host ""

foreach ($server in $servers) {
    $ping = Test-Connection -ComputerName $server.IP -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($ping) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')]`t $($server.IP) `t Server $($server.name) [SID: $($server.SID)] available" -ForegroundColor Green
    }
    else {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')]`t $($server.IP) `t Server $($server.name) [SID: $($server.SID)] unavailable" -ForegroundColor Red
    }
}

Read-Host "Press enter..."
