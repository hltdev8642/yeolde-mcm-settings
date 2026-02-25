param(
    [string]$CompilerPath = "H:\\_STEAM\\The Elder Scrolls - Skyrim - Special Edition\\Papyrus Compiler",
    [switch]$Force
)

# Delegate to do_compile.bat which has the correct -flags and -import paths
$batPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'do_compile.bat'
if (Test-Path $batPath) {
    Write-Host "Delegating to do_compile.bat (has correct -f/-i flags)..."
    cmd /c "`"$batPath`""
    exit $LASTEXITCODE
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-Compiler {
    param($path)
    if (-not $path) { return $null }
    if (Test-Path $path -PathType Leaf) { return (Get-Item $path).FullName }
    # If a directory was provided, look for executable inside
    if (Test-Path $path -PathType Container) {
        $candidates = Get-ChildItem -Path $path -Filter 'PapyrusCompiler*.exe' -File -ErrorAction SilentlyContinue
        if ($candidates) { return $candidates[0].FullName }
        $default = Join-Path $path 'PapyrusCompiler.exe'
        if (Test-Path $default) { return (Get-Item $default).FullName }
    }
    return $null
}

$compiler = Resolve-Compiler -path $CompilerPath
if (-not $compiler) {
    Write-Error "Papyrus compiler not found at path: $CompilerPath"
    exit 2
}

Write-Host "Using Papyrus compiler: $compiler"

# Source -> target map
$projects = @(
    @{ src = Join-Path $root 'YeOlde_-_MCM_Settings\source\scripts'; out = Join-Path $root 'YeOlde_-_MCM_Settings\scripts' },
    @{ src = Join-Path $root 'YeOlde_-_MCM_Settings_patches\source\scripts'; out = Join-Path $root 'YeOlde_-_MCM_Settings_patches\scripts' }
)

$triedAny = $false

foreach ($p in $projects) {
    if (-not (Test-Path $p.src)) { continue }
    $pscs = Get-ChildItem -Path $p.src -Recurse -Filter '*.psc' -File -ErrorAction SilentlyContinue
    if (-not $pscs -or $pscs.Count -eq 0) { Write-Host "No .psc files found in $($p.src) - skipping"; continue }

    New-Item -ItemType Directory -Path $p.out -Force | Out-Null

    Write-Host "Compiling $($pscs.Count) .psc files from $($p.src) -> $($p.out)"

    # Create a temporary file list (some compiler modes accept a file list)
    $fileList = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName() + '.txt')
    $pscs.FullName | Out-File -FilePath $fileList -Encoding ASCII

    # Candidate argument patterns (format: {compiler} {args})
    $patterns = @(
        '"{0}" "{1}" "{2}"',                    # positional: compiler source out
        '"{0}" -s "{1}" -o "{2}"',              # -s source -o out
        '"{0}" -i "{1}" -o "{2}"',              # -i include -o out
        '"{0}" -source "{1}" -output "{2}"',    # -source -output
        '"{0}" -include "{1}" -out "{2}"',      # -include -out
        '"{0}" -i "{1};" -o "{2}" -f "{3}"'   # with filelist
    )

    $compiled = $false
    foreach ($pat in $patterns) {
        $triedAny = $true
        $cmd = ''
        if ($pat -like '*{3}*') {
            $cmd = [String]::Format($pat, $compiler, $p.src, $p.out, $fileList)
        } else {
            $cmd = [String]::Format($pat, $compiler, $p.src, $p.out)
        }

        Write-Host "Trying: $cmd"
        try {
            # Invoke and capture output
            $output = & cmd /c $cmd 2>&1
            $exit = $LASTEXITCODE
        } catch {
            $output = $_.Exception.Message
            $exit = 1
        }

        if ($exit -eq 0) {
            Write-Host "Compile succeeded using pattern: $pat"
            $compiled = $true
            break
        } else {
            Write-Host "Pattern failed (exit=$exit). Output:"
            $output | ForEach-Object { Write-Host "  $_" }
        }
    }

    Remove-Item -Force $fileList -ErrorAction SilentlyContinue

    if (-not $compiled) {
        Write-Warning "Compilation failed for project at $($p.src). Review output above and run the compiler manually if needed."
    } else {
        # Copy resulting .pex into the out folder if compiler placed files elsewhere
        $found = Get-ChildItem -Path $p.out -Filter '*.pex' -File -Recurse -ErrorAction SilentlyContinue
        if ($found) { Write-Host "Found compiled .pex files in $($p.out): $($found.Count)" }
        else { Write-Warning "No .pex files found in $($p.out) after successful run - compiler may output elsewhere." }
    }
}

if (-not $triedAny) { Write-Warning "Nothing attempted; no projects had .psc files." }

Write-Host "Done. If compilation succeeded, run .\build.ps1 to package outputs."
