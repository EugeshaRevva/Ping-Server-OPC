# =============================================================================
#  Ping check servers OPS
#  Reads the server list from Config.json and checks every server in it.
#  Windows PowerShell 5.1 compatible.
# =============================================================================

$configurationFileName = 'Config.json'

$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = (Get-Location).ProviderPath
}

$serversConfigPath = Join-Path -Path $scriptDirectory -ChildPath $configurationFileName
$logFilePath       = Join-Path -Path $scriptDirectory -ChildPath 'ping_log.txt'
$converterPath     = Join-Path -Path $scriptDirectory -ChildPath 'JSON_Conventer.ps1'

# UTF-8 without BOM keeps non-English server names readable in the log file.
$utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false


function Format-Cell {
    param(
        [string]$Text,
        [int]$Width
    )

    if ($null -eq $Text) { $Text = '' }
    if ($Text.Length -ge $Width) { return $Text }
    return $Text.PadRight($Width)
}


function Get-ConfigField {
    param(
        $InputObject,
        [string]$Name,
        [string]$Default = ''
    )

    if ($null -eq $InputObject) { return $Default }

    $value = $null

    if ($InputObject -is [System.Collections.IDictionary]) {
        $value = $InputObject[$Name]
    }
    else {
        $property = $InputObject.PSObject.Properties[$Name]
        if ($null -ne $property) { $value = $property.Value }
    }

    if ($null -eq $value) { return $Default }

    $text = [string]$value
    if ([string]::IsNullOrWhiteSpace($text)) { return $Default }

    return $text
}


function Read-ServerConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # -Encoding UTF8 also strips a UTF-8 BOM, so files written by the old
    # generator (Out-File -Encoding utf8) are still read correctly.
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    # Do not wrap ConvertFrom-Json in @() directly: Windows PowerShell returns
    # a top-level JSON array as a single object and @() would make it a
    # one-element array. Collect the entries with foreach instead - it always
    # enumerates an array, however the cmdlet handed it back.
    $parsed = $raw | ConvertFrom-Json

    if ($null -eq $parsed) {
        return @()
    }

    $items = @()
    if ($parsed -is [System.Array]) {
        foreach ($entry in $parsed) {
            $items += $entry
        }
    }
    else {
        $items += $parsed
    }

    # A doubly wrapped list ([[{...},{...}]]) would otherwise look like one
    # broken entry - unwrap it.
    if ($items.Count -eq 1 -and $items[0] -is [System.Array]) {
        $nested = @()
        foreach ($entry in $items[0]) {
            $nested += $entry
        }
        $items = $nested
    }

    $servers = @()
    $index   = 0

    foreach ($item in $items) {
        $index++

        $ip = Get-ConfigField -InputObject $item -Name 'IP'
        if ([string]::IsNullOrWhiteSpace($ip)) {
            Write-Warning "Entry #${index} in '$configurationFileName' has no IP address and was skipped."
            continue
        }

        $servers += [pscustomobject][ordered]@{
            IP   = $ip
            Name = (Get-ConfigField -InputObject $item -Name 'Name' -Default $ip)
            SID  = (Get-ConfigField -InputObject $item -Name 'SID' -Default 'N/A')
        }
    }

    return $servers
}


function Config_Initialization {
    if (Test-Path -LiteralPath $serversConfigPath) {
        try {
            $servers = @(Read-ServerConfig -Path $serversConfigPath)
            if ($servers.Count -gt 0) {
                Write-Host "Configuration file has loaded! ($($servers.Count) servers)" -ForegroundColor DarkGreen
                return $servers
            }
            Write-Warning "Configuration file '$configurationFileName' does not contain any usable servers."
        }
        catch {
            Write-Warning "Configuration file '$configurationFileName' is corrupted or has an invalid JSON format: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "Configuration file '$configurationFileName' not found"
    }

    $choice = Read-Host 'Generate new default configuration file? [Y/N]'
    if ($choice -notmatch '^[Yy]') {
        Write-Error 'No configuration'
        exit
    }

    if (-not (Test-Path -LiteralPath $converterPath)) {
        throw "JSON generator not found: '$converterPath'"
    }

    Write-Host 'Running JSON Converter to restore config...' -ForegroundColor DarkCyan

    # '&' runs the generator in its own scope, so nothing it prints to the
    # pipeline can leak into this function's return value. Dot-sourcing it used
    # to add the raw JSON string to the server list and crash the ping loop.
    $null = & $converterPath

    $servers = @()
    if (Test-Path -LiteralPath $serversConfigPath) {
        try {
            $servers = @(Read-ServerConfig -Path $serversConfigPath)
        }
        catch {
            Write-Warning "Configuration file '$configurationFileName' is still unreadable: $($_.Exception.Message)"
        }
    }

    if ($servers.Count -eq 0) {
        throw "Configuration file '$configurationFileName' could not be generated."
    }

    Write-Host "Configuration file has been generated! ($($servers.Count) servers)" -ForegroundColor DarkGreen
    return $servers
}


function Main {
    $servers = @(Config_Initialization)
    if ($servers.Count -eq 0) {
        throw 'Server list is empty - nothing to ping.'
    }

    do {
        Write-Host ''
        Write-Host "`t=== Ping check servers OPS ===" -ForegroundColor Yellow

        foreach ($server in $servers) {
            $ping = Test-Connection -ComputerName $server.IP -Count 1 -Quiet -ErrorAction SilentlyContinue

            $now       = Get-Date
            $timeStamp = $now.ToString('HH:mm:ss')

            if ($ping) {
                $statusText = 'available'
                $color      = 'Green'
            }
            else {
                $statusText = 'unavailable'
                $color      = 'Red'
            }

            $displayIp = Format-Cell -Text $server.IP -Width 15

            Write-Host ("[{0}]`t{1}`tServer {2}`t|`t[SID: {3}]`t{4}" -f $timeStamp, $displayIp, $server.Name, $server.SID, $statusText) -ForegroundColor $color

            $logTime = $now.ToString('yyyy-MM-dd HH:mm:ss')
            $logIp   = Format-Cell -Text $server.IP -Width 15
            $logName = Format-Cell -Text $server.Name -Width 25
            $logSid  = Format-Cell -Text $server.SID -Width 10

            $logLine = "[$logTime] IP: $logIp | Server: $logName | SID: $logSid | Status: $statusText"

            try {
                [System.IO.File]::AppendAllText($logFilePath, $logLine + [Environment]::NewLine, $utf8NoBom)
            }
            catch {
                Write-Warning "Cannot write to the log file '$logFilePath': $($_.Exception.Message)"
            }
        }

        Write-Host "`nWaiting for Input `n[Enter] - New Ping `n[Spacebar] - Close Program" -ForegroundColor DarkBlue

        while ($true) {
            $keyInfo = [Console]::ReadKey($true)

            if ($keyInfo.Key -eq 'Spacebar') {
                Write-Host 'Close Program...'
                exit
            }

            if ($keyInfo.Key -eq 'Enter') {
                Clear-Host
                break
            }
        }
    } while ($true)
}


Main
