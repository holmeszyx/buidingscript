# Android Build Script for Windows (PowerShell)
# This script builds Android APK or AAB files with proper file management

param(
    [string]$DataDir = ".",
    [string]$WorkDir = ".",
    [string]$OutputDir = "output"
)

# Configuration - Files to copy (modify as needed)
$FilesToCopy = @(
    @{Source = "local.properties"; Destination = "local.properties"},
    @{Source = "signing.properties"; Destination = "signing.properties"}
)

# Build template directories to clean
$BuildTemplateDirs = @(
    "build",
    "app/build"
)

# Record the initial running directory
$InitialDir = Get-Location

Write-Host "=== Android Build Script ===" -ForegroundColor Green
Write-Host "Data Directory: $DataDir" -ForegroundColor Yellow
Write-Host "Work Directory: $WorkDir" -ForegroundColor Yellow
Write-Host "Output Directory: $OutputDir" -ForegroundColor Yellow
Write-Host "Initial Directory: $InitialDir" -ForegroundColor Yellow

# Step 1: Copy files to destination directory
Write-Host "`n[Step 1] Copying files..." -ForegroundColor Cyan
foreach ($file in $FilesToCopy) {
    $sourcePath = Join-Path $DataDir $file.Source
    $destPath = Join-Path $WorkDir $file.Destination
    
    if (Test-Path $sourcePath) {
        $destDir = Split-Path $destPath -Parent
        if (!(Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "  Copied: $($file.Source) -> $($file.Destination)" -ForegroundColor Green
    } else {
        Write-Host "  Warning: Source file not found: $sourcePath" -ForegroundColor Yellow
    }
}

# Step 2: Clean build template directories
Write-Host "`n[Step 2] Cleaning build directories..." -ForegroundColor Cyan
foreach ($dir in $BuildTemplateDirs) {
    $dirPath = Join-Path $WorkDir $dir
    if (Test-Path $dirPath) {
        Remove-Item -Path $dirPath -Recurse -Force
        Write-Host "  Deleted: $dir" -ForegroundColor Green
    } else {
        Write-Host "  Not found: $dir" -ForegroundColor Gray
    }
}

# Step 3: Get user selection for build artifact
Write-Host "`n[Step 3] Select build artifact type:" -ForegroundColor Cyan
Write-Host "  1. APK (Android Package)"
Write-Host "  2. AAB (Android App Bundle)"
Write-Host ""

do {
    $choice = Read-Host "Enter your choice (1 for APK, 2 for AAB)"
} while ($choice -notin @("1", "2"))

$buildType = if ($choice -eq "1") { "apk" } else { "aab" }
Write-Host "Selected: $buildType" -ForegroundColor Green

# Step 4: Execute build command
Write-Host "`n[Step 4] Building $buildType..." -ForegroundColor Cyan

$gradlewPath = Join-Path $WorkDir "gradlew.bat"
if (!(Test-Path $gradlewPath)) {
    Write-Host "Error: gradlew.bat not found in $WorkDir" -ForegroundColor Red
    exit 1
}

try {
    Set-Location $WorkDir
    
    if ($buildType -eq "apk") {
        Write-Host "Executing: .\gradlew.bat assembleRelease" -ForegroundColor Yellow
        & .\gradlew.bat assembleRelease "-Duser.language=en"
    } else {
        Write-Host "Executing: .\gradlew.bat bundleRelease" -ForegroundColor Yellow
        & .\gradlew.bat bundleRelease "-Duser.language=en"
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        # Restore initial directory before exiting
        Set-Location $InitialDir
        exit $LASTEXITCODE
    }
    
    Write-Host "Build completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "Build failed: $($_.Exception.Message)" -ForegroundColor Red
    # Restore initial directory before exiting
    Set-Location $InitialDir
    exit 1
} finally {
    # Restore initial directory after build execution
    Write-Host "Restoring initial directory: $InitialDir" -ForegroundColor Cyan
    Set-Location $InitialDir
}

# Step 5: Copy build artifact to output directory
Write-Host "`n[Step 5] Copying build artifact..." -ForegroundColor Cyan

# Create output directory if it doesn't exist
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

if ($buildType -eq "apk") {
    $artifactPath = Join-Path $WorkDir "app\build\outputs"
    $outputFile = Join-Path $OutputDir "app-release-apk"
} else {
    $artifactPath = Join-Path $WorkDir "app\build\outputs"
    $outputFile = Join-Path $OutputDir "app-release-aab"
}

if (Test-Path $artifactPath) {
    # Clean the specific destination before copying
    if (Test-Path $outputFile) {
        Write-Host "Cleaning existing destination: $outputFile" -ForegroundColor Yellow
        Remove-Item -Path $outputFile -Recurse -Force
    }
    
    # Copy artifact (handle both file and folder)
    if ((Get-Item $artifactPath).PSIsContainer) {
        # Source is a folder
        Copy-Item -Path $artifactPath -Destination $outputFile -Recurse -Force
        Write-Host "Artifact folder copied to: $outputFile" -ForegroundColor Green
    } else {
        # Source is a file
        Copy-Item -Path $artifactPath -Destination $outputFile -Force
        Write-Host "Artifact file copied to: $outputFile" -ForegroundColor Green
    }
} else {
    Write-Host "Warning: Build artifact not found at: $artifactPath" -ForegroundColor Yellow
}

Write-Host "`n=== Build Process Completed ===" -ForegroundColor Green
Write-Host "Check the output directory: $OutputDir" -ForegroundColor Yellow
