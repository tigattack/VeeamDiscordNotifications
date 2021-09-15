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

# Get all supported jobs
$vbrJobs = Get-VBRJob -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Where-Object {$_.IsBackupJob}

# Make sure we found some jobs
if ($vbrJobs.Count -eq 0) {
	Write-Output 'No supported jobs found; Exiting.'
	Start-Sleep 10
	exit
}

# Post-job script for Discord notifications
$newPostScriptCmd = "Powershell.exe -ExecutionPolicy 'Bypass' -File 'C:\VeeamScripts\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1'"

# Run foreach loop for all found jobs
foreach ($job in $vbrJobs) {
	# Get post-job script options for job
	$jobOptions = $job.GetOptions()
	$postScriptEnabled = $jobOptions.JobScriptCommand.PostScriptEnabled
	$postScriptCmd = $jobOptions.JobScriptCommand.PostScriptCommandLine

	# Check if job is already configured with correct post-job script
	if ($postScriptCmd.EndsWith('DiscordNotificationBootstrap.ps1') -or $postScriptCmd.EndsWith("DiscordNotificationBootstrap.ps1'")) {
		Write-Output "`nJob '$($job.Name)' is already configured for Discord notifications; Skipping."
		Continue
	}

	# Different actions whether post-job script is already enabled. If yes we ask to modify it, if not we ask to enable & set it.
	if ($postScriptEnabled) {
		Write-Output "`nJob '$($job.Name)' has an existing post-job script.`nScript: $postScriptCmd"
		Write-Output "`nIf you wish to receive Discord notifications for this job, you must overwrite the existing post-job script."

		do {
			$overWriteCurrentCmd = Read-Host -Prompt 'Do you wish to overwrite it? Y/N'
		}
		until ($overWriteCurrentCmd -eq 'Y' -or $overWriteCurrentCmd -eq 'N')

		switch ($overWriteCurrentCmd) {
			# Default action will be to skip the job.
			default { Write-Output "`nSkipping job '$($job.Name)'`n"}
			Y {
				try {
					# Check to see if the script has even changed
					if ($postScriptCmd -ne $newPostScriptCmd) {
						# Script is not the same. Update the script command line.
						$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
						Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

						Write-Output "Updated post-job script for job '$($job.Name)'.`nOld: $postScriptCmd`nNew: $newPostScriptCmd"
						Write-Output "Job '$($job.Name)' is now configured for Discord notifications."
					}
					else {
						# Script hasn't changed. Notify user of this and continue.
						Write-Output "Job '$($job.Name)' is already configured for Discord notifications; Skipping."
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
			$setNewPostScript = Read-Host -Prompt "`nDo you wish to receive Discord notifications for job '$($job.Name)'? Y/N"
		}
		until ($setNewPostScript -eq 'Y' -or $setNewPostScript -eq 'N')

		Switch ($setNewPostScript) {
			# Default action will be to skip the job.
			default { Write-Output "Skipping job '$($job.Name)'`n"}
			Y {
				try {
					# Sets post-job script to Enabled and sets the command line to full command including path.
					$jobOptions.JobScriptCommand.PostScriptEnabled = $true
					$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
					Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

					Write-Output "Job '$($job.Name)' is now configured for Discord notifications."
				}
				catch {
					DeploymentError
				}
			}
		}
	}
}

Write-Output "`n`Finished. Exiting."
Start-Sleep 10
exit
