[CmdletBinding()]
param([switch]$NoVersionBump)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$moduleDir = $scriptDir
$zipPath = Join-Path (Split-Path -Parent $scriptDir) "OneOne.zip"
$propPath = Join-Path $moduleDir "module.prop"

# 1. Tu dong tang version trong module.prop
$propLines = Get-Content $propPath
$currentVerCode = 1
$foundCode = $false
foreach ($line in $propLines) {
    if ($line -match "^versionCode=(\d+)") {
        $currentVerCode = [int]$matches[1]
        if (-not $NoVersionBump) { $currentVerCode++ }
        $foundCode = $true
    }
}
if (-not $foundCode) { $currentVerCode = 2 }
$newVerStr = "v1.$($currentVerCode - 1)"

$finalLines = @()
foreach ($line in $propLines) {
    if ($line -match "^version=") {
        $finalLines += "version=$newVerStr"
    } elseif ($line -match "^versionCode=") {
        $finalLines += "versionCode=$currentVerCode"
    } else {
        $finalLines += $line
    }
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($propPath, ($finalLines -join "`n") + "`n", $utf8NoBom)

# 2. Dong goi OneOne.zip voi Forward Slash /
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

$archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
$files = Get-ChildItem -Path $moduleDir -Recurse -File | Where-Object { $_.Name -notmatch "build_zip" }
foreach ($file in $files) {
    $rel = $file.FullName.Substring($moduleDir.Length + 1).Replace("\", "/")
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $rel)
}
$archive.Dispose()

Write-Host "=========================================="
Write-Host " DA DONG GOI MODULE THANH CONG!"
Write-Host " Phien ban moi: $newVerStr (versionCode=$currentVerCode)"
Write-Host " File zip: $zipPath"
Write-Host "=========================================="

# Metadata for the native Magisk/Kitsune online module updater.
# Publish the matching GitHub release before pushing this metadata to main.
$update = [ordered]@{
    version = $newVerStr
    versionCode = $currentVerCode
    zipUrl = "https://github.com/oneone404/modulelogin/releases/download/$newVerStr/OneOne.zip"
    changelog = 'https://raw.githubusercontent.com/oneone404/modulelogin/main/CHANGELOG.md'
}
$updatePath = Join-Path (Split-Path -Parent $scriptDir) 'update.json'
[System.IO.File]::WriteAllText($updatePath, ($update | ConvertTo-Json) + "`n", $utf8NoBom)
