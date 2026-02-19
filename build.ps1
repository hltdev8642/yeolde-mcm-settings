param(
    [string]$OutDir = "dist"
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $root $OutDir

if (Test-Path $out) {
    Write-Host "Removing existing output folder: $out"
    Remove-Item -Recurse -Force $out
}

New-Item -ItemType Directory -Path $out | Out-Null

Write-Host "Packaging distribution into: $out"

# Copy ESP
$espPath = Join-Path $root "YeOlde_-_MCM_Settings\YeOlde - MCM Settings.esp"
if (Test-Path $espPath) {
    Copy-Item -Path $espPath -Destination $out -Force
    Write-Host "Copied ESP: $espPath"
} else {
    Write-Host "ESP not found at: $espPath (skipping)"
}

# Prepare scripts output folder
$outScripts = Join-Path $out 'scripts'
New-Item -ItemType Directory -Path $outScripts | Out-Null

# Copy compiled .pex from main module
$srcScripts1 = Join-Path $root 'YeOlde_-_MCM_Settings\scripts'
if (Test-Path $srcScripts1) {
    Get-ChildItem -Path $srcScripts1 -Filter '*.pex' -File -Recurse | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $outScripts -Force
    }
    Write-Host "Copied .pex from YeOlde_-_MCM_Settings/scripts"
}

# Copy compiled .pex from patches module
$srcScripts2 = Join-Path $root 'YeOlde_-_MCM_Settings_patches\scripts'
if (Test-Path $srcScripts2) {
    Get-ChildItem -Path $srcScripts2 -Filter '*.pex' -File -Recurse | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $outScripts -Force
    }
    Write-Host "Copied .pex from YeOlde_-_MCM_Settings_patches/scripts"
}

# Copy interface assets if present
$interface = Join-Path $root 'YeOlde_-_MCM_Settings\interface'
if (Test-Path $interface) {
    Copy-Item -Path $interface -Destination (Join-Path $out 'interface') -Recurse -Force
    Write-Host "Copied interface assets"
}

# Copy fomod (patches) if present
$fomod = Join-Path $root 'YeOlde_-_MCM_Settings_patches\fomod'
if (Test-Path $fomod) {
    Copy-Item -Path $fomod -Destination (Join-Path $out 'fomod') -Recurse -Force
    Write-Host "Copied fomod"
}

Write-Host "Packaging complete. Distribution folder: $out"
Write-Host "Note: This script packages existing compiled .pex files. To generate .pex from .psc you must run the Papyrus compiler (Creation Kit / PapyrusCompiler). See BUILD.md."
