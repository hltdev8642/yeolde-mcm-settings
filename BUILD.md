# Build / Package Instructions

This repository contains Papyrus source (`.psc`) and compiled scripts (`.pex`). The repository does not include an automated Papyrus compilation tool.

What `build.ps1` does
- Packages existing compiled artifacts and assets into a `dist/` folder.
- Copies the ESP, compiled `.pex` files from `YeOlde_-_MCM_Settings/scripts` and `YeOlde_-_MCM_Settings_patches/scripts`, `interface/`, and `fomod/` into `dist/`.

How to use
1. If you already have compiled `.pex` files (from the Creation Kit / Papyrus compiler), run:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

2. If you need to generate `.pex` from `.psc` sources:
- Install the Skyrim Special Edition Creation Kit or otherwise obtain the Papyrus compiler (`PapyrusCompiler.exe`).
- Use the Papyrus compiler to compile the `.psc` files in:
  - `YeOlde_-_MCM_Settings\source\scripts`
  - `YeOlde_-_MCM_Settings_patches\source\scripts`
- Place the resulting `.pex` files into the corresponding `scripts` folders (e.g. `YeOlde_-_MCM_Settings\scripts` and `YeOlde_-_MCM_Settings_patches\scripts`).

Notes and warnings
- Some source files (for example `yeolde_patches.psc` and `SKI_ConfigBase.psc`) include comments saying they should not be recompiled — leave those as-is.
- Papyrus compiler usage varies by Creation Kit version; follow the official Creation Kit or modding community documentation for the correct compiler invocation and include paths.

If you want, I can:
- Add a PowerShell wrapper that will attempt to call `PapyrusCompiler.exe` when you provide its install path.
- Create an automated packaging + zip step for `dist/`.

How to run the compiler wrapper

If you provided the Papyrus compiler path, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\compile-psc.ps1 -CompilerPath "H:\\_STEAM\\The Elder Scrolls - Skyrim - Special Edition\\Papyrus Compiler"
```

Notes:
- The wrapper will try several common command-line patterns for `PapyrusCompiler.exe`. If none succeed, run the compiler manually with the flags for your Creation Kit version.
- After successful compilation, run `build.ps1` to package the generated `.pex` files.
