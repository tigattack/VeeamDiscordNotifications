# Function to convert raw byte values to the most applicable unit
function ConvertTo-ByteUnit {
	<#
	.Synopsis
	   Converts raw numbers to byte units.
	.DESCRIPTION
	   Converts raw numbers to byte units, dynamically deciding which unit (i.e. B, KB, MB, etc.) based on the number.
	.EXAMPLE
	   ConvertTo-ByteUnit -Data 1024
	.EXAMPLE
	   ConvertTo-ByteUnit -Data ((Get-ChildItem -Path ./ -Recurse | Measure-Object -Property Length -Sum).Sum)
	#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory)]
		[in64]$Data
	)

	process {
		switch ($Data) {
			{$_ -ge 1TB } {
				$Value = $Data / 1TB
				[String]$Value = [math]::Round($Value,2)
				$Value += ' TB'
				break
			}
			{$_ -ge 1GB } {
				$Value = $Data / 1GB
				[String]$Value = [math]::Round($Value,2)
				$Value += ' GB'
				break
			}
			{$_ -ge 1MB } {
				$Value = $Data / 1MB
				[String]$Value = [math]::Round($Value,2)
				$Value += ' MB'
				break
			}
			{$_ -ge 1KB } {
				$Value = $Data / 1KB
				[String]$Value = [math]::Round($Value,2)
				$Value += ' GB'
				break
			}
			default {
				$Value = $Data
				break
			}
		}
		Write-Output $Value
	}
}

# Function to determine if the prpject is up to date
function Get-VDNUpdateStatus {
	# Get currently downloaded version of this project.
	$currentVersion = Get-Content (Join-Path -Path $PSScriptRoot -ChildPath version.txt) -Raw

	# Fetch latest release from GitHub and parse the tag.
	$latestVersion = (Invoke-RestMethod -Uri https://api.github.com/repos/tigattack/VeeamDiscordNotifications/releases/latest).tag_name

	# Compare current and latest versions to determine if an update is required.
	## Out of date
	If ($currentVersion -lt $latestVersion) {
		$updateAvailable = $true
		$prerelease = $false
	}

	## Up to date
	Elseif ($currentVersion -eq $latestVersion) {
		$updateAvailable = $false
		$prerelease = $false
	}

	# Prerelease
	Elseif ($currentVersion -gt $latestVersion) {
		$updateAvailable = $false
		$prerelease = $true
	}

	# Return status object
	New-Object PSObject -Property @{
		UpdateAvailable = $updateAvailable
		CurrentVersion = $currentVersion
		LatestVersion = $latestVersion
		Prerelease = $prerelease
	}
}

# Function to authenticate with the VBR REST API
function Get-VbrApiToken {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[string]$Server,

		[uint16]$Port = '9419',

		[Parameter(Mandatory=$true)]
		[string]$Username,

		[Parameter(Mandatory=$true)]
		[SecureString]$Password,

		[switch]$IgnoreSSL

	)

	# Prepare headers
	$headers = @{
		"x-api-version" = "1.0-rev1"
	}

	# Prepare body
	$body = @{
		grant_type = 'password'
		username = $Username
		password = $Password
	}

	# Send authentication request
	try {
		$response = Invoke-WebRequest -Uri "https://${Server}:${Port}/api/oauth2/token" -Method 'POST' -Headers $headers -Body $body -ContentType 'application/x-www-form-urlencoded' -SkipCertificateCheck:$IgnoreSSL
		($response.Content | ConvertFrom-Json).access_token
	}
	catch {
		$errorMsg = "Failed to authenticate with REST API. $($_.Exception.Message)"
		Throw $errorMsg
	}

}

