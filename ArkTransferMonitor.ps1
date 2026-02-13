$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = Get-Location }
$ConfigFile = Join-Path $ScriptDir "config.json"

if (!(Test-Path -Path $ConfigFile)) {
    Write-Host "CRITICAL ERROR: Could not find config.json in $ScriptDir" -ForegroundColor Red
    Pause
    Exit
}

$Config = Get-Content -Path $ConfigFile | ConvertFrom-Json
$global:ClusterFolder = $Config.ClusterFolder
$global:BackupFolder  = $Config.BackupFolder
$global:RetentionDays = $Config.DaysToKeepBackups
$global:MaxBackups    = $Config.MaxBackupsPerID

if (!(Test-Path -Path $global:BackupFolder)) {
    New-Item -ItemType Directory -Path $global:BackupFolder | Out-Null
}

$global:LogFile = Join-Path $global:BackupFolder "Backup_History.txt"

# --- MEMORY SYSTEM ---
$global:FileSizes = @{}

if (Test-Path $global:ClusterFolder) {
    Get-ChildItem -Path $global:ClusterFolder -File | ForEach-Object {
        $global:FileSizes[$_.Name] = $_.Length
    }
}

$Watcher = New-Object IO.FileSystemWatcher $global:ClusterFolder, "*"
$Watcher.IncludeSubdirectories = $false
$Watcher.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, Size'

$Action = {
    $FilePath = $Event.SourceEventArgs.FullPath
    $FileName = $Event.SourceEventArgs.Name
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $Extension = [System.IO.Path]::GetExtension($FileName)
    
    if ($Extension -like "*.tmp*" -or $FileName -like "*.tmp*") { return }
    
    Start-Sleep -Seconds 2 
    
    $MaxReadRetries = 10
    $ReadRetryCount = 0
    $CurrentSize = $null

    while ($ReadRetryCount -lt $MaxReadRetries) {
        try {
            $FileInfo = Get-Item -Path $FilePath -ErrorAction Stop
            $CurrentSize = $FileInfo.Length
            break
        } catch {
            $ReadRetryCount++
            Start-Sleep -Seconds 1
        }
    }

    if ($null -eq $CurrentSize) { return }

    $PreviousSize = if ($global:FileSizes.ContainsKey($FileName)) { $global:FileSizes[$FileName] } else { 0 }
    $global:FileSizes[$FileName] = $CurrentSize
    
    # Ignore files that shrunk (download) & item/dino uploads
    #TODO: Implement a config filter for dino & item uploads
    if ($CurrentSize -gt $PreviousSize -and $CurrentSize -ge 500KB) {
        $MaxRetries = 10
        $RetryCount = 0
        $Copied = $false

        while (-not $Copied -and $RetryCount -lt $MaxRetries) {
            try {
                $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
                $BackupFileName = "$BaseName`_$Timestamp$Extension"
                $Destination = Join-Path $global:BackupFolder $BackupFileName

                Copy-Item -Path $FilePath -Destination $Destination -Force -ErrorAction Stop
                $Copied = $true
                
                $KB = [math]::Round($CurrentSize / 1024, 2)
                Add-Content -Path $global:LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SUCCESS: Backed up $FileName ($KB KB)"
                
                # --- 1. GLOBAL TIME-BASED CLEANUP ---
                if ($global:RetentionDays -gt 0) {
                    $CutoffDate = (Get-Date).AddDays(-$global:RetentionDays)
                    $OldGlobalFiles = Get-ChildItem -Path $global:BackupFolder -File | 
                        Where-Object { $_.LastWriteTime -lt $CutoffDate -and $_.Name -ne "Backup_History.txt" }
                    
                    foreach ($OldFile in $OldGlobalFiles) {
                        Remove-Item -Path $OldFile.FullName -Force
                        Add-Content -Path $global:LogFile -Value " -> Auto-deleted (Older than $global:RetentionDays days): $($OldFile.Name)"
                    }
                }

                # --- 2. PER-PLAYER LIMIT CLEANUP ---
                if ($global:MaxBackups -gt 0) {
                    $PlayerBackups = Get-ChildItem -Path $global:BackupFolder -Filter "$BaseName*" -File | 
                                     Where-Object { $_.Name -ne "Backup_History.txt" } | 
                                     Sort-Object LastWriteTime
                    
                    if ($PlayerBackups.Count -gt $global:MaxBackups) {
                        $ToDeleteCount = $PlayerBackups.Count - $global:MaxBackups
                        $OldestBackups = $PlayerBackups | Select-Object -First $ToDeleteCount
                        
                        foreach ($OldBackup in $OldestBackups) {
                            Remove-Item -Path $OldBackup.FullName -Force
                            Add-Content -Path $global:LogFile -Value " -> Auto-deleted (Exceeded max $global:MaxBackups limit): $($OldBackup.Name)"
                        }
                    }
                }

            } catch {
                $RetryCount++
                Start-Sleep -Seconds 1
            }
        }

        if (-not $Copied) {
            Add-Content -Path $global:LogFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: Locked file $FileName"
        }
    }
}

Register-ObjectEvent $Watcher "Created" -Action $Action | Out-Null
Register-ObjectEvent $Watcher "Changed" -Action $Action | Out-Null
Register-ObjectEvent $Watcher "Renamed" -Action $Action | Out-Null

while ($true) {
    Start-Sleep -Seconds 1
}