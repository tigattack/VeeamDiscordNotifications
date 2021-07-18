# Import modules.
Import-Module Veeam.Backup.PowerShell
Import-Module "$PSScriptRoot\resources\Logger.psm1"
Import-Module "$PSScriptRoot\resources\VBRSessionInfo.psm1"

# Get the config from our config file.
$config = (Get-Content "$PSScriptRoot\config\conf.json") -Join "`n" | ConvertFrom-Json

# Start logging if logging is enabled in config.
if($config.debug_log) {
	## Set log file name
	$date = (Get-Date -UFormat %Y-%m-%d_%T | ForEach-Object { $_ -replace ":", "." })
	$logFile = "$PSScriptRoot\log\Log_Bootstrap-$date.log"
	## Start logging to file
	Start-Logging $logFile
}

# Get the command line used to start the Veeam session.
$parentPID = (Get-CimInstance Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentCmd = (Get-CimInstance Win32_Process -Filter "processid='$parentPID'").CommandLine

# Get the Veeam job and session IDs
$jobId = ([regex]::Matches($parentCmd, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')).Value[0]
$sessionId = ([regex]::Matches($parentCmd, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')).Value[1]
# Get the Veeam job details and hide warnings to mute the warning regarding depreciation of the use of this cmdlet to get Agent job details. At time of writing, there is no alternative.
$job = Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.Id.Guid -eq $jobId}

# Get the job time
Switch ($job.JobType) {
	{$_ -eq 'Backup'} {
		$jobType = 'VM'
	}
	{$_ -eq 'EpAgentBackup'} {
		$jobType = 'Agent'
	}
}

# Get the session information and name.
$sessionInfo = Get-VBRSessionInfo -SessionID $sessionId -JobType $jobType
$jobName = $sessionInfo.JobName

Write-LogMessage -Tag Info -Message "Bootstrap script for Veeam job '$jobName' ($jobId)."

# Build argument string for the alert sender.
$powershellArguments = "-file $PSScriptRoot\AlertSender.ps1", "-JobName $jobName", "-Id $sessionId", "-JobType $jobType"

# Start a new new script in a new process with some of the information gathered here.
# This allows Veeam to finish the current session faster and allows us gather information from the completed job.
Start-Process -FilePath "powershell" -Verb runAs -ArgumentList $powershellArguments -WindowStyle hidden

# Stop logging.
if($config.debug_log) {
	Stop-Logging
}
