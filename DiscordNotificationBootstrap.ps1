# Import Functions.
Import-Module "$PSScriptRoot\resources\logger.psm1"

# Get the config from our config file.
$config = (Get-Content "$PSScriptRoot\config\conf.json") -Join "`n" | ConvertFrom-Json

# Log if enabled in config.
if($config.debug_log) {
	Start-Logging "$PSScriptRoot\log\debug.log"
}

# Import Veeam module.
Import-Module Veeam.Backup.PowerShell

# Get the Veeam job from parent process.
$parentpid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentcmd = (Get-WmiObject Win32_Process -Filter "processid='$parentpid'").CommandLine
$job = Get-VBRJob | ?{$parentcmd -like "*"+$_.Id.ToString()+"*"}

# Get the Veeam session.
$session = Get-VBRBackupSession | ?{($_.OrigJobName -eq $job.Name) -and ($parentcmd -like "*"+$_.Id.ToString()+"*")}

# Store the job's name and ID.
$Id = '"' + $session.Id.ToString().ToString().Trim() + '"'
$JobName = '"' + $session.OrigJobName.ToString().Trim() + '"'

# Build argument string for the alert sender.
$powershellArguments = "-file $PSScriptRoot\DiscordVeeamAlertSender.ps1", "-JobName $JobName", "-Id $Id"

# Start a new new script in a new process with some of the information gathered here.
# This allows Veeam to finish the current session so that we can gather information from the completed job.
Start-Process -FilePath "powershell" -Verb runAs -ArgumentList $powershellArguments -WindowStyle hidden

# Stop logging.
if($config.debug_log) {
	Stop-Logging "$PSScriptRoot\log\debug.log"
}
