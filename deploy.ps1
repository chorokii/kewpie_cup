# =====================================================================
# Kewpie Cup (kewpie_cup) - GitHub Pages Deploy Script
# =====================================================================

$RepoName = "kewpie_cup"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Starting Web Build for $RepoName... " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Flutter Web Release Build with base-href /kewpie_cup/
flutter build web --release --base-href "/$RepoName/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter build web failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "[SUCCESS] Web build completed in build\web" -ForegroundColor Green

# 2. Initialize Git if not initialized
if (-not (Test-Path ".git")) {
    Write-Host "[GIT] Initializing Git repository..." -ForegroundColor Yellow
    git init
    git branch -M main
}

# 3. Add and Commit changes
Write-Host "[GIT] Staging and committing files..." -ForegroundColor Cyan
git add .
git commit -m "Deploy $RepoName web release"

# 4. Deploy build\web to GitHub Pages via gh-pages
Write-Host "[DEPLOY] Deploying build\web to GitHub Pages..." -ForegroundColor Green
npx --yes gh-pages -d build/web

if ($LASTEXITCODE -eq 0) {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host " DEPLOYMENT COMPLETE! " -ForegroundColor Green
    Write-Host " Your app will be live at: https://[Your-GitHub-Username].github.io/$RepoName/" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Host "[NOTICE] If gh-pages push failed, please make sure you have added your GitHub remote:" -ForegroundColor Yellow
    Write-Host "  git remote add origin https://github.com/[Your-GitHub-Username]/$RepoName.git" -ForegroundColor Yellow
    Write-Host "  git push -u origin main" -ForegroundColor Yellow
}
