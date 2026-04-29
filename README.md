# Server Automation & Backup Scripts 🛠️

This repository contains PowerShell scripts designed to automate routine Windows Server administration tasks, ensure data redundancy, and simplify IT operations.

## Featured Script: `ServerDataBackupToNas.ps1`
A robust, enterprise-ready PowerShell script that automates the backup of local server data to a Network Attached Storage (NAS) device. 

### Key Features:
* **Exact Mirroring:** Uses `Robocopy` to create an exact replica of the source directories, copying only new or changed files for maximum efficiency.
* **Error Handling & Resiliency:** Configured with retry limits (`/R:2`) and wait times (`/W:2`) to handle locked files without freezing the script.
* **Detailed Logging:** Automatically generates a date-stamped log file (`backup_log.txt`) tracking the exact time of execution, files copied, and any errors encountered.
* **Security Conscious:** Uses placeholders for sensitive IP addresses and directory paths, ensuring internal network structures are not hardcoded.
* **Custom Exclusions:** Automatically skips temporary and locked system files (e.g., `.TSF`).

### Prerequisites
* Windows PowerShell 5.1 or later.
* Network access and write permissions to the target NAS.
* Ensure `robocopy.exe` is available in your system path (Native to modern Windows OS).

### How to Use
1. Download `ServerDataBackupToNas.ps1`.
2. Open the script in your preferred editor (e.g., VS Code or PowerShell ISE).
3. Replace the placeholder `<Your_Folder>` paths in the `$sourceDirs` array with your actual source directories.
4. Replace `<YOUR_NAS_IP>` and `<YOUR_BACKUP_SHARE>` with your actual NAS UNC path.
5. Run the script manually or set it up as a Daily Trigger in **Windows Task Scheduler**.

## Featured Script: `Windows-Maintenance-Tool.ps1`
A comprehensive local system maintenance script that automates routine Windows cleanup, file integrity verification, and image health repair. 

### Key Features:
* **Auto-Elevation (UAC):** The script automatically detects if it is running with standard user rights and dynamically re-launches itself to request the necessary Administrator privileges.
* **Smart DISM Integration:** Performs a rapid, non-intrusive `Repair-WindowsImage -CheckHealth` scan. It only triggers the time-consuming `RestoreHealth` deep scan if actual corruption is detected.
* **System File Checker (SFC):** Integrates standard Windows file integrity checks to find and replace corrupted OS files.
* **Automated Cleanup:** Safely purges temporary system folders and leftover files to free up disk space and improve local machine performance.
