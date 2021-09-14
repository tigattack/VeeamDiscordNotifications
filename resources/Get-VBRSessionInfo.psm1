Function Get-VBRSessionInfo {
	param (
		[Parameter(Mandatory=$true)]$sessionId,
		[Parameter(Mandatory=$true)]$jobType
	)

	If (($null -ne $sessionId) -and ($null -ne $jobType)) {
		Switch ($jobType) {
			{$_ -eq 'VM'} {
				# Get the session details.
				$script:session = Get-VBRBackupSession | Where-Object {$_.Id.Guid -eq $sessionId}
				# Get the session's name.
				$script:jobName = $session.OrigJobName
			}
			{$_ -eq 'Agent'} {
				# Copy the job's name to it's own variable.
				$script:jobName = $job.Info.Name
				# Get the Veeam session.
				$script:session = Get-VBRComputerBackupJobSession -Id $sessionId
			}
		}
	}

	Elseif ($null -eq $sessionId) {
		Write-Warning '$sessionId is null.'
	}

	Elseif ($null -eq $jobType) {
		Write-Warning '$jobType is null.'
	}
}
