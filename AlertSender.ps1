# Define parameters
Param(
	[String]$jobName,
	[String]$id,
	[String]$jobType
)

# Import modules.
Import-Module "$PSScriptRoot\resources\Logger.psm1"
Import-Module "$PSScriptRoot\resources\ConvertTo-ByteUnit.psm1"
Import-Module "$PSScriptRoot\resources\VBRSessionInfo.psm1"
Import-Module "$PSScriptRoot\resources\UpdateInfo.psm1"

# Get config from file
$config = Get-Content -Raw "$PSScriptRoot\config\conf.json" | ConvertFrom-Json

# Start logging if logging is enabled in config
if($config.debug_log) {
	## Set log file name
	$date = (Get-Date -UFormat %Y-%m-%d_%T | ForEach-Object { $_ -replace ":", "." })
	$logFile = "$PSScriptRoot\log\Log_$jobName-$date.log"
	## Start logging to file
	Start-Logging $logFile
}


# Determine if an update is required
$updateStatus = Get-UpdateStatus


# Define static output objects.

## Get and define update status message.
$footerAddition = Get-UpdateMessage -CurrentVersion $updateStatus.CurrentVersion -LatestVersion $updateStatus.LatestVersion

## Define thumbnail object.
$thumbObject = [PSCustomObject]@{
	url = $config.thumbnail
}

## Define footer object.
$footerObject = [PSCustomObject]@{
	text = "tigattack's VeeamDiscordNotifications $($updateStatus.CurrentVersion). $footerAddition"
	icon_url = 'https://avatars0.githubusercontent.com/u/10629864'
}


# Job info preparation

## Get the backup session information.
$session = (Get-VBRSessionInfo -SessionID $id -JobType $jobType).Session

## Wait for the backup session to finish.
While ($session.State -ne 'Stopped') {
	Write-LogMessage -Tag 'Info' -Message 'Session not finished. Sleeping...'
	Start-Sleep -Milliseconds 500
	$session = (Get-VBRSessionInfo -SessionID $id -JobType $jobType).Session
}

## Gather generic session info
[String]$status = $session.Result
$jobEndTime = $session.Info.EndTime
$jobStartTime = $session.Info.CreationTime

## Create writeable object using their values, prepending 0 to single-digit values.
## Necessary because $jobEndTime and $jobStartTime are readonly.
$jobTimes = [PSCustomObject]@{
	StartHour = $jobStartTime.Hour.ToString("00")
	StartMinute = $jobStartTime.Minute.ToString("00")
	StartSecond = $jobStartTime.Second.ToString("00")
	EndHour = $jobEndTime.Hour.ToString("00")
	EndMinute = $jobEndTime.Minute.ToString("00")
	EndSecond = $jobEndTime.Second.ToString("00")
}

## Calculate difference between job start and end time.
$duration = $jobEndTime - $jobStartTime

## Switch for job duration; define pretty output.
Switch ($duration) {
	{$_.Days -ge '1'} {
		$durationFormatted = '{0}d {1}h {2}m {3}s' -f $_.Days, $_.Hours, $_.Minutes, $_.Seconds
		break
	}
	{$_.Hours -ge '1'} {
		$durationFormatted = '{0}h {1}m {2}s' -f $_.Hours, $_.Minutes, $_.Seconds
		break
	}
	{$_.Minutes -ge '1'} {
		$durationFormatted = '{0}m {1}s' -f $_.Minutes, $_.Seconds
		break
	}
	{$_.Seconds -ge '1'} {
		$durationFormatted = '{0}s' -f $_.Seconds
		break
	}
	Default {
		$durationFormatted = '{0}d {1}h {2}m {3}s' -f $_.Days, $_.Hours, $_.Minutes, $_.Seconds
	}
}

## Initialise fieldArray variable.
$fieldArray = @()


# Define session statistics for the report.

