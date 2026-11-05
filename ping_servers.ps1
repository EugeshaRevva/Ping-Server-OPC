#task - Вывод лога в txt
$configurationFileName = "Config.json"
$serversConfigPath = Join-Path $PSScriptRoot $configurationFileName
$LogFilePath = Join-Path $PSScriptRoot "ping_log.txt"

function Config_Initialization {
    if (Test-Path $serversConfigPath) {
        try {
            Write-Host "Configuration File has loaded!" -ForegroundColor DarkGreen
            return Get-Content -Raw -Path $serversConfigPath -ErrorAction Stop | ConvertFrom-Json
        } catch {
            Write-Warning "Configuration file '$configurationFileName' is corrupted or has an invalid .JSON format"
        }
    }
    else {
            Write-Warning "Configuration file '$configurationFileName' not found"
    }

    $Choice = Read-Host "Generate new default configuration file? [Y/N]"
        if ($Choice -notmatch "^[Yy]") {
            Write-Error "No configuration"
            Exit
        }
        Write-Host "Running JSON Converter to restore config..." -ForegroundColor DarkCyan
        . (Join-Path $PSScriptRoot "JSON_Conventer.ps1")

        if (Test-Path $serversConfigPath) {
            return Get-Content -Raw -Path $serversConfigPath | ConvertFrom-Json
        }
    }
    
function Main {
    $Servers = Config_Initialization
    
    do {
        Write-Host "`n"
        Write-Host "`t=== Ping check servers OPS ===" -ForegroundColor Yellow
    
        foreach ($ServerHost in $Servers) {
        $ping = Test-Connection -ComputerName $ServerHost.IP -Count 1 -Quiet -ErrorAction SilentlyContinue
        
        $timeStamp = Get-Date -Format 'HH:mm:ss'

        if ($ping) {
            $statusText = "available"
            Write-Host "[$timeStamp]`t $($ServerHost.IP) `t Server $($ServerHost.name)`t | `t[SID: $($ServerHost.SID)] `t$statusText" -ForegroundColor Green
        }
        else {
            $statusText = "unavailable"
            Write-Host "[$timeStamp]`t $($ServerHost.IP) `t Server $($ServerHost.name)`t | `t[SID: $($ServerHost.SID)] `t$statusText" -ForegroundColor Red
        }
        $LogLine = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] IP: $($ServerHost.IP.PadRight(15)) | Server: $($ServerHost.name.PadRight(25)) | SID: $($ServerHost.SID.PadRight(10)) | Status: $statusText"
        Add-Content -Path $logFilePath -Value $LogLine -ErrorAction SilentlyContinue

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
}

Main