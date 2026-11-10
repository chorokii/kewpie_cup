[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# =====================================================================
# Kewpie Cup (kewpie_cup) - GitHub Pages Deploy Script
# =====================================================================

$RepoName = "kewpie_cup"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Starting Web Build for $RepoName... " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Check Git Repository Initialization
if (-not (Test-Path ".git")) {
    Write-Host "[GIT] Initializing Git repository..." -ForegroundColor Yellow
    git init
    git branch -M main
}

# 2. Check Remote Origin URL
$remoteUrl = & git remote get-url origin 2>$null
if (-not $remoteUrl) {
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host " [ERROR] GitHub remote (origin) URL is NOT configured!" -ForegroundColor Red
    Write-Host " Please run this command ONCE in Terminal to link your GitHub repo:" -ForegroundColor Yellow
    Write-Host "   git remote add origin https://github.com/chorokii/$RepoName.git" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Red
    exit 1
}

# 3. Flutter Web Release Build with base-href /kewpie_cup/
Write-Host "[BUILD] Running Flutter Web Release Build..." -ForegroundColor Cyan
flutter build web --release --base-href "/$RepoName/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter build web failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "[SUCCESS] Web build completed in build\web" -ForegroundColor Green

# 4. Add and Commit changes
Write-Host "[GIT] Staging and committing files..." -ForegroundColor Cyan
git add .
git commit -m "Deploy $RepoName web release" 2>$null

# 5. Push source code to GitHub main branch
Write-Host "[GIT] Pushing source code to GitHub main branch..." -ForegroundColor Cyan
git push -u origin main 2>$null

# 6. Deploy build\web to GitHub Pages via gh-pages
Write-Host "[DEPLOY] Deploying build\web to GitHub Pages..." -ForegroundColor Green
npx --yes gh-pages -d build/web

if ($LASTEXITCODE -eq 0) {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host " DEPLOYMENT COMPLETE! " -ForegroundColor Green
    Write-Host " Your app will be live shortly at: https://chorokii.github.io/$RepoName/" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host " [NOTICE] GitHub repository '$RepoName' was not found on your GitHub account." -ForegroundColor Red
    Write-Host " Please open https://github.com/new and create a new Public repository named '$RepoName'." -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Red
}
