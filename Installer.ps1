#Requires -RunAsAdministrator

# Prepare variables
$rootPath = 'C:\VeeamScripts'
$project = 'VeeamDiscordNotifications'
$webhookRegex = 'https:\/\/(.*\.)?discord(app)?\.com\/api\/webhooks\/([^\/]+)\/([^\/]+)'

# Get latest release from GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$versionParams = @{
	Uri = "https://github.com/tigattack/$project/releases/latest"
	Headers = @{'Accept'='application/json'}
	UseBasicParsing = $true
}
try {
	$latestVersion = ((Invoke-WebRequest @versionParams).Content | ConvertFrom-Json).tag_name
}
catch {
	$versionStatusCode = $_.Exception.Response.StatusCode.value__
	Write-Warning "Failed to query GitHub for the latest version. Please check your internet connection and try again.`nStatus code: $versionStatusCode"
	exit 1
}

# Check if this project is already installed and, if so, whether it's the latest version.
if (Test-Path $rootPath\$project) {
	$installedVersion = Get-Content -Raw "$rootPath\$project\resources\version.txt"
	If ($installedVersion -ge $latestVersion) {
		Write-Output "VeeamDiscordNotifications is already installed and up to date.`nExiting."
		Start-Sleep -Seconds 5
		exit
	}
	else {
		Write-Output "VeeamDiscordNotifications is already installed but it's out of date!"
		Write-Output "Please try the updater script in `"$rootPath\$project`" or download from https://github.com/tigattack/$project/releases."
	}
}

# Check user has webhook URL ready
do {
	$webhookPrompt = Read-Host -Prompt 'Do you have your Discord webhook URL ready? Y/N'
}
until ($webhookPrompt -in 'Y', 'N')

# Prompt user to create webhook first if not ready
If ($webhookPrompt -eq 'N') {
	Write-Output 'Please create a Discord webhook before continuing.'
	Write-Output 'Full instructions available at https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks'

	# Prompt user to launch URL
	$launchPrompt = Read-Host -Prompt 'Open URL? Y/N'
	If ($launchPrompt -eq 'Y') {
		Start-Process 'https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks'
	}

	exit
}

# Prompt user with config options
do {
	$webhookUrl = Read-Host -Prompt 'Please enter your Discord webhook URL'
	If ($webhookUrl -notmatch $webhookRegex) {
		Write-Output "`nInvalid webhook URL. Please try again."
	}
}
until ($webhookUrl -match $webhookRegex)

Write-Output "`nDo you wish to be mentioned in Discord when a job fails or finishes with warnings?"

do {
	$mentionPreference = Read-Host -Prompt "1 = No`n2 = On warn`n3 = On fail`n4 = On fail and on warn`nYour choice"
	If (1..4 -notcontains $mentionPreference) {
		Write-Output "`nInvalid choice. Please try again."
	}
}
until (1..4 -contains $mentionPreference)

If ($mentionPreference -ne 1) {
	do {
		try {
			[Int64]$userId = Read-Host -Prompt "`nPlease enter your Discord user ID"
		}
		catch [System.Management.Automation.ArgumentTransformationMetadataException] {
			Write-Output "`nInvalid user ID. Please try again."
		}
	}
	until ($userId.ToString().Length -gt 1)
}

# Pull latest version of script from GitHub
$DownloadParams = @{
	Uri = "https://github.com/tigattack/$project/releases/download/$latestVersion/$project-$latestVersion.zip"
	OutFile = "$env:TEMP\$project-$latestVersion.zip"
}
Try {
	Invoke-WebRequest @DownloadParams
}
catch {
	$downloadStatusCode = $_.Exception.Response.StatusCode.value__
	Write-Warning "Failed to download $project $latestVersion. Please check your internet connection and try again.`nStatus code: $downloadStatusCode"
	exit 1
}

# Unblock downloaded ZIP
try {
	Unblock-File -Path "$env:TEMP\$project-$latestVersion.zip"
}
catch {
	Write-Warning 'Failed to unblock downloaded files. You will need to run the following commands manually once installation is complete:'
	Write-Output "Unblock-File -Path $rootPath\$project\*.ps*"
	Write-Output "Unblock-File -Path $rootPath\$project\resources\*.ps*"
}

# Extract release to destination path
Expand-Archive -Path "$env:TEMP\$project-$latestVersion.zip" -DestinationPath "$rootPath"

# Rename destination and tidy up
Rename-Item -Path "$rootPath\$project-$latestVersion" -NewName "$project"
Remove-Item -Path "$env:TEMP\$project-$latestVersion.zip"

# Get config
$config = Get-Content "$rootPath\$project\config\conf.json" -Raw | ConvertFrom-Json
$config.webhook = $webhookUrl

Switch ($mentionPreference) {
	1 {
		$config.mention_on_fail = $false
		$config.mention_on_warning = $false
	}
	2 {
		$config.mention_on_fail = $false
		$config.mention_on_warning = $true
		$config.userId = $userId
	}
	3 {
		$config.mention_on_fail = $true
		$config.mention_on_warning = $false
		$config.userId = $userId
	}
	4 {
		$config.mention_on_fail = $true
		$config.mention_on_warning = $true
		$config.userId = $userId
	}
}

# Write config
Try {
	ConvertTo-Json $config | Set-Content "$rootPath\$project\config\conf.json"
}
catch {
	Write-Warning "Failed to write configuration file at `"$rootPath\$project\config\conf.json`". Please open the file and complete configuration manually."
}

Write-Output "Installation complete!`n"

# Run Post Script action.
& "$rootPath\$project\resources\DeployVeeamConfiguration.ps1"
