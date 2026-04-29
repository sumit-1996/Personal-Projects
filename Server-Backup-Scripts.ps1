# =============================================================================
# Purpose: Backup Server data to NAS, excluding .TSF or other temp files
# proofed by Gemini
# =============================================================================

# 1. Configuration
# -----------------------------------------------------------------------------

# Source Directories
$sourceDirs = @(
    "D:\<Your_Folder_1>",
    "D:\<Your_Folder_2>",
    "D:\<Your_Folder_3>",
    "D:\<Tally_Data_Folder>"
)

# Destination Base Directory (UNC path to NAS)
$destBaseDir = "\\<YOUR_NAS_IP>\<YOUR_BACKUP_SHARE>"

# Date Format for Folder Name
$date = Get-Date -Format "yyyy-MM-dd"

# 2. Setup
# -----------------------------------------------------------------------------

# Create the dated backup folder on NAS
$backupFolder = Join-Path -Path $destBaseDir -ChildPath $date
if (-not (Test-Path -Path $backupFolder)) {
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
}

# Define Log File
$logFile = Join-Path -Path $backupFolder -ChildPath "backup_log.txt"

# Helper Function: Write to log
function LogMessage {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMessage = "[$timestamp] $message"
    Add-Content -Path $logFile -Value $fullMessage
    Write-Host $fullMessage -ForegroundColor Cyan
}

# Track overall success
$script:BackupFailed = $false

# 3. Execution
# -----------------------------------------------------------------------------

LogMessage "--- Backup Process Started ---"
LogMessage "Destination: $backupFolder"

foreach ($sourceDir in $sourceDirs) {
    # Check if source exists before attempting copy
    if (Test-Path $sourceDir) {
        $folderName = Split-Path -Leaf $sourceDir
        $destDir = Join-Path -Path $backupFolder -ChildPath $folderName
        
        LogMessage "Processing: $folderName"

        # Robocopy Options
        # /MIR : Mirror a directory tree (PURGES files in dest that are not in source)
        # /XO  : Exclude Older files (Speeds up copy)
        # /FFT : Assume FAT File Times (Critical for NAS to allow 2-sec granularity difference)
        # /R:2 : Retry 2 times on failure
        # /W:2 : Wait 2 seconds between retries
        # /NP  : No Progress (Prevents % bars from cluttering the log file)
        
        $roboArgs = @($sourceDir, $destDir, "/MIR", "/XO", "/FFT", "/R:2", "/W:2", "/NP", "/LOG+:$logFile")

        # Specific rule: Exclude Any Temp files (Example .TSF) only for the specific data folder
        if ($sourceDir -eq "D:\<AnyServer_Data_Folder>") {
            LogMessage "Applying Tally exclusion filters (.TSF) for $folderName"
            $roboArgs += "/XF"
            $roboArgs += "*.TSF"
            $roboArgs += "TACCESS.TSF"
            $roboArgs += "TEXCL.TSF"
        }

        # Execute Robocopy
        try {
            # Start-Process allows us to wait for the command to finish cleanly
            $process = Start-Process -FilePath "robocopy.exe" -ArgumentList $roboArgs -Wait -NoNewWindow -PassThru
            $exitCode = $process.ExitCode
            
            # Robocopy Exit Codes:
            # 0 = No changes
            # 1 = Successful copy
            # 2 = Extra files detected
            # 4 = Mismatches detected
            # 8+ = FAILED
            
            if ($exitCode -ge 8) {
                $script:BackupFailed = $true
                LogMessage "ERROR: Robocopy failed for $folderName with exit code $exitCode"
            } else {
                LogMessage "Success: $folderName (Code: $exitCode)"
            }
        }
        catch {
            $script:BackupFailed = $true
            LogMessage "CRITICAL ERROR: Could not run Robocopy for $sourceDir. Details: $_"
        }
    }
    else {
        LogMessage "WARNING: Source directory not found: $sourceDir"
    }
}

# 4. Final Reporting
# -----------------------------------------------------------------------------

if ($script:BackupFailed) {
    LogMessage "--- Backup completed WITH ERRORS ---"
    # Optional: Add email alert logic here if needed
} else {
    LogMessage "--- Backup completed SUCCESSFULLY ---"
}