# Define parameters
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$true)]
	[string]$VbrHost,

	[Parameter]
	[uint16]$VbrPort = '9419',

	[Parameter(Mandatory=$true)]
	[string]$VbrUsername,

	[Parameter(Mandatory=$true)]
	[SecureString]$VbrPassword,

	[Parameter(Mandatory=$true)]
	[ValidatePattern('https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)')]
	[string]$Webook,

	[Parameter]
	[ValidatePattern('https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)')]
	[string]$Thumbnail = 'https://raw.githubusercontent.com/tigattack/VeeamDiscordNotifications/master/asset/thumb01.png',

	[Parameter]
	[uint64]$UserId,

	[Parameter]
	[ValidateSet('OnFail','OnWarn','Never','Always')]
	[string]$Mention = 'Never',

	[switch]$NoAutoUpdate = $false,

	[switch]$IgnoreSSL = $false,

	[switch]$Debug = $false
)

# Setup

# Get last check time
$time = Get-Date
try {
	$lastCheck = Get-Content $temp\lastcheck.txt -ErrorAction Stop
	# compare time?
	# kick off main to authenticate, get data, and send
}
catch {
	Write-Verbose 'Last check time not found; this is a clean start. Sleeping.'
	# sleep
	# restart script
}
