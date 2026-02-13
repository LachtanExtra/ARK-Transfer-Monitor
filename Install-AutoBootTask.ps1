# Ensure the script is running as Administrator (required to make scheduled tasks)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERROR: You need to run this script as Administrator to create a Task." -ForegroundColor Red
    Pause
    Exit
}

# Automatically find where we are located
$ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = Get-Location }

$TargetScript = Join-Path $ScriptDir "ArkTransferMonitor.ps1"
$TaskName = "ARK Transfer Monitor"

# Check if the monitor script actually exists here
if (!(Test-Path -Path $TargetScript)) {
    Write-Host "ERROR: Could not find ArkTransferMonitor.ps1 in $ScriptDir" -ForegroundColor Red
    Write-Host "Make sure both scripts are in the exact same folder." -ForegroundColor Yellow
    Pause
    Exit
}

Write-Host "Creating Scheduled Task for $TargetScript..." -ForegroundColor Cyan

# 1. Define what to run (PowerShell, hidden, bypassing execution policies)
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TargetScript`"" -WorkingDirectory $ScriptDir

# 2. Define when to run (At system startup)
$Trigger = New-ScheduledTaskTrigger -AtStartup

# 3. Define how to run (As SYSTEM account, meaning it runs perfectly in the background without a user logged in)
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# 4. Define the rules (Don't ever stop the task, even if it runs for 3+ days)
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

# 5. Register the task into Windows
try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    Write-Host "SUCCESS! The task '$TaskName' has been created." -ForegroundColor Green
    Write-Host "Your ARK Transfer Monitor will now start automatically whenever this computer boots up." -ForegroundColor Green
    Start-ScheduledTask -TaskName "ARK Transfer Monitor"
    Write-Host "Ark Transfer Monitor active, no need to restart :)"
} catch {
    Write-Host "FAILED to create the task. Error details:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")