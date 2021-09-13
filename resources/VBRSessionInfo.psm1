Function Get-VBRSessionInfo {
	param (
		[Parameter(Mandatory=$true)]$SessionId,
		[Parameter(Mandatory=$true)]$JobType
	)

	# Import VBR module
	Import-Module Veeam.Backup.PowerShell -DisableNameChecking

	If (($null -ne $SessionId) -and ($null -ne $JobType)) {

		# Switch on job type.
		Switch ($JobType) {

			# VM job
			{$_ -eq 'Backup'} {

				# Get the session details.
				$session = Get-VBRBackupSession | Where-Object {$_.Id.Guid -eq $SessionId}

				# Get the job's name from the session details.
				$jobName = $session.OrigJobName
			}

			# Agent job
			{$_ -eq 'EpAgentBackup'} {
				# Get the session details.
				$session = Get-VBRComputerBackupJobSession -Id $SessionId

				$session = [Veeam.Backup.Core.CBackupSession]::GetByOriginalSessionId($SessionId)
				$jobName = ($session.JobName | Select-String -Pattern '^(.+)(-.+)$').Matches.Groups[1].Value

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

	Elseif ($null -eq $SessionId) {
		Write-Warning '$SessionId is null.'
	}

	Elseif ($null -eq $JobType) {
		Write-Warning '$JobType is null.'
	}
}
