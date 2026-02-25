param([string]$Version = "v4")

$root    = $PSScriptRoot
$distDir = Join-Path $root "dist"
$zipPath = Join-Path $distDir "YeOlde_-_MCM_Settings_$Version.zip"
$staging = Join-Path $root "_staging_zip"

# Clean up
if (Test-Path $zipPath)  { Remove-Item $zipPath -Force }
if (Test-Path $staging)  { Remove-Item $staging -Recurse -Force }

$mod = Join-Path $root "YeOlde_-_MCM_Settings"
$pat = Join-Path $root "YeOlde_-_MCM_Settings_patches"

function Stage([string]$src, [string]$rel) {
    $dest = Join-Path $staging $rel
    $dir  = Split-Path $dest -Parent
    if (!(Test-Path $dir)) { New-Item $dir -ItemType Directory -Force | Out-Null }
    Copy-Item $src $dest -Force
    Write-Host "  + $rel"
}

# ── fomod/ ────────────────────────────────────────────────────────────────────
Write-Host "`nfomod/"
Get-ChildItem "$pat\fomod\*" -File | ForEach-Object {
    Stage $_.FullName "fomod\$($_.Name)"
}

# ── Core/ ─────────────────────────────────────────────────────────────────────
Write-Host "`nCore/"
Stage "$mod\YeOlde - MCM Settings.esp" "Core\YeOlde - MCM Settings.esp"
Stage "$mod\interface\yeolde\settings_splash.dds" "Core\interface\yeolde\settings_splash.dds"

Get-ChildItem "$mod\scripts\*.pex" | ForEach-Object {
    Stage $_.FullName "Core\scripts\$($_.Name)"
}

Get-ChildItem "$mod\source\scripts\*.psc" | ForEach-Object {
    Stage $_.FullName "Core\source\scripts\$($_.Name)"
}

foreach ($name in @("SKI_ConfigBase.psc", "yeolde_patches.psc")) {
    $f = "$mod\source\scripts\implementation\$name"
    if (Test-Path $f) { Stage $f "Core\source\scripts\implementation\$name" }
}

# ── Patches/ ──────────────────────────────────────────────────────────────────
Write-Host "`nPatches/"
Get-ChildItem "$pat\scripts\*.pex" | ForEach-Object {
    Stage $_.FullName "Patches\scripts\$($_.Name)"
}

Get-ChildItem "$pat\source\scripts\done\*.psc" | ForEach-Object {
    Stage $_.FullName "Patches\source\scripts\done\$($_.Name)"
}

Get-ChildItem "$pat\source\scripts\need_patch\*.psc" | ForEach-Object {
    Stage $_.FullName "Patches\source\scripts\need_patch\$($_.Name)"
}

# ── Zip the staging tree ──────────────────────────────────────────────────────
if (!(Test-Path $distDir)) { New-Item $distDir -ItemType Directory -Force | Out-Null }
Compress-Archive -Path "$staging\*" -DestinationPath $zipPath -CompressionLevel Optimal

Remove-Item $staging -Recurse -Force

$size = (Get-Item $zipPath).Length
Write-Host "`nCreated: $zipPath  ($size bytes)"
