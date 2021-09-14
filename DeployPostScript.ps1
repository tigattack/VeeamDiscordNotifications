# Gets Name of all Jobs
$AllJobs = Get-VBRJob -ea silentlyContinue -WarningAction silentlyContinue | Select-Object -ExpandProperty Name

# Make sure we actually have jobs we can run this on.
if ([string]::IsNullOrEmpty($AllJobs)) {
	Write-Output 'No Jobs found to set Post Script for.'
	Start-Sleep 10
	exit
}
# Command that Veeam needs to use for the Post Script action.
$VeeamPowershellCommand = 'Powershell.exe -File C:\VeeamScripts\VeeamDiscordNotifications\Bootstrap.ps1'

# Run foreach loop for all found jobs
foreach ($JobName in $AllJobs) {
	$Job = Get-VBRJob -Name $JobName -ea silentlyContinue -WarningAction silentlyContinue
	# Get all required options/parameters for specific job
	$JobOptions = $Job.GetOptions()
	$JobScriptCommand = $JobOptions.JobScriptCommand
	$PostScriptEnabled = $JobScriptCommand.PostScriptEnabled
	$PostScriptCommandLine = $JobScriptCommand.PostScriptCommandLine
	# Different actions whether Post Script is already enabled. If yes we ask to modify it, if not we ask to enable & set it.
	if ($PostScriptEnabled -eq 'True') {
		$OverWriteCurrentCL = Read-Host "`nThere is already a Post Script set for $JobName`nScript: $PostScriptCommandLine`nDo you want to overwrite it? Y/N"
		switch ($OverWriteCurrentCL) {
			# Default action will be to skip the job.
			default { Write-Output "Skipping Job $JobName"}
			Y {
				try {
					# Small check to see if the script has even changed
					if ($PostScriptCommandLine -ne $VeeamPowershellCommand) {
						# Script is not the same. Update the script command line.
						$JobOptions.JobScriptCommand.PostScriptCommandLine = $VeeamPowershellCommand
						Set-VBRJobOptions $JobName $JobOptions | Out-Null
						Write-Output "Updated Post Script for Job $JobName from '$PostScriptCommandLine' to '$VeeamPowershellCommand'"
					}
					else {
						# Script hasn't changed. Notify user of this and continue.
						Write-Output "Post Script content hasn't changed. Not modifying."
					}
				}
				catch {
					# Catch exceptions.
					Write-Output "An error occured: $_.ScriptStackTrace"
				}
			}
			# Allow user to skip jobs they have incase there's already other post-scripts configured.
			N { Write-Output "Skipping Job: $JobName"}
		}
	}
	else {
		$SetNewPostScript = Read-Host "`nThere is no Post Script for $JobName. Do you want to add a new one? Y/N"
		Switch ($SetNewPostScript) {
			# Default action will be to skip the job.
			default { Write-Output "Skipping Job $JobName"}
			Y {
				try {
					# Sets Post Script to Enabled and sets the command line to full command including path.
					$JobOptions.JobScriptCommand.PostScriptEnabled = $True
					$JobOptions.JobScriptCommand.PostScriptCommandLine = $VeeamPowershellCommand
					Set-VBRJobOptions $JobName $JobOptions | Out-Null
					Write-Output "Added Post Script for Job $JobName"
				}
				catch {
					# Catch exceptions.
					Write-Output "An error occured: $_.ScriptStackTrace"
				}
			}
			# Allow user to skip job if they don't want to monitor a specific one.
			N { Write-Output "Skipping Job: $JobName"}
		}
	}
}
Write-Output "`r`n`r`nAll Jobs Configured. Exiting."
Start-Sleep 5
exit
