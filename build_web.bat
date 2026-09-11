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
echo  Building Flutter Web (No-PWA Cache, Build ID: %BUILD_NUM%)
echo ==============================================================================

call flutter build web --release --pwa-strategy=none --build-number=%BUILD_NUM%

if %ERRORLEVEL% equ 0 (
    echo.
    echo [1/3] Copying .htaccess (LiteSpeed no-cache headers) to build/web/...
    copy /Y "web\.htaccess" "build\web\.htaccess" >nul

    echo [2/3] Bundling self-destructing flutter_service_worker.js to build/web/...
    copy /Y "web\flutter_service_worker.js" "build\web\flutter_service_worker.js" >nul

    echo [3/3] Ensuring flutter_bootstrap.js disables serviceWorkerSettings...
    powershell -Command "(Get-Content 'build/web/flutter_bootstrap.js') -replace 'window._flutter.loader.load\(\);', 'window._flutter.loader.load({ serviceWorkerSettings: null });' | Set-Content 'build/web/flutter_bootstrap.js'"

    echo.
    echo ==============================================================================
    echo  BUILD SUCCESSFUL!
    echo.
    echo  Next Step: Upload the contents of 'build/web/' to Hostinger public_html/
    echo.
    echo  How this eliminates manual cache clearing:
    echo  1. Version Sentinel in index.html automatically compares server build ID.
    echo     When a new build is detected, the browser purges caches and reloads automatically!
    echo  2. Legacy service workers are actively unregistered and killed on user arrival.
    echo  3. LiteSpeed cache on Hostinger is completely disabled for index.html and json.
    echo  4. Query parameter (?v=...) forces browsers to fetch the fresh main.dart.js.
    echo ==============================================================================
) else (
    echo.
    echo [ERROR] Build failed with exit code %ERRORLEVEL%
)
