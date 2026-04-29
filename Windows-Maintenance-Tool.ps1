#================================================================================
# SCRIPT: System Maintenance and Cleanup
# AUTHOR: Gemini Code Assist (Review)
#================================================================================

#--------------------------------------------------------------------------------
# Self-Elevation: Check for Administrator privileges and re-launch if needed.
# Most operations in this script (cleaning system folders, SFC, DISM) require
# elevated permissions. This block ensures the script runs with the necessary rights.
#--------------------------------------------------------------------------------
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires Administrator privileges. Attempting to re-launch as Administrator..."
    # Re-launch the script with elevated privileges
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-File "{0}"' -f $MyInvocation.MyCommand.Path)
    Exit # Exit the current non-elevated session
}

Clear-Host

#--------------------------------------------------------------------------------
# Reusable function to clean a specified directory.
# This avoids code duplication and improves error reporting.
#--------------------------------------------------------------------------------
function Invoke-Cleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Write-Host "Attempting to clean $Description at '$DirectoryPath'..."
    if (!(Test-Path -Path $DirectoryPath)) {
        Write-Warning "Directory not found: $DirectoryPath. Skipping."
        return
    }

    try {
        # Get child items and pipe them to Remove-Item.
        # -ErrorAction SilentlyContinue on Get-ChildItem prevents script halt on inaccessible subfolders (e.g., system junctions).
        # -ErrorAction SilentlyContinue on Remove-Item suppresses expected errors for files currently in use by other processes.
        Get-ChildItem -Path $DirectoryPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "$Description cleanup complete." -ForegroundColor Green
    }
    catch {
        # This catch block will handle any unexpected terminating errors during the process.
        Write-Warning "A critical error occurred while cleaning $Description : $_"
    }
}


Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " Cleaning Temporary Files (files + folders)"
Write-Host "===============================================" -ForegroundColor Cyan

# --- Clean user temp ---
Invoke-Cleanup -DirectoryPath $env:TEMP -Description "User temporary files"

# --- Clean Windows temp ---
Invoke-Cleanup -DirectoryPath "C:\Windows\Temp" -Description "Windows temporary files"

# --- Clean Prefetch ---
# NOTE: Cleaning Prefetch is generally not recommended for performance.
# Windows uses this folder to speed up application loading. Clearing it may
# result in slower application starts until the cache is rebuilt.
$prefetchChoice = Read-Host "Do you want to clean prefetch files? (This is not generally recommended) (y/n)"
if ($prefetchChoice -match '^[Yy]$') {
    Invoke-Cleanup -DirectoryPath "C:\Windows\Prefetch" -Description "Prefetch files"
}
else {
    Write-Host "Prefetch deletion Skipped" -ForegroundColor Yellow
}

# --- Run SFC (System File Checker) ---
# SFC scans for and attempts to repair corrupt Windows system files.
# We launch it in a new CMD window to show its detailed, real-time output.
# The 'timeout' command is used to keep the window open for 10 seconds after completion.
Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host " Checking System File Checker (SFC) "
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Starting SFC in a new window. Please wait for it to complete..."
Start-Process -FilePath "cmd.exe" `
    -ArgumentList '/c "sfc /scannow & echo. & echo === SFC Completed, closing in 10 seconds === & timeout /t 10"' `
    -Verb RunAs -Wait `
    -WorkingDirectory "C:\Windows\System32"

Write-Host "SFC check completed." -ForegroundColor Green

# --- Run DISM (Deployment Image Servicing and Management) ---
# DISM is used to check the health of the Windows Component Store and repair it if necessary.
Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host " Checking Windows Image Health (DISM) "
Write-Host "===============================================" -ForegroundColor Cyan
try {
    # First, run a quick health check. This is non-intrusive.
    $checkHealth = Repair-WindowsImage -Online -CheckHealth -ErrorAction Stop
    # If the state is anything other than "Healthy", we proceed with a full scan and restore.
    if ($checkHealth.ImageHealthState -ne "Healthy") {
        Write-Host "Quick check flagged possible corruption (often a leftover flag). Running full DISM RestoreHealth in a new window to verify and fix..." -ForegroundColor Yellow
        # RestoreHealth automatically performs a deep scan and repairs if needed, saving time over running ScanHealth first.
        Start-Process -FilePath "cmd.exe" `
            -ArgumentList '/c "DISM /Online /Cleanup-Image /RestoreHealth & echo. & echo === DISM Completed, closing in 10 seconds === & timeout /t 10"' `
            -Verb RunAs -Wait `
            -WorkingDirectory "C:\Windows\System32"
    }
    else {
        Write-Host "No corruption detected. Windows image is healthy." -ForegroundColor Green
    }
}
catch {
    Write-Error "An error occurred during the DISM health check: $_"
}

Write-Host "`n=== Script Completed! Press any key to exit. ===" -ForegroundColor Cyan
Pause
