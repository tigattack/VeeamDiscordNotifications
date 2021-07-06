# Define parameters
[CmdletBinding()]
Param (
	[Parameter]
	[string]$VbrHost,
	[Parameter]
	[uint16]$VbrPort = '9419',
	[Parameter]
	[string]$VbrUsername,
	[Parameter]
	[SecureString]$VbrPassword,
	[Parameter]
	[string]$Webook,
	[Parameter]
	[string]$Thumbnail = 'https://raw.githubusercontent.com/tigattack/VeeamDiscordNotifications/master/asset/thumb01.png',
	[Parameter]
	[uint64]$UserId,
	[Parameter]
	[string]$Mention,
	[switch]$NoAutoUpdate = $false,
	[switch]$IgnoreSSL = $false,
	[switch]$Debug = $false
)

# Setup
## Enable TLS1.2
Write-Verbose 'Enabling TLS1.2'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

## Get temp directory and remove trailing slash
$temp = [IO.Path]::GetTempPath().TrimEnd('\/')

# Set paths
$UpdateCheckPath = "$temp\LastCheckUpdate.txt"
$SessionCheckPath = "$temp\LastCheckSession.txt"


# Determine versions and if an update is required
try {
	Write-Verbose 'Getting update status'
	$UpdateStatus = Get-VDNUpdateStatus
	Write-Verbose "Update status: $UpdateStatus"
}
catch {
	$errorMsg = "Failed to determine update status. Root cause: $($_.Exception.Message)"
	Write-Warning $errorMsg
}

# Write last update check time to file
try {
	Write-Verbose "Writing update check time to $UpdateCheckPath"
	Get-Date | Out-File -FilePath $UpdateCheckPath
}
catch {
	$errorMsg = "Failed to save update check time. Root cause: $($_.Exception.Message)"
	Write-Warning $errorMsg
}

# Authenticate with the VBR API to retrieve an access token
Write-Verbose 'Fetching VBR REST API token'
$token = Get-VbrApiToken -Server $VbrServer -Port $VbrPort -Username $VbrUsername -Password $VbrPassword -IgnoreSSL:$IgnoreSSL

# Get sessions
