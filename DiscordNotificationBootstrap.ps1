####################
# Import Functions #
####################
Import-Module "$PSScriptRoot\helpers"

# Get the config from our config file
$config = (Get-Content "$PSScriptRoot\config\conf.json") -Join "`n" | ConvertFrom-Json

# Should we log?
if($config.debug_log) {
	Start-Logging "$PSScriptRoot\log\debug.log"
}

# Add Veeam commands
Add-PSSnapin VeeamPSSnapin

# Get Veeam job from parent process
$parentpid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentcmd = (Get-WmiObject Win32_Process -Filter "processid='$parentpid'").CommandLine
$job = Get-VBRJob | ?{$parentcmd -like "*"+$_.Id.ToString()+"*"}
# Get the Veeam session
$session = Get-VBRBackupSession | ?{($_.OrigJobName -eq $job.Name) -and ($parentcmd -like "*"+$_.Id.ToString()+"*")}
# Store the ID and Job Name
$Id = '"' + $session.Id.ToString().ToString().Trim() + '"'
$JobName = '"' + $session.OrigJobName.ToString().Trim() + '"'
# Build argument string
$powershellArguments = "-file $PSScriptRoot\DiscordVeeamAlertSender.ps1", "-JobName $JobName", "-Id $Id"
# Start a new new script in a new process with some of the information gathered her
# Doing this allows Veeam to finish the current session so information on the job's status can be read
Start-Process -FilePath "powershell" -Verb runAs -ArgumentList $powershellArguments -WindowStyle hidden
