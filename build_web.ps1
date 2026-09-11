$buildNum = Get-Date -Format "yyyyMMddHHmm"
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " Building Flutter Web (No-PWA Cache, Build ID: $buildNum)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

flutter build web --release --pwa-strategy=none --build-number=$buildNum

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[1/3] Copying .htaccess (LiteSpeed no-cache headers) to build/web/..." -ForegroundColor Yellow
    Copy-Item -Path "web\.htaccess" -Destination "build\web\.htaccess" -Force

    Write-Host "[2/3] Bundling self-destructing flutter_service_worker.js to build/web/..." -ForegroundColor Yellow
    Copy-Item -Path "web\flutter_service_worker.js" -Destination "build\web\flutter_service_worker.js" -Force

    Write-Host "[3/3] Ensuring flutter_bootstrap.js disables serviceWorkerSettings..." -ForegroundColor Yellow
    $bootstrapPath = "build\web\flutter_bootstrap.js"
    if (Test-Path $bootstrapPath) {
        (Get-Content $bootstrapPath) -replace 'window._flutter.loader.load\(\);', 'window._flutter.loader.load({ serviceWorkerSettings: null });' | Set-Content $bootstrapPath
    }

    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host " BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host ""
    Write-Host " Next Step: Upload the contents of 'build/web/' to Hostinger public_html/"
    Write-Host ""
    Write-Host " How this eliminates manual cache clearing:"
    Write-Host " 1. Version Sentinel in index.html automatically compares server build ID."
    Write-Host "    When a new build is detected, the browser purges caches and reloads automatically!"
    Write-Host " 2. Legacy service workers are actively unregistered and killed on user arrival."
    Write-Host " 3. LiteSpeed cache on Hostinger is completely disabled for index.html and json."
    Write-Host " 4. Query parameter (?v=...) forces browsers to fetch the fresh main.dart.js."
    Write-Host "==============================================================================" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
