function Get-UpdateStatus {

	process {
		# Get currently downloaded version of this project.
		$currentVersion = (Get-Content "$PSScriptRoot\version.txt" -Raw).Trim()

		# Get all releases from GitHub.
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		try {
			$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/tigattack/$project/releases" -Method Get
		}
		catch {
			$versionStatusCode = $_.Exception.Response.StatusCode.value__
			Write-LogMessage -Tag 'ERROR' -Message "Failed to query GitHub for the latest version. Please check your internet connection and try again. Status code: $versionStatusCode"
			exit 1
		}

		# Get latest stable
		foreach ($i in $releases) {
			if (-not $i.prerelease) {
				$latestVersion = $i.tag_name
				break
			}
		}

		# Set version status
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
