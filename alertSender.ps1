# Pull in variables from the DiscordNotificationBootstrap script
Param(
	[String]$jobName,
	[String]$id
)

# Import functions
Import-Module "$PSScriptRoot\resources\logger.psm1"
Import-Module "$PSScriptRoot\resources\ConvertTo-ByteUnit.psm1"

# Get config from your config file
$config = Get-Content -Raw "$PSScriptRoot\config\conf.json" | ConvertFrom-Json

# Start logging if logging is enabled in config
if($config.debug_log) {
	## Set log file name
	$date = (Get-Date -UFormat %Y-%m-%d_%T | ForEach-Object { $_ -replace ":", "." })
	$logFile = "$PSScriptRoot\log\Log_$jobName-$date.log"
	## Start logging to file
	Start-Logging $logFile
}

# Gather backup session info.
[String]$status = $session.Result
$jobName = $session.Name.ToString().Trim()
$JobType = $session.JobTypeString.Trim()
[Float]$jobSize = $session.BackupStats.DataSize
[Float]$transferSize = $session.BackupStats.BackupSize
[Float]$speed = $session.Info.Progress.AvgSpeed
$jobEndTime = $session.Info.EndTime
$jobStartTime = $session.Info.CreationTime

# Convert bytes to rounded units.
$jobSizeRound = ConvertTo-ByteUnit -InputObject $jobSize
$transferSizeRound = ConvertTo-ByteUnit -InputObject $transferSize
## Convert speed in B/s to rounded units and append '/s'
$speedRound = (ConvertTo-ByteUnit -InputObject $speed) + '/s'

# Write "Unknown" processing speed if 0B/s to avoid confusion.
If ($speedRound -eq '0 B/s') {
	$speedRound = 'Unknown.'
}

# Calculate difference between job start and end time.
$duration = $jobEndTime - $jobStartTime

# $jobEndTime and $jobStartTime are readonly. Create writeable object using their values, prepending 0 to single-digit values.
$jobTimes = [PSCustomObject]@{
	StartHour = $jobStartTime.Hour.ToString("00")
	StartMinute = $jobStartTime.Minute.ToString("00")
	StartSecond = $jobStartTime.Second.ToString("00")
	EndHour = $jobEndTime.Hour.ToString("00")
	EndMinute = $jobEndTime.Minute.ToString("00")
	EndSecond = $jobEndTime.Second.ToString("00")
}

# Switch for job duration.
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

# Switch for the session status to decide the embed colour.
Switch ($status) {
	None {$colour = '16777215'}
	Warning {$colour = '16776960'}
	Success {$colour = '65280'}
	Failed {$colour = '16711680'}
	Default {$colour = '16777215'}
}

# Create thumbnail object.
$thumbObject = [PSCustomObject]@{
	url = $config.thumbnail
}

# Create field objects and add to fieldArray.
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

# Build footer object.
$footerObject = [PSCustomObject]@{
	text = "tigattack's VeeamDiscordNotifications $currentVersion. $footerAddition"
	icon_url = 'https://avatars0.githubusercontent.com/u/10629864'
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

# Create payload
## Mention user on job failure if configured to do so.
If ($config.mention_on_fail -and $status -eq 'Failed') {
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
If ($currentVersion -lt $latestVersion -and $config.auto_update) {
	Copy-Item $PSScriptRoot\UpdateVeeamDiscordNotification.ps1 $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1
	Unblock-File $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1
	$powershellArguments = "-file $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1", "-LatestVersion $latestVersion"
	Start-Process -FilePath "powershell" -Verb runAs -ArgumentList $powershellArguments -WindowStyle hidden
}

# Stop logging.
if($config.debug_log) {
	Stop-Logging
}
