# Function to be used when an error is encountered
function DeploymentError {
	$issues = 'https://github.com/tigattack/VeeamDiscordNotifications/issues'

	Write-Output "An error occured: $($_.ScriptStackTrace)"
	Write-Output "Please raise an issue at $issues"

	do {
		$launchIssues = Read-Host -Prompt 'Do you wish to launch this URL? Y/N'
	}
	until ($launchIssues -eq 'Y' -or $launchIssues -eq 'N')
	If ($launchIssues -eq 'Y') {
		Start-Process "$issues/new?assignees=tigattack&labels=bug&template=bug_report.md&title=[BUG]+Veeam%20configuration%20deployment%20error"
	}
}

# Import Veeam module
Import-Module Veeam.Backup.PowerShell -DisableNameChecking

# Write notice
Write-Output "`nPlease note: This script can currently only be used to configure VM backup jobs and VM replica jobs.`n"

# Get all supported jobs
$backupJobs = Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.IsBackupJob -or $_.IsReplica}

# Make sure we found some jobs
if ($backupJobs.Count -eq 0) {
	Write-Output 'No supported jobs found; Exiting.'
	Start-Sleep 10
	exit
}

# Set name
$jobNameType = "'$($job.Name)' (type '$($job.JobType)')"

# Post-job script for Discord notifications
$newPostScriptCmd = 'Powershell.exe -ExecutionPolicy Bypass -File C:\VeeamScripts\VeeamDiscordNotifications\Bootstrap.ps1'

# Run foreach loop for all found backup jobs
foreach ($job in $backupJobs) {
	# Get post-job script options for job
	$jobOptions = $job.GetOptions()
	$postScriptEnabled = $jobOptions.JobScriptCommand.PostScriptEnabled
	$postScriptCmd = $jobOptions.JobScriptCommand.PostScriptCommandLine

	# Check if job is already configured with correct post-job script
	if ($postScriptCmd.EndsWith('Bootstrap.ps1') -or $postScriptCmd.EndsWith("Bootstrap.ps1'")) {
		Write-Output "`nJob $jobNameType is already configured for Discord notifications; Skipping."
		Continue
	}

	# Different actions whether post-job script is already enabled. If yes we ask to modify it, if not we ask to enable & set it.
	if ($postScriptEnabled) {
		Write-Output "`nJob $jobNameType has an existing post-job script.`nScript: $postScriptCmd"
		Write-Output "`nIf you wish to receive Discord notifications for this job, you must overwrite the existing post-job script."

		do {
			$overWriteCurrentCmd = Read-Host -Prompt 'Do you wish to overwrite it? Y/N'
		}
		until ($overWriteCurrentCmd -eq 'Y' -or $overWriteCurrentCmd -eq 'N')

		switch ($overWriteCurrentCmd) {

			# Default action will be to skip the job.
			default { Write-Output "`nSkipping job $jobNameType`n"}
			Y {
				try {
					# Check to see if the script has even changed
					if ($postScriptCmd -ne $newPostScriptCmd) {

						# Script is not the same. Update the script command line.
						$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
						Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

						Write-Output "Updated post-job script for job $jobNameType.`nOld: $postScriptCmd`nNew: $newPostScriptCmd"
						Write-Output "Job $jobNameType is now configured for Discord notifications."
					}
					else {
						# Script hasn't changed. Notify user of this and continue.
						Write-Output "Job $jobNameType is already configured for Discord notifications; Skipping."
					}
				}
				catch {
					DeploymentError
				}
			}
		}
	}
	else {
		do {
			$setNewPostScript = Read-Host -Prompt "`nDo you wish to receive Discord notifications for job $jobNameType? Y/N"
		}
		until ($setNewPostScript -eq 'Y' -or $setNewPostScript -eq 'N')

		Switch ($setNewPostScript) {
			# Default action will be to skip the job.
			default { Write-Output "Skipping job $jobNameType`n"}
			Y {
				try {
					# Sets post-job script to Enabled and sets the command line to full command including path.
					$jobOptions.JobScriptCommand.PostScriptEnabled = $true
					$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
					Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

					Write-Output "Job $jobNameType is now configured for Discord notifications."
				}
				catch {
					DeploymentError
				}
			}
		}
	}
}

# Inform user about agent jobs
$agentJobCount = (Get-VBRComputerBackupJob | Where-Object {$_.Mode -eq 'ManagedByBackupServer'}).Count
If ($agentJobCount -gt 0) {
	If ($agentJobCount -eq 1) {
		Write-Output "`n$($agentJobCount) agent job has been found."
	}
	Else {
		Write-Output "`n$($agentJobCount) agent jobs have been found."
	}
	Write-Output "Unfortunately they cannot be configured automatically due to limitations in Veeam's PowerShell module."
	Write-Output 'Please manually configure them to receive Discord notifications.'
}

Write-Output "`n`Finished. Exiting."
Start-Sleep 10
exit
