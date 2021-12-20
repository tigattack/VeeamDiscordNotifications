function Get-UpdateStatus {

	process {
		# Get currently downloaded version of this project.
		$currentVersion = (Get-Content "$PSScriptRoot\version.txt" -Raw).Replace("`n",'')

		# Get latest release from GitHub.
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		$latestRelease = Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/latest `
			-Headers @{'Accept'='application/json'} -UseBasicParsing

		# Release IDs are returned in a format of {"id":3622206,"tag_name":"v1.0"}, so we need to extract tag_name.
		$latestVersion = ConvertFrom-Json $latestRelease.Content | ForEach-Object {$_.tag_name}

		If ($currentVersion -gt $latestVersion) {
			$status = 'Ahead'
		}
		elseif ($currentVersion -lt $latestVersion) {
			$status = 'Behind'
		}
		else {
			$status = 'Current'
		}

		# Create PSObject to return.
		$out = New-Object PSObject -Property @{
			CurrentVersion 	= $currentVersion
			LatestVersion 	= $latestVersion
			Status 			= $status
		}

		# Return PSObject.
		return $out
	}
}
