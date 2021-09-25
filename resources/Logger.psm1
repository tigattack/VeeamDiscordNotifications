# This function logs messages with a type tag
Function Write-LogMessage {
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = 'Low'
	)]
	Param (
		$Tag,
		$Message
	)
	If ($PSCmdlet.ShouldProcess('Output stream', 'Write log message')) {
		Write-Output "[$($Tag.ToUpper())] $Message"
	}
}

# These functions handles Logging
Function Start-Logging {
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = 'Low'
	)]
	Param(
		[Parameter(Mandatory)]
		$Path
	)
	If ($PSCmdlet.ShouldProcess($Path, 'Start-Transcript')) {
		Try {
			Start-Transcript -Path $Path -Force -Append
			Write-LogMessage -Tag 'INFO' -Message "Transcript is being logged to $Path"
		}
		Catch [Exception] {
			Write-LogMessage -Tag 'INFO' -Message "Transcript is already being logged to $Path"
		}
	}
}
Function Stop-Logging {
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = 'Low'
	)]
	Param()
	If ($PSCmdlet.ShouldProcess('log file', 'Stop-Transcript')) {
		Write-LogMessage -Tag 'INFO' -Message 'Stopping transcript logging.'
		Stop-Transcript
	}
}
