param([string]$Version = "v4")

$root    = $PSScriptRoot
$zipPath = Join-Path $root "dist\YeOlde_-_MCM_Settings_$Version.zip"

if (Test-Path $zipPath) { Remove-Item $zipPath }

Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open(
    $zipPath,
    [System.IO.Compression.ZipArchiveMode]::Create
)

function Add-Entry([string]$absPath, [string]$entryName) {
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $absPath, $entryName,
        [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
    Write-Host "  + $entryName"
}

$mod = Join-Path $root "YeOlde_-_MCM_Settings"
$pat = Join-Path $root "YeOlde_-_MCM_Settings_patches"

# ── fomod/ ────────────────────────────────────────────────────────────────────
Write-Host "`nfomod/"
Get-ChildItem "$pat\fomod\*" -File | ForEach-Object {
    Add-Entry $_.FullName "fomod/$($_.Name)"
}

# ── Core/ (always installed: esp, scripts, interface, source) ─────────────────
Write-Host "`nCore/"
Add-Entry "$mod\YeOlde - MCM Settings.esp" "Core/YeOlde - MCM Settings.esp"
Add-Entry "$mod\interface\yeolde\settings_splash.dds" "Core/interface/yeolde/settings_splash.dds"

Get-ChildItem "$mod\scripts\*.pex" | ForEach-Object {
    Add-Entry $_.FullName "Core/scripts/$($_.Name)"
}

Get-ChildItem "$mod\source\scripts\*.psc" | ForEach-Object {
    Add-Entry $_.FullName "Core/source/scripts/$($_.Name)"
}

foreach ($name in @("SKI_ConfigBase.psc", "yeolde_patches.psc")) {
    $f = "$mod\source\scripts\implementation\$name"
    if (Test-Path $f) { Add-Entry $f "Core/source/scripts/implementation/$name" }
}

# ── Patches/ (optional patch scripts) ────────────────────────────────────────
Write-Host "`nPatches/"
Get-ChildItem "$pat\scripts\*.pex" | ForEach-Object {
    Add-Entry $_.FullName "Patches/scripts/$($_.Name)"
}

Get-ChildItem "$pat\source\scripts\done\*.psc" | ForEach-Object {
    Add-Entry $_.FullName "Patches/source/scripts/done/$($_.Name)"
}

Get-ChildItem "$pat\source\scripts\need_patch\*.psc" | ForEach-Object {
    Add-Entry $_.FullName "Patches/source/scripts/need_patch/$($_.Name)"
}

$zip.Dispose()

$size = (Get-Item $zipPath).Length
Write-Host "`nCreated: $zipPath  ($size bytes)"
