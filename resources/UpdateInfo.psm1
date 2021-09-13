function Get-UpdateStatus {

	process {
		# Get currently downloaded version of this project.
		$currentVersion = Get-Content "$PSScriptRoot\version.txt" -Raw

		# Get latest release from GitHub.
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		$latestRelease = Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/latest `
			-Headers @{'Accept'='application/json'} -UseBasicParsing

		# Release IDs are returned in a format of {"id":3622206,"tag_name":"v1.0"}, so we need to extract tag_name.
		$latestVersion = ConvertFrom-Json $latestRelease.Content | ForEach-Object {$_.tag_name}

		# Create PSObject to return.
		New-Object PSObject -Property @{
			CurrentVersion = $currentVersion
			LatestVersion = $latestVersion
		}
	}
}

function Get-UpdateMessage {
	Param (
		[Parameter(Mandatory)]
		$CurrentVersion,
		[Parameter(Mandatory)]
		$LatestVersion
	)

	process {

		# Get version announcement phrases.
		$phrases = Get-Content -Raw "$PSScriptRoot\VersionPhrases.json" | ConvertFrom-Json

		# Comparing local and latest versions and determine if an update is required, then use that information to build the footer text.
		# Picks a phrase at random from the list above for the version statement in the footer of the backup report.
		Switch ($CurrentVersion) {
			{$_ -lt $LatestVersion} {
				$updateMessage = (Get-Random -InputObject $phrases.older -Count 1)
			}

			{$_ -eq $LatestVersion} {
				$updateMessage = (Get-Random -InputObject $phrases.current -Count 1)
			}

			{$_ -gt $LatestVersion} {
				$updateMessage = (Get-Random -InputObject $phrases.newer -Count 1)
			}
		}

		# Return update message.
		$updateMessage
	}
}
