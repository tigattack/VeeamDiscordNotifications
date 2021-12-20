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

# Post-job script for Discord notifications
$newPostScriptCmd = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File C:\VeeamScripts\VeeamDiscordNotifications\Bootstrap.ps1'

# Import Veeam module
Import-Module Veeam.Backup.PowerShell -DisableNameChecking

# Get all supported jobs
$backupJobs = Get-VBRJob -WarningAction SilentlyContinue | Where-Object {
	$_.JobType -in 'Backup', 'Replica', 'EpAgentBackup'
}

# Make sure we found some jobs
if ($backupJobs.Count -eq 0) {
	Write-Output 'No supported jobs found; Exiting.'
	Start-Sleep 10
	exit
}
else {
	Write-Output "Found $($backupJobs.count) supported jobs:"
	Format-Table -InputObject $backupJobs -Property Name,@{Name='Type'; Expression={$_.TypeToString}} -AutoSize
}

# Query configure all or selected jobs
do {
	$configChoice = Read-Host -Prompt 'Do you wish to configure all supported jobs or make a choice for each job? A(ll)/S(elected)'
}
until ($configChoice -in 'A', 'All', 'S', 'Selected')

If ($configChoice -in 'S', 'Selected') {
	# Run foreach loop for all found backup jobs
	foreach ($job in $backupJobs) {
		# Set name string
		$jobName = "`"$($job.Name)`""

		# Get post-job script options for job
		$jobOptions = $job.GetOptions()
		$postScriptEnabled = $jobOptions.JobScriptCommand.PostScriptEnabled
		$postScriptCmd = $jobOptions.JobScriptCommand.PostScriptCommandLine

		# Check if job is already configured with correct post-job script
		if ($postScriptCmd.EndsWith('\Bootstrap.ps1') -or $postScriptCmd.EndsWith("\Bootstrap.ps1'")) {
			Write-Output "`n$($jobName) is already configured for Discord notifications; Skipping."
			Continue
		}
		elseif ($postScriptCmd.EndsWith('\DiscordNotificationBootstrap.ps1') -or $postScriptCmd.EndsWith("\DiscordNotificationBootstrap.ps1'")) {
			Write-Output "`n$($jobName) is configured for an older version of Discord notifications; Updating..."
			try {
				# Sets post-job script to Enabled and sets the command line to full command including path.
				$jobOptions.JobScriptCommand.PostScriptEnabled = $true
				$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
				Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

				Write-Output "$($jobName) is now updated."
			}
			catch {
				DeploymentError
			}
			Continue
		}

		# Different actions whether post-job script is already enabled. If yes we ask to modify it, if not we ask to enable & set it.
		if ($postScriptEnabled) {
			Write-Output "`n$($jobName) has an existing post-job script.`nScript: $postScriptCmd"
			Write-Output "`nIf you wish to receive Discord notifications for this job, you must overwrite the existing post-job script."

			do {
				$overWriteCurrentCmd = Read-Host -Prompt 'Do you wish to overwrite it? Y/N'
			}
			until ($overWriteCurrentCmd -in 'Y', 'N')

			switch ($overWriteCurrentCmd) {

				# Default action will be to skip the job.
				default { Write-Output "`nSkipping job $($jobName)`n"}
				Y {
					try {
						# Check to see if the script has even changed
						if ($postScriptCmd -ne $newPostScriptCmd) {

							# Script is not the same. Update the script command line.
							$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
							Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

							Write-Output "Updated post-job script for job $($jobName).`nOld: $postScriptCmd`nNew: $newPostScriptCmd"
							Write-Output "$($jobName) is now configured for Discord notifications."
						}
						else {
							# Script hasn't changed. Notify user of this and continue.
							Write-Output "$($jobName) is already configured for Discord notifications; Skipping."
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
				$setNewPostScript = Read-Host -Prompt "`nDo you wish to receive Discord notifications for $($jobName) ($($job.TypeToString))? Y/N"
			}
			until ($setNewPostScript -in 'Y', 'N')

			Switch ($setNewPostScript) {
				# Default action will be to skip the job.
				default { Write-Output "Skipping job $($jobName)"}
				Y {
					try {
						# Sets post-job script to Enabled and sets the command line to full command including path.
						$jobOptions.JobScriptCommand.PostScriptEnabled = $true
						$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
						Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

						Write-Output "`n$($jobName) is now configured for Discord notifications."
					}
					catch {
						DeploymentError
					}
				}
			}
		}
	}
}

elseif ($configChoice -in 'A', 'All') {
	# Run foreach loop for all found backup jobs
	foreach ($job in $backupJobs) {
		# Set name string
		$jobName = "`"$($job.Name)`""

		# Get post-job script options for job
		$jobOptions = $job.GetOptions()
		$postScriptEnabled = $jobOptions.JobScriptCommand.PostScriptEnabled
		$postScriptCmd = $jobOptions.JobScriptCommand.PostScriptCommandLine

		# Check if job is already configured with correct post-job script
		if ($postScriptCmd.EndsWith('\Bootstrap.ps1') -or $postScriptCmd.EndsWith("\Bootstrap.ps1'")) {
			Write-Output "`n$($jobName) is already configured for Discord notifications; Skipping."
			Continue
		}
		elseif ($postScriptCmd.EndsWith('\DiscordNotificationBootstrap.ps1') -or $postScriptCmd.EndsWith("\DiscordNotificationBootstrap.ps1'")) {
			Write-Output "`n$($jobName) is configured for an older version of Discord notifications; Updating..."
			try {
				# Sets post-job script to Enabled and sets the command line to full command including path.
				$jobOptions.JobScriptCommand.PostScriptEnabled = $true
				$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
				Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

				Write-Output "$($jobName) is now updated."
			}
			catch {
				DeploymentError
			}
			Continue
		}

		# Different actions whether post-job script is already enabled. If yes we ask to modify it, if not we ask to enable & set it.
		if ($postScriptEnabled) {
			Write-Output "`n$($jobName) has an existing post-job script.`nScript: $postScriptCmd"
			Write-Output "`nIf you wish to receive Discord notifications for this job, you must overwrite the existing post-job script."

			do {
				$overWriteCurrentCmd = Read-Host -Prompt 'Do you wish to overwrite it? Y/N'
			}
			until ($overWriteCurrentCmd -in 'Y', 'N')

			switch ($overWriteCurrentCmd) {

				# Default action will be to skip the job.
				default { Write-Output "`nSkipping job $($jobName)`n"}
				Y {
					try {
						# Check to see if the script has even changed
						if ($postScriptCmd -ne $newPostScriptCmd) {

							# Script is not the same. Update the script command line.
							$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
							Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

							Write-Output "Updated post-job script for job $($jobName).`nOld: $postScriptCmd`nNew: $newPostScriptCmd"
							Write-Output "$($jobName) is now configured for Discord notifications."
						}
						else {
							# Script hasn't changed. Notify user of this and continue.
							Write-Output "$($jobName) is already configured for Discord notifications; Skipping."
						}
					}
					catch {
						DeploymentError
					}
				}
			}
		}
		else {
			try {
				# Sets post-job script to Enabled and sets the command line to full command including path.
				$jobOptions.JobScriptCommand.PostScriptEnabled = $true
				$jobOptions.JobScriptCommand.PostScriptCommandLine = $newPostScriptCmd
				Set-VBRJobOptions -Job $job -Options $jobOptions | Out-Null

				Write-Output "`n$($jobName) is now configured for Discord notifications."
			}
			catch {
				DeploymentError
			}
		}
	}
}

Write-Output "`n`Finished. Exiting."
Start-Sleep 10
exit
