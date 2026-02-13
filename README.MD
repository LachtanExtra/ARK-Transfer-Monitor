# ARK Transfer Monitor 🦖

A lightweight & fully automated background script for Windows that instantly backs up player character files during cross-ARK cluster transfers. 

If your server crashes during a transfer, or if ARK deletes a character due to a network glitch, this tool ensures you always have a safe, up-to-date backup of their profile ready to restore.

## ✨ Features
* **Smart Size Checking:** Only backs up files that grew in size (when the player uploads)
* **Temp File Immunity:** Strictly ignores ARK's locked `.tmpprofile` files
* **Dual-Cleanup Retention:** Prevents your hard drive from filling up by automatically deleting backups based on both **age** (e.g., older than 30 days) and a **per-player limit** (e.g., keep only the last 5 transfers per SteamID)
* **Zero Overhead:** Uses Windows `FileSystemWatcher` to check for file changes
* **Auto-Boot Integration:** Includes an installer that securely mounts the script to Windows Task Scheduler so it runs on boot

## ⚙️ Configuration

Edit the `config.json` file to match your server's environment. **Note:** You must use double-backslashes (`\\`) for Windows file paths in JSON.

```json
{
    "ClusterFolder": "C:\\Path\\To\\ARK\\ShooterGame\\Saved\\clusters\\YourClusterID",
    "BackupFolder": "C:\\Path\\To\\ARK_Backups\\TransferSafeguard",
    "DaysToKeepBackups": 30,
    "MaxBackupsPerID": 5
}
```
* `DaysToKeepBackups`: Deletes any backup older than this many days. (Set to `0` to disable)
* `MaxBackupsPerID`: The maximum number of backups to keep per unique player ID. (Oldest deleted when reached, set to `0` to disable)

## 🚀 Installation & Usage

1. Download the files and place them together in a dedicated folder on your server machine
2. Edit `config.json` with your paths and preferences
3. Right-click the Start Menu and open **PowerShell as Administrator**
4. Navigate to your folder: `cd "C:\Path\To\Your\ScriptFolder"`
5. Run the installer: `.\Install-AutoBootTask.ps1`

The installer will create a Windows Scheduled Task named **ARK Transfer Monitor** and start it immediately. It will now run completely hidden in the background, persisting through server reboots.

## 📝 Logs & Restoration

Every successful backup, ignored file, and automated deletion is logged in a clean `Backup_History.txt` file located inside your `BackupFolder`.

**To restore a lost character:**
1. Navigate to your `BackupFolder`
2. Find the player's most recent backup (e.g., `1234567890_2026-02-13_08-00-00.arkprofile`)
3. Delete the timestamp from the filename so it is just their ID (e.g., `1234567890`)
4. Drop it back into your server's live `clusters` folder. 
5. The player can now safely download their character.

## 🛑 Stopping or Updating the Script
If you change your `config.json`, you must restart the background task so it reads the new settings. Run this in an Administrator PowerShell window:
```powershell
Stop-ScheduledTask -TaskName "ARK Transfer Monitor"
Start-ScheduledTask -TaskName "ARK Transfer Monitor"
```