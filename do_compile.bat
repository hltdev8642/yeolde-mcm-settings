@echo off
setlocal

set COMPILER=h:\_STEAM\The Elder Scrolls - Skyrim - Special Edition\Papyrus Compiler\PapyrusCompiler.exe
set FLAGS=h:\_STEAM\The Elder Scrolls - Skyrim - Special Edition\Data\Scripts\Source\TESV_Papyrus_Flags.flg
set VANILLA_SRC=h:\_STEAM\The Elder Scrolls - Skyrim - Special Edition\Data\Scripts\Source
set DEV_ROOT=h:\_STEAM\The Elder Scrolls - Skyrim - Special Edition\Dev\yeolde-mcm-settings

set MAIN_SRC=%DEV_ROOT%\YeOlde_-_MCM_Settings\source\scripts
set IMPL_SRC=%DEV_ROOT%\YeOlde_-_MCM_Settings\source\scripts\implementation
set MAIN_OUT=%DEV_ROOT%\YeOlde_-_MCM_Settings\scripts
set PATCH_SRC=%DEV_ROOT%\YeOlde_-_MCM_Settings_patches\source\scripts
set PATCH_OUT=%DEV_ROOT%\YeOlde_-_MCM_Settings_patches\scripts

set IMPORTS=%MAIN_SRC%;%IMPL_SRC%;%VANILLA_SRC%

echo ============================================================
echo Compiling main mod scripts...
echo ============================================================

for %%f in ("%MAIN_SRC%\*.psc") do (
    echo   Compiling: %%~nxf
    "%COMPILER%" "%%f" -f="%FLAGS%" -i="%IMPORTS%" -o="%MAIN_OUT%"
    if errorlevel 1 echo   ERROR on %%~nxf
)

echo.
echo ============================================================
echo Compiling patch scripts...
echo ============================================================

set PATCH_IMPORTS=%PATCH_SRC%;%MAIN_SRC%;%IMPL_SRC%;%VANILLA_SRC%

for %%f in ("%PATCH_SRC%\*.psc") do (
    echo   Compiling: %%~nxf
    "%COMPILER%" "%%f" -f="%FLAGS%" -i="%PATCH_IMPORTS%" -o="%PATCH_OUT%"
    if errorlevel 1 echo   ERROR on %%~nxf
)

echo.
echo ============================================================
echo Done. Checking output timestamps:
echo ============================================================
dir /TC "%MAIN_OUT%\yeolde_mcm_settings.pex"
dir /TC "%MAIN_OUT%\BackupConfig.pex"
dir /TC "%MAIN_OUT%\ski_configmanager.pex"

endlocal
