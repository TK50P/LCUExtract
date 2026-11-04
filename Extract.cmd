@echo off
pushd "%~dp0"

:: Enforce Administrator privileges
reg query HKU\S-1-5-19>nul 2>nul||(powershell -c "start cmd -ArgumentList '/c call \"%~f0\"' -verb runas" &exit)

set "BASE_DIR=%~dp0"
set "BASE_DIR=%BASE_DIR:~0,-1%"
set "LCU_DIR=%BASE_DIR%"
set "OUT_DIR=%BASE_DIR%\LCUEXT"
set "RPK_DIR=%BASE_DIR%\LCURPK"
set "SEVENZIP=%BASE_DIR%\Files\7z.exe"
set "EXPAND_EXE=%BASE_DIR%\Files\expand.exe"
set "WIMLIB=%BASE_DIR%\Files\wimlib-imagex.exe"
set "PSFEXTRACTOR=%BASE_DIR%\Files\PSFExtractor-x64.exe"
set "_Null=1>nul 2>nul"

Title Windows Update Extractor and Repacker

echo ===========================================================
echo  Environment Directories:
echo  - Base: %BASE_DIR%
echo  - Unpack Directory: %OUT_DIR%
echo  - Repack Directory: %RPK_DIR%
===========================================================
echo.

:: Local Dependency Assertions
if not exist "%SEVENZIP%" echo [Error] Missing %SEVENZIP% && dram-stop && pause && exit /b
if not exist "%WIMLIB%" echo [Error] Missing %WIMLIB% && safe-pause && pause && exit /b
if not exist "%PSFEXTRACTOR%" echo [Error] Missing %PSFEXTRACTOR% && pause && exit /b

:: Safety check layer to verify the MSU archive exists before creating workspace folders
if not exist "%LCU_DIR%\Windows1*.0-KB*.msu" (
    echo [Error] No matching updates found.
    echo Please make sure your Windows1*.0-KB*.msu file is placed 
    echo right next to this script in: %BASE_DIR%
    echo.
    pause
    exit /b
)

if exist "%OUT_DIR%" (rmdir /q /s "%OUT_DIR%") 2>nul
md "%OUT_DIR%"
if not exist "%RPK_DIR%" md "%RPK_DIR%"

setlocal EnableDelayedExpansion

echo [1/3] Splitting core archives from MSU package...
for %%i in ("%LCU_DIR%\Windows1*.0-KB*.msu") do (
    "%SEVENZIP%" e -aoa "%%i" ssu*.* windows1*.* *.AggregatedMetadata*.* DesktopDeployment.* -o"%LCU_DIR%" -y %_Null%
)

echo [2/3] Extracting update contents to LCUEXT...

:: Process Servicing Stack Updates (SSU) straight to LCUEXT folder
if /i exist "%LCU_DIR%\ssu*.cab" (
    for %%s in ("%LCU_DIR%\ssu*.cab") do (
        set "SSUName=%%~ns"
        mkdir "%OUT_DIR%\!SSUName!"
        "%EXPAND_EXE%" "%%s" -f:* "%OUT_DIR%\!SSUName!" %_Null%
    )
)

:: Extract WIM Payloads (Windows 11 Standard Deployment Architecture)
if /i exist "%LCU_DIR%\Windows1*.0-KB*.wim" (
    for %%k in ("%LCU_DIR%\Windows1*.0-KB*.wim") do (
        set "WimName=%%~nk"
        mkdir "%OUT_DIR%\!WimName!"
        "%WIMLIB%" extract "%%k" 1 --dest-dir="%OUT_DIR%\!WimName!" %_Null%
        
        :: Process matching Patch Storage Files (.psf) if they exist locally
        if exist "%LCU_DIR%\!WimName!.psf" (
            "%PSFEXTRACTOR%" -v2 "%LCU_DIR%\!WimName!.psf" "%OUT_DIR%\!WimName!\express.psf.cix.xml" "%OUT_DIR%\!WimName!"
        )
    )
)

:: Extract Cumulative Update CAB Payloads
if /i exist "%LCU_DIR%\Windows1*.0-KB*.cab" (
    for %%b in ("%LCU_DIR%\Windows1*.0-KB*.cab") do (
        set "CabName=%%~nb"
        mkdir "%OUT_DIR%\!CabName!"
        "%EXPAND_EXE%" "%%b" -f:* "%OUT_DIR%\!CabName!" %_Null%
        
        if exist "%LCU_DIR%\!CabName!.psf" (
            "%PSFEXTRACTOR%" -v2 "%LCU_DIR%\!CabName!.psf" "%OUT_DIR%\!CabName!\express.psf.cix.xml" "%OUT_DIR%\!CabName!"
        )
        
        :: Handle Nested Archive Extractions
        if /i exist "%OUT_DIR%\!CabName!\!CabName!.cab" (
            "%EXPAND_EXE%" "%OUT_DIR%\!CabName!\!CabName!.cab" -f:* "%OUT_DIR%\!CabName!" %_Null%
            del /f /q "%OUT_DIR%\!CabName!\!CabName!.cab" %_Null%
        )
        if /i exist "%OUT_DIR%\!CabName!\Cab*.cab" (
            "%EXPAND_EXE%" "%OUT_DIR%\!CabName!\Cab*.cab" -f:* "%OUT_DIR%\!CabName!" %_Null%
            del /f /q "%OUT_DIR%\!CabName!\Cab*.cab" %_Null%
        )
    )
)

:: Cleanup extraction debris from the root directory
del /f /q "%LCU_DIR%\ssu*.cab" %_Null%
del /f /q "%LCU_DIR%\Windows1*.0-KB*.cab" %_Null%
del /f /q "%LCU_DIR%\Windows1*.0-KB*.wim" %_Null%
del /f /q "%LCU_DIR%\*.psf" %_Null%
del /f /q "%LCU_DIR%\*.AggregatedMetadata*" %_Null%
del /f /q "%LCU_DIR%\DesktopDeployment.*" %_Null%

echo [3/3] Extraction completed.
echo.

:ask_recompress
set /p "choice=Do you want to recompress your extracted payload directories into ESD packages inside LCURPK? (Y/N): "
if /i "%choice%"=="Y" (
    echo.
    echo Recompressing payload structures to Solid ESD packages using LZX...
    for /f "tokens=* delims=" %%a in ('dir /b /a:d "%OUT_DIR%"') do (
        echo Capturing target payload folder: %%a
        "%WIMLIB%" capture "%OUT_DIR%\%%a" "%RPK_DIR%\%%a.esd" "%%a" --check --compress=LZX:100
    )
    echo.
    echo All target structures successfully compiled inside the LCURPK directory.
    echo Cleaning up temporary extraction folder...
    if exist "%OUT_DIR%" rmdir /q /s "%OUT_DIR%" %_Null%
    echo.
    echo ==============================================================================
    echo  Task finished successfully.
    echo  To update your system using the compressed package, use:
    echo  Dism.exe /Online /add-package /packagepath:"%RPK_DIR%\[PackageName].esd"
    echo ==============================================================================
    goto :end_script
)
if /i "%choice%"=="N" (
    echo.
    echo Keeping raw files uncompressed inside the LCUEXT directory.
    echo.
    echo ==============================================================================
    echo  Task finished successfully.
    echo  To update your system using the loose extracted manifest, use:
    echo  Dism.exe /Online /add-package /packagepath:"%OUT_DIR%\[FolderName]\update.mum"
    echo ==============================================================================
    goto :end_script
)
echo Invalid selection. Please specify either Y or N.
goto :ask_recompress

:end_script
endlocal
pause
exit /b
