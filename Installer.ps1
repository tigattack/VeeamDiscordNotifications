#Requires -RunAsAdministrator

# Prepare variables
$rootPath = 'C:\VeeamScripts'
$project = 'VeeamDiscordNotifications'
$webhookRegex = 'https:\/\/(.*\.)?discord(app)?\.com\/api\/webhooks\/([^\/]+)\/([^\/]+)'

# Get latest release from GitHub
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$latestVersion = ((Invoke-WebRequest -Uri "https://github.com/tigattack/$project/releases/latest" `
			-Headers @{'Accept'='application/json'} -UseBasicParsing).Content | ConvertFrom-Json).tag_name

# Check if this project is already installed and, if so, whether it's the latest version.
if (Test-Path $rootPath\$project) {
	Write-Output 'VeeamDiscordNotifications is already installed; Checking version.'
	$installedVersion = Get-Content -Raw "$rootPath\$project\resources\version.txt"
	If ($installedVersion -ge $latestVersion) {
		Write-Output "VeeamDiscordNotifications is already up to date.`nExiting."
		exit
	}
}

# Check user has webhook URL ready
$userPrompt = Read-Host -Prompt 'Do you have your Discord webhook URL ready? Y/N'

# Prompt user to create webhook first if not ready
If ($userPrompt -ne 'Y') {
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
Invoke-WebRequest -Uri "https://github.com/tigattack/$project/archive/refs/heads/master.zip" `
	-OutFile "$env:TEMP\$project-master.zip"

# Unblock downloaded ZIP
Unblock-File -Path "$env:TEMP\$project-master.zip"

# Extract release to destination path
Expand-Archive -Path "$env:TEMP\$project-master.zip" -DestinationPath "$rootPath"

# Rename destination and tidy up
Rename-Item -Path "$rootPath\$project-master" -NewName "$rootPath\$project"
Remove-Item -Path "$env:TEMP\$project-master.zip"

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
ConvertTo-Json $config | Set-Content "$rootPath\$project\config\conf.json"

# Run Post Script action.
& "$rootPath\$project\resources\DeployVeeamConfiguration.ps1"
