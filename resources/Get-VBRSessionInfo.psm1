Function Get-VBRSessionInfo {
	param (
		[Parameter(Mandatory=$true)]$sessionId,
		[Parameter(Mandatory=$true)]$jobType
	)

	# Import VBR module
	Import-Module Veeam.Backup.PowerShell

	If (($null -ne $sessionId) -and ($null -ne $jobType)) {

		# Switch on job type.
		Switch ($jobType) {
			{$_ -eq 'VM'} {

				# Get the session details.
				$session = Get-VBRBackupSession | Where-Object {$_.Id.Guid -eq $sessionId}

				# Get the job's name from the session details.
				$jobName = $session.OrigJobName
			}

			{$_ -eq 'Agent'} {
				# Get the session details.
				$session = Get-VBRComputerBackupJobSession -Id $sessionId

				# Copy the job's name to it's own variable.
				$jobName = $job.Info.Name
			}
		}

		# Create PSObject to return.
		New-Object PSObject -Property @{
			Session = $session
			JobName = $jobName
		}
	}

	Elseif ($null -eq $sessionId) {
		Write-Warning '$sessionId is null.'
	}

	Elseif ($null -eq $jobType) {
		Write-Warning '$jobType is null.'
	}
}
