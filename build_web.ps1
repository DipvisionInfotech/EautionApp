$buildNum = Get-Date -Format "yyyyMMddHHmm"
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " Building Flutter Web with Unique Build ID: $buildNum" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

flutter build web --release --build-number=$buildNum

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host " BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host ""
    Write-Host " Next Step: Upload the contents of 'build/web/' to Hostinger public_html/"
    Write-Host ""
    Write-Host " Result:"
    Write-Host " - All browsers (Chrome, Safari, Edge, mobile) will automatically load"
    Write-Host "   the new build immediately without any manual cache clearing."
    Write-Host " - .htaccess is already bundled to prevent Hostinger from caching index.html."
    Write-Host "==============================================================================" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
