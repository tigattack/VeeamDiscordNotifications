# This function logs messages with a type tag
Function Write-LogMessage {
	[CmdletBinding(
		SupportsShouldProcess,
		ConfirmImpact = 'Low'
	)]
	Param (
		$tag,
		$message
	)
	If ($PSCmdlet.ShouldProcess('Output stream', 'Write log message')) {
		Write-Output "[$tag] $message"
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
		$path
	)
	If ($PSCmdlet.ShouldProcess($path, 'Start-Transcript')) {
		Try {
			Start-Transcript -Path $path -Force -Append
			Write-LogMessage -Tag 'Info' -Message "Transcript is being logged to $path"
		}
		Catch [Exception] {
			Write-LogMessage -Tag 'Info' -Message "Transcript is already being logged to $path"
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
		Write-LogMessage -Tag 'Info' -Message 'Stopping transcript logging.'
		Stop-Transcript
	}
}