## If VM backup, gather and include session info
if ($jobType -eq 'VM') {
	# Gather session info.
	[Float]$jobSize = $session.BackupStats.DataSize
	[Float]$transferSize = $session.BackupStats.BackupSize
	[Float]$speed = $session.Info.Progress.AvgSpeed

	# Convert bytes to rounded units.
	$jobSizeRound = ConvertTo-ByteUnit -InputObject $jobSize
	$transferSizeRound = ConvertTo-ByteUnit -InputObject $transferSize
	# Convert speed from B/s to rounded units and append '/s'
	$speedRound = (ConvertTo-ByteUnit -InputObject $speed) + '/s'

	# Set processing speed  "Unknown" if 0B/s to avoid confusion.
	If ($speedRound -eq '0 B/s') {
		$speedRound = 'Unknown'
	}

	# Add session information to fieldArray.
	$fieldArray = @(
		[PSCustomObject]@{
			name = 'Backup Size'
			value = [String]$jobSizeRound
			inline = 'true'
		},
		[PSCustomObject]@{
			name = 'Transferred Data'
			value = [String]$transferSizeRound
			inline = 'true'
		}
		[PSCustomObject]@{
			name = 'Dedup Ratio'
			value = [String]$session.BackupStats.DedupRatio
			inline = 'false'
		}
		[PSCustomObject]@{
			name = 'Compression Ratio'
			value = [String]$session.BackupStats.CompressRatio
			inline = 'false'
		}
		[PSCustomObject]@{
			name = 'Processing Rate'
			value = $speedRound
			inline = 'false'
		}
	)
}

## Add job times to fieldArray.
$fieldArray += @(
	[PSCustomObject]@{
		name = 'Job Duration'
		value = $durationFormatted
		inline = 'true'
	}
	[PSCustomObject]@{
		name = 'Time Started'
		value = '{0}:{1}:{2}' -f $jobTimes.StartHour, $jobTimes.StartMinute, $jobTimes.StartSecond
		inline = 'true'
	}
	[PSCustomObject]@{
		name = 'Time Completed'
		value = '{0}:{1}:{2}' -f $jobTimes.EndHour, $jobTimes.EndMinute, $jobTimes.EndSecond
		inline = 'true'
	}
)

# If agent backup, add notice to fieldArray.
If ($jobType -eq 'Agent') {
	$fieldArray += @(
		[PSCustomObject]@{
			name = 'Notice'
			value = "Due to limitations in Veeam's PowerShell module, this information is unfortunately all that can be provided."
			inline = 'false'
		}
	)
}

# Switch for the session status to decide the embed colour.
Switch ($status) {
	None {$colour = '16777215'}
	Warning {$colour = '16776960'}
	Success {$colour = '65280'}
	Failed {$colour = '16711680'}
	Default {$colour = '16777215'}
}

# Build embed object.
$embedArray = @(
	[PSCustomObject]@{
		title		= $jobName
		description	= $status
		color		= $colour
		thumbnail	= $thumbObject
		fields		= $fieldArray
		footer		= $footerObject
	}
)

# Decide whether to mention user
If (($config.mention_on_fail -and $Status -eq 'Failed') -or ($config.mention_on_warning -and $Status -eq 'Warning')) {
	$mention = $true
}

# Create payload object.
## Mention user on job failure if configured to do so.
If ($mention) {
	$payload = [PSCustomObject]@{
		content = "<@!$($config.userid)> Job status $status"
		embeds	= $embedArray
	}
}

## Otherwise do not mention user.
Else {
	$payload = [PSCustomObject]@{
		embeds	= $embedArray
	}
}


# Send iiiit.
$request = Invoke-RestMethod -Uri $config.webhook -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'

# Write error if message fails to send to Discord.
If ($request.Length -gt '0') {
	Write-LogMessage -Tag 'Error' -Message 'Failed to send message to Discord. Response below.'
	Write-LogMessage -Tag 'Error' -Message "$request"
}


# Trigger update if there's a newer version available.
If (($updateStatus.CurrentVersion -lt $updateStatus.latestVersion) -and $config.auto_update) {
	# Copy update script out of working directory.
	Copy-Item $PSScriptRoot\Updater.ps1 $PSScriptRoot\..\VDNotifs-Updater.ps1
	Unblock-File $PSScriptRoot\..\VDNotifs-Updater.ps1

	# Run update script.
	$updateArgs = "-file $PSScriptRoot\..\VDNotifs-Updater.ps1", "-LatestVersion $latestVersion"
	Start-Process -FilePath "powershell" -Verb runAs -ArgumentList $updateArgs -WindowStyle hidden
}

# Stop logging.
if($config.debug_log) {
	Stop-Logging
}