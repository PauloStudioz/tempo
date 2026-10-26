# Build and Package Script for Tempo Windows Application
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Building Tempo Windows Application...   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Build release binaries with Flutter
Write-Host "`n[1/3] Compiling Release Windows Binaries..." -ForegroundColor Yellow
flutter build windows
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build windows failed."
    exit 1
}

# 2. Build Inno Setup Installer
Write-Host "`n[2/3] Compiling Standalone Setup Installer..." -ForegroundColor Yellow
$isccPath = "C:\Users\LOQ\AppData\Local\Programs\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $isccPath)) {
    $iscc = Get-Command iscc -ErrorAction SilentlyContinue
    if ($iscc) { $isccPath = $iscc.Source }
}

if (Test-Path $isccPath) {
    & $isccPath "$PSScriptRoot\installer\tempo_setup.iss"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Inno Setup compilation failed."
    }
} else {
    Write-Warning "Inno Setup compiler (ISCC.exe) not found. Skipping installer build."
}

# 3. Build Portable ZIP Package
Write-Host "`n[3/3] Generating Portable ZIP Archive..." -ForegroundColor Yellow
$releaseDir = "$PSScriptRoot\build\windows\x64\runner\Release"
$distDir = "$PSScriptRoot\dist"
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
$zipPath = "$distDir\Tempo-Windows-Portable-1.0.0.zip"

Push-Location $releaseDir
& tar.exe -a -c -f $zipPath *
Pop-Location

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host " Build Complete! Artifacts in dist/:" -ForegroundColor Green
Get-ChildItem $distDir | ForEach-Object {
    Write-Host (" - {0} ({1:N1} MB)" -f $_.Name, ($_.Length / 1MB)) -ForegroundColor Green
}
Write-Host "=========================================" -ForegroundColor Green

