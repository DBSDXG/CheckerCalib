$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Build assets live in this folder; project dir is its parent.
$packDir = $PSScriptRoot
$projDir = Split-Path $packDir -Parent
Write-Output ('Project dir: ' + $projDir)

foreach ($need in @('LauncherStandalone.cs','icon.ico','name_standalone.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $packDir $need))) { throw ('missing build asset: ' + $need) }
}

# ---------- payload.zip: scripts + settings + presets + tools/ ----------
$payload = Join-Path $packDir 'payload.zip'
if (Test-Path -LiteralPath $payload) { Remove-Item -LiteralPath $payload -Force }
$fs = [System.IO.File]::Open($payload, [System.IO.FileMode]::Create)
$za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
function Add-FileToZip([System.IO.Compression.ZipArchive]$z, [string]$srcFile, [string]$entryName) {
    $entry = $z.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $es = $entry.Open()
    try {
        $src = [System.IO.File]::OpenRead($srcFile)
        try { $src.CopyTo($es) } finally { $src.Dispose() }
    } finally { $es.Dispose() }
}
try {
    Add-FileToZip $za (Join-Path $projDir 'checkerboard.scad') 'checkerboard.scad'
    Add-FileToZip $za (Join-Path $projDir 'generator.ps1') 'generator.ps1'
    Add-FileToZip $za (Join-Path $projDir 'bambu_project_settings.json') 'bambu_project_settings.json'
    if (Test-Path -LiteralPath (Join-Path $projDir 'checkerboard.json')) {
        Add-FileToZip $za (Join-Path $projDir 'checkerboard.json') 'checkerboard.json'
    }
    $toolsDir = Join-Path $projDir 'tools'
    $files = Get-ChildItem -LiteralPath $toolsDir -Recurse -File
    $count = 0
    foreach ($f in $files) {
        $rel = 'tools/' + $f.FullName.Substring($toolsDir.Length + 1).Replace('\', '/')
        Add-FileToZip $za $f.FullName $rel
        $count++
    }
    Write-Output ('Payload entries: ' + ($count + 2) + ' files')
} finally { $za.Dispose(); $fs.Dispose() }
Write-Output ('payload.zip: ' + [math]::Round((Get-Item $payload).Length / 1MB, 1) + ' MB')

# ---------- compile ----------
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path -LiteralPath $csc)) { throw 'csc.exe not found' }
$exeTmp = Join-Path $packDir 'standalone_build.exe'
& $csc /nologo /target:winexe /platform:anycpu /codepage:65001 ("/win32icon:" + (Join-Path $packDir 'icon.ico')) ("/resource:$payload,CheckerboardPayload.zip") ("/out:" + $exeTmp) /r:System.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll (Join-Path $packDir 'LauncherStandalone.cs')
if ($LASTEXITCODE -ne 0) { throw 'csc compile failed' }
Write-Output ('standalone build: ' + [math]::Round((Get-Item $exeTmp).Length / 1MB, 1) + ' MB')

# ---------- deploy ----------
$name = [IO.File]::ReadAllText((Join-Path $packDir 'name_standalone.txt'), (New-Object Text.UTF8Encoding($false))).Trim()
if ($name.Length -eq 0) { throw 'empty exe name' }
$dest = Join-Path $projDir $name
Copy-Item -LiteralPath $exeTmp $dest -Force
Remove-Item -LiteralPath $exeTmp -Force
Remove-Item -LiteralPath $payload -Force
$item = Get-Item -LiteralPath $dest
Write-Output ('Deployed: ' + $item.FullName)
Write-Output ('Size: ' + [math]::Round($item.Length / 1MB, 1) + ' MB')
Write-Output 'BUILD OK'
