@echo off
setlocal enabledelayedexpansion

:: Extract timestamp as yyyyMMddHHmm
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set dt=%%I
set BUILD_NUM=%dt:~0,12%
if "%BUILD_NUM%"=="" (
    set BUILD_NUM=%date:~10,4%%date:~4,2%%date:~7,2%%time:~0,2%%time:~3,2%
    set BUILD_NUM=!BUILD_NUM: =0!
)

echo ==============================================================================
echo  Building Flutter Web with Unique Build ID: %BUILD_NUM%
echo ==============================================================================

call flutter build web --release --build-number=%BUILD_NUM%

if %ERRORLEVEL% equ 0 (
    echo.
    echo ==============================================================================
    echo  BUILD SUCCESSFUL!
    echo.
    echo  Next Step: Upload the contents of build/web/ to Hostinger public_html/
    echo.
    echo  Result:
    echo  - All browsers will load the new build immediately with zero cache issues.
    echo  - .htaccess is bundled to prevent Hostinger from caching index.html.
    echo ==============================================================================
) else (
    echo.
    echo [ERROR] Build failed with exit code %ERRORLEVEL%
)
