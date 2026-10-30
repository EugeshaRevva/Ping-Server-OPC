#task - Вывод лога в txt
$configurationFileName = "Config.json"
$serversConfigPath = Join-Path $PSScriptRoot $configurationFileName

function Config-Initialization {
    try {
        Write-Host "Configuration File has loaded!" -ForegroundColor DarkGreen
        return Get-Content -Raw -Path $serversConfigPath | ConvertFrom-Json
    }
    catch {
        Write-Warning "Configuration file $($configurationFileName) is corrupted or has an valid .JSON format"
    }
    else {
        Write-Warning "Configuration file $($configurationFileName) not found"
    }
    if () {
        $generationProposal = Read-Host "Generate new default configuration file? [Y/N]"
    }

}

if (Test-Path $serversConfigPath) {
    $Servers = Get-Content -Raw -Path $serversConfigPath | ConvertFrom-Json
}
else {
    Write-Host "Warning!" -ForegroundColor DarkYellow
    Write-Error "Configuration file not found."
    Exit
}

do {
    Write-Host "`n"
    Write-Host "`t=== Ping check servers OPS ===" -ForegroundColor Yellow

    foreach ($ServerHost in $Servers) {
    $ping = Test-Connection -ComputerName $ServerHost.IP -Count 1 -Quiet -ErrorAction SilentlyContinue

    if ($ping) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')]`t $($ServerHost.IP) `t Server $($ServerHost.name)`t | `t[SID: $($ServerHost.SID)] `tavailable" -ForegroundColor Green
    }
    else {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')]`t $($ServerHost.IP) `t Server $($ServerHost.name)`t | `t[SID: $($ServerHost.SID)] `tunavailable" -ForegroundColor Red
    }
}

Write-Host "`nWaiting for Input `n[Enter] - New Ping `n[Spacebar] - Close Program" -ForegroundColor DarkBlue

while ($true) {
    $keyInfo = [Console]::ReadKey($true)   
   
    if ($keyInfo.Key -eq "Spacebar") {
        Write-Host "Close Program..."
        exit
    }

    if ($keyInfo.Key -eq "Enter") {
        Clear-Host
        break
    }
}
} while ($true)