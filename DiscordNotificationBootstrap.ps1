# Import Functions.
Import-Module "$PSScriptRoot\resources\logger.psm1"

# Get the config from our config file.
$config = Get-Content -Raw "$PSScriptRoot\config\conf.json" | ConvertFrom-Json

# Start logging if logging is enabled in config.
if($config.debug_log) {
	## Set log file name
	$date = (Get-Date -UFormat %Y-%m-%d_%T | ForEach-Object { $_ -replace ':', '.' })
	$logFile = "$PSScriptRoot\log\Log_Bootstrap-$date.log"
	## Start logging to file
	Start-Logging $logFile
}

# Import Veeam module.
Import-Module Veeam.Backup.PowerShell -DisableNameChecking

# Get the command line used to start the Veeam session.
$parentPID = (Get-CimInstance Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentCmd = (Get-CimInstance Win32_Process -Filter "processid='$parentPID'").CommandLine
$job = Get-VBRJob | Where-Object{$parentCmd -like '*'+$_.Id.ToString()+'*'}

# Get the Veeam session.
$session = Get-VBRBackupSession | Where-Object{($_.OrigJobName -eq $job.Name) -and ($parentCmd -like '*'+$_.Id.ToString()+'*')}

# Store the job's name and ID.
$id = '"' + $session.Id.ToString().ToString().Trim() + '"'
$jobName = '"' + $session.OrigJobName.ToString().Trim() + '"'

# Build argument string for the alert sender.
$powershellArguments = "-file $PSScriptRoot\DiscordVeeamAlertSender.ps1", "-JobName $jobName", "-Id $id"

# Start a new new script in a new process with some of the information gathered here.
# This allows Veeam to finish the current session faster and allows us gather information from the completed job.
Start-Process -FilePath 'powershell' -Verb runAs -ArgumentList $powershellArguments -WindowStyle hidden

# Stop logging.
if($config.debug_log) {
	Stop-Logging
}
