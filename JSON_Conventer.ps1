<#
.SYNOPSIS
    Generates Config.json - the server list used by ping_servers.ps1.

.DESCRIPTION
    Writes a UTF-8 (no BOM) JSON array, validates every entry first, keeps a
    backup of the previous file and checks that the generated text parses back
    through ConvertFrom-Json.

    The script writes only to the host, never to the output stream, so it can
    be called with '&' (or dot-sourced) from another script without polluting
    the caller's pipeline.

.PARAMETER Path
    Target file. Defaults to Config.json next to this script.

.EXAMPLE
    .\JSON_Conventer.ps1

.EXAMPLE
    .\JSON_Conventer.ps1 -Path C:\Temp\Config.test.json
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

# --- Target path -------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Path)) {
    $scriptDirectory = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
        $scriptDirectory = (Get-Location).ProviderPath
    }
    $Path = Join-Path -Path $scriptDirectory -ChildPath 'Config.json'
}
$Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

# --- Server list -------------------------------------------------------------
# [ordered] keeps the field order IP -> Name -> SID in the generated file.
# Add, remove or edit servers here, then run this script again.
$ServerList = @(
    [ordered]@{ IP = '172.16.2.1';  Name = 'DataBase OLTP';                       SID = 'OPS2PRI2' },
    [ordered]@{ IP = '172.16.2.6';  Name = 'Kerio VPN, Web-servers';              SID = 'N/A' },
    [ordered]@{ IP = '172.16.2.3';  Name = 'Web-server AutomaticWorkplace, JIRA'; SID = 'N/A' },
    [ordered]@{ IP = '172.16.2.5';  Name = 'Standby Database OLTP';               SID = 'OPS2SB3' },
    [ordered]@{ IP = '172.16.2.7';  Name = 'DataBase Warehouse';                  SID = 'OPSWH2' },
    [ordered]@{ IP = '172.16.2.13'; Name = 'DataBase Warehouse';                  SID = 'OPSWH2' },
    [ordered]@{ IP = '172.16.2.15'; Name = 'Standby Database OLTP';               SID = 'OPS2SB3' },
    [ordered]@{ IP = '172.16.2.25'; Name = 'Test Stand';                          SID = 'N/A' }
)

# --- Validation --------------------------------------------------------------
function Test-ServerList {
    param(
        [object[]]$Servers
    )

    if ($null -eq $Servers -or $Servers.Count -eq 0) {
        throw 'Server list is empty - nothing to write.'
    }

    $seenIps = @{}

    for ($i = 0; $i -lt $Servers.Count; $i++) {
        $entry  = $Servers[$i]
        $number = $i + 1

        foreach ($field in 'IP', 'Name', 'SID') {
            if ([string]::IsNullOrWhiteSpace([string]($entry[$field]))) {
                throw "Entry #${number}: '$field' is empty."
            }
        }

        $ip = [string]($entry['IP'])

        if ($ip -notmatch '^[A-Za-z0-9][A-Za-z0-9._:\-]*$') {
            throw "Entry #${number}: '$ip' is not a valid IP address or host name."
        }

        if ($seenIps.ContainsKey($ip)) {
            throw "Duplicate IP '$ip' in entries #$($seenIps[$ip]) and #${number}."
        }

        $seenIps[$ip] = $number
    }
}

# --- Serialize ---------------------------------------------------------------
Test-ServerList -Servers $ServerList

# The pipeline form is used on purpose: it reliably produces a JSON array in
# every Windows PowerShell version (unlike -InputObject, which may wrap the
# array into an extra nesting level).
$json = $ServerList | ConvertTo-Json -Depth 5

if ($ServerList.Count -eq 1) {
    # Keep the file an array even with a single server.
    $json = '[' + [Environment]::NewLine + $json + [Environment]::NewLine + ']'
}

# Windows PowerShell 5.1 escapes every non-ASCII character as \uXXXX. Turn
# those escapes back into real characters so non-English names stay readable.
$unescaped = New-Object -TypeName System.Text.StringBuilder
$position  = 0

foreach ($match in [regex]::Matches($json, '\\u([0-9a-fA-F]{4})')) {
    [void]$unescaped.Append($json.Substring($position, $match.Index - $position))

    $code = [Convert]::ToInt32($match.Groups[1].Value, 16)

    # Keep ASCII escapes and surrogate halves untouched.
    if ($code -lt 0x80 -or ($code -ge 0xD800 -and $code -le 0xDFFF)) {
        [void]$unescaped.Append($match.Value)
    }
    else {
        [void]$unescaped.Append([char]::ConvertFromUtf32($code))
    }

    $position = $match.Index + $match.Length
}

[void]$unescaped.Append($json.Substring($position))
$json = $unescaped.ToString()

# PowerShell 5.1 aligns values with two spaces after the colon - normalize it.
$json = $json -replace '":  ', '": '

# --- Verify before touching the file -----------------------------------------
try {
    # Same trap as in ping_servers.ps1: ConvertFrom-Json hands a JSON array
    # back as one object, so @(...) around the pipeline would report 1 entry.
    $parsed = $json | ConvertFrom-Json
}
catch {
    throw "Generated JSON is invalid and was not written: $($_.Exception.Message)"
}

if ($null -eq $parsed) {
    throw 'Generated JSON is empty - file was not written.'
}

# Collect entries with foreach: @($pipeline) would report 1 entry because
# ConvertFrom-Json hands the whole JSON array back as a single object.
$roundTrip = @()
if ($parsed -is [System.Array]) {
    foreach ($entry in $parsed) {
        $roundTrip += $entry
    }
}
else {
    $roundTrip += $parsed
}

if ($roundTrip.Count -ne $ServerList.Count) {
    throw "Generated JSON has $($roundTrip.Count) entries, expected $($ServerList.Count) - file was not written."
}

# --- Write -------------------------------------------------------------------
$directory = Split-Path -Path $Path -Parent
if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

if (Test-Path -LiteralPath $Path) {
    $backupPath = "$Path.bak"
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    Write-Host "Previous configuration backed up to '$backupPath'" -ForegroundColor DarkGray
}

$temporaryPath = "$Path.tmp"
$utf8NoBom     = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false

try {
    # Write to a temporary file first, then swap it in, so a failure can never
    # leave a half-written Config.json behind.
    [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8NoBom)
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
}
catch {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
    throw "Cannot write '$Path': $($_.Exception.Message)"
}

Write-Host "Configuration generated: $($ServerList.Count) servers -> '$Path'" -ForegroundColor Green
