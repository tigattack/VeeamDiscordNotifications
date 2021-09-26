# Define parameters
Param(
	[String]$jobName,
	[String]$id,
	[String]$jobType,
	$Config
)

# Convert config from JSON
$Config = $Config | ConvertFrom-Json

# Import modules.
Import-Module Veeam.Backup.PowerShell -DisableNameChecking
Import-Module "$PSScriptRoot\resources\Logger.psm1"
Import-Module "$PSScriptRoot\resources\ConvertTo-ByteUnit.psm1"
Import-Module "$PSScriptRoot\resources\VBRSessionInfo.psm1"
Import-Module "$PSScriptRoot\resources\UpdateInfo.psm1"


# Start logging if logging is enabled in config
If ($Config.debug_log) {
	## Replace spaces if any in the job name
	If ($jobName -match ' ') {
		$logJobName = $jobName.Replace(' ', '_')
	}
	Else {
		$logJobName = $jobName
	}
	## Set log file name
	$date = (Get-Date -UFormat %Y-%m-%d_%T).Replace(':','.')
	$logFile = "$PSScriptRoot\log\Log_$($logJobName)_$date.log"
	## Start logging to file
	Start-Logging $logFile
}


# Initialise some variables.
$fieldArray = @()
$mention = $false


# Determine if an update is required
$updateStatus = Get-UpdateStatus


# Define static output objects.

## Get and define update status message.
$footerAddition = (Get-UpdateMessage -CurrentVersion $updateStatus.CurrentVersion -LatestVersion $updateStatus.LatestVersion) `
	-replace 'latestVerPlaceholder', $updateStatus.LatestVersion

## Define thumbnail object.
$thumbObject = [PSCustomObject]@{
	url = $Config.thumbnail
}

## Define footer object.
$footerObject = [PSCustomObject]@{
	text 		= "tigattack's VeeamDiscordNotifications $($updateStatus.CurrentVersion). $footerAddition"
	icon_url	= 'https://avatars0.githubusercontent.com/u/10629864'
}


# Job info preparation

## Get the backup session information.
$session = (Get-VBRSessionInfo -SessionId $id -JobType $jobType).Session

## Wait for the backup session to finish.
While ($session.State -ne 'Stopped') {
	Write-LogMessage -Tag 'INFO' -Message 'Session not finished. Sleeping...'
	Start-Sleep -Milliseconds 500
	$session = (Get-VBRSessionInfo -SessionId $id -JobType $jobType).Session
}

## Gather generic session info.
[String]$status = $session.Result


# Define session statistics for the report.

## If VM backup, gather and include session info.
if ($jobType -eq 'Backup') {
	# Gather session data sizes and timing.
	[Float]$jobSize			= $session.BackupStats.DataSize
	[Float]$transferSize	= $session.BackupStats.BackupSize
	[Float]$speed			= $session.Info.Progress.AvgSpeed
	$jobEndTime 			= $session.Info.EndTime
	$jobStartTime 			= $session.Info.CreationTime

	# Convert bytes to closest unit.
	$jobSizeRound		= ConvertTo-ByteUnit -Data $jobSize
	$transferSizeRound	= ConvertTo-ByteUnit -Data $transferSize
	$speedRound			= (ConvertTo-ByteUnit -Data $speed) + '/s'

	# Set processing speed "Unknown" if 0B/s to avoid confusion.
	If ($speedRound -eq '0 B/s') {
		$speedRound = 'Unknown'
	}

	# Get objects in session.
	$sessionObjects = $session.GetTaskSessions()

	## Count total
	$sessionObjectsCount = $sessionObjects.Count

	## Count warns and fails
	$sessionObjectWarns = 0
	$sessionObjectFails = 0

	foreach ($object in $sessionObjects) {
		If ($object.Status -eq 'Warning') {
			$sessionObjectWarns++
		}
		# TODO: check if 'Failed' is a valid state.
		If ($object.Status -eq 'Failed') {
			$sessionObjectFails++
		}
	}

	# Add session information to fieldArray.
	$fieldArray = @(
		[PSCustomObject]@{
			name	= 'Backup Size'
			value	= [String]$jobSizeRound
			inline	= 'true'
		},
		[PSCustomObject]@{
			name	= 'Transferred Data'
			value	= [String]$transferSizeRound
			inline	= 'true'
		}
		[PSCustomObject]@{
			name	= 'Dedup Ratio'
			value	= [String]$session.BackupStats.DedupRatio
			inline	= 'true'
		}
		[PSCustomObject]@{
			name	= 'Compression Ratio'
			value	= [String]$session.BackupStats.CompressRatio
			inline	= 'true'
		}
		[PSCustomObject]@{
			name	= 'Processing Rate'
			value	= $speedRound
			inline	= 'true'
		}
		[PSCustomObject]@{
			name	= 'Bottleneck'
			value	= [String]$session.Info.Progress.BottleneckInfo.Bottleneck
			inline	= 'true'
		}
	)

	# Add object warns/fails to fieldArray if any.
	If ($sessionObjectWarns -gt 0) {
		$fieldArray += @(
			[PSCustomObject]@{
				name	= 'Warnings'
				value	= "$sessionObjectWarns/$sessionobjectsCount"
				inline	= 'true'
			}
		)
	}
	If ($sessionObjectFails -gt 0) {
		$fieldArray += @(
			[PSCustomObject]@{
				name	= 'Fails'
				value	= "$sessionObjectFails/$sessionobjectsCount"
				inline	= 'true'
			}
		)
	}
}

# If agent backup, gather and include session info.
If ($jobType -eq 'EpAgentBackup') {
	# Gather session data sizes and timings.
	[Float]$jobProcessedSize	= $session.Info.Progress.ProcessedSize
	[Float]$jobTransferredSize	= $session.Info.Progress.TransferedSize
	[Float]$speed				= $session.Info.Progress.AvgSpeed
	$jobEndTime 				= $session.EndTime
	$jobStartTime 				= $session.CreationTime

	# Convert bytes to closest unit.
	$jobProcessedSizeRound		= ConvertTo-ByteUnit -Data $jobProcessedSize
	$jobTransferredSizeRound	= ConvertTo-ByteUnit -Data $jobTransferredSize
	$speedRound					= (ConvertTo-ByteUnit -Data $speed) + '/s'

	# Get number of objects in job.
	$jobObjects = (Get-VBRComputerBackupJob -Name "$jobName").BackupObject

	# Initialise job object count variable.
	$jobObjectCount = 0

	# Determine if object is individual computer or container.
	foreach ($i in 0..($jobObjects.Count-1)) {
		# Switch on object type.
		Switch ($jobObjects[$i].GetType()) {
			# Individual computer
			'VBRIndividualComputer' {
				$jobObjectCount++
			}
			# Protection group
			'VBRProtectionGroup' {
				$jobObjectCount = $jobObjectsCount+$objects[$i].Container.Entity.Count
			}
		}
	}

	# Add session information to fieldArray.
	$fieldArray = @(
		[PSCustomObject]@{
			name	= 'Processed Size'
			value	= [String]$jobProcessedSizeRound
			inline	= 'true'
		},
		[PSCustomObject]@{
			name	= 'Transferred Data'
			value	= [String]$jobTransferredSizeRound
			inline	= 'true'
		},
		[PSCustomObject]@{
			name	= 'Processing Rate'
			value	= $speedRound
			inline	= 'true'
		},
		[PSCustomObject]@{
			name	= 'Objects'
			value	= "$jobObjectCount"
			inline	= 'true'
		}
	)
}


# Job timings

## Create array of job timings.
# Necessary because $jobEndTime and $jobStartTime are readonly.
# Create writeable object using their values, prepending 0 to single-digit values.
$jobTimes = [PSCustomObject]@{
	StartHour	= $jobStartTime.Hour.ToString('00')
	StartMinute	= $jobStartTime.Minute.ToString('00')
	StartSecond	= $jobStartTime.Second.ToString('00')
	EndHour		= $jobEndTime.Hour.ToString('00')
	EndMinute	= $jobEndTime.Minute.ToString('00')
	EndSecond	= $jobEndTime.Second.ToString('00')
}

# Calculate difference between job start and end time.
$duration = $jobEndTime - $jobStartTime

## Switch for job duration; define pretty output.
Switch ($duration) {
	{$_.Days -ge '1'} {
		$durationFormatted	= '{0}d {1}h {2}m {3}s' -f $_.Days, $_.Hours, $_.Minutes, $_.Seconds
		break
	}
	{$_.Hours -ge '1'} {
		$durationFormatted	= '{0}h {1}m {2}s' -f $_.Hours, $_.Minutes, $_.Seconds
		break
	}
	{$_.Minutes -ge '1'} {
		$durationFormatted	= '{0}m {1}s' -f $_.Minutes, $_.Seconds
		break
	}
	{$_.Seconds -ge '1'} {
		$durationFormatted	= '{0}s' -f $_.Seconds
		break
	}
	Default {
		$durationFormatted	= '{0}d {1}h {2}m {3}s' -f $_.Days, $_.Hours, $_.Minutes, $_.Seconds
	}
}


## Add job times to fieldArray.
$fieldArray += @(
	[PSCustomObject]@{
		name	= 'Job Duration'
		value	= $durationFormatted
		inline	= 'true'
	}
	[PSCustomObject]@{
		name	= 'Time Started'
		value	= '{0}:{1}:{2}' -f $jobTimes.StartHour, $jobTimes.StartMinute, $jobTimes.StartSecond
		inline	= 'true'
	}
	[PSCustomObject]@{
		name	= 'Time Ended'
		value	= '{0}:{1}:{2}' -f $jobTimes.EndHour, $jobTimes.EndMinute, $jobTimes.EndSecond
		inline	= 'true'
	}
)


# If agent backup, add notice to fieldArray.
If ($jobType -eq 'EpAgentBackup') {
	$fieldArray += @(
		[PSCustomObject]@{
			name = 'Job Objects'
			value = $jobObjectsCount
			inline = 'false'
		}
		[PSCustomObject]@{
			name	= 'Notice'
			value	= "The information you see here is all that is available due to limitations in Veeam's PowerShell module."
			inline	= 'false'
		}
	)
}


# Switch for the session status to decide the embed colour.
Switch ($status) {
	None {$colour		= '16777215'}
	Warning {$colour	= '16776960'}
	Success {$colour	= '65280'}
	Failed {$colour		= '16711680'}
	Default {$colour	= '16777215'}
}

# Decide whether to mention user
## On fail
Try {
	If ($Config.mention_on_fail -and $Status -eq 'Failed') {
		$mention = $true
	}
}
Catch {
	Write-LogMessage -Tag 'WARN' -Message "Unable to determine 'mention on fail' configuration. User will not be mentioned."
}

## On warning
Try {
	If ($Config.mention_on_warning -and $Status -eq 'Warning') {
		$mention = $true
	}
}
Catch {
	Write-LogMessage -Tag 'WARN' -Message "Unable to determine 'mention on warning' configuration. User will not be mentioned."
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

# Create payload object.
Switch ($mention) {
	## Mention user on job failure if configured to do so.
	$true {
		$payload = [PSCustomObject]@{
			content = "<@!$($Config.userid)> Job $Status!"
			embeds	= $embedArray
		}
	}
	## Otherwise do not mention user.
	$False {
		$payload = [PSCustomObject]@{ embeds = $embedArray }
	}
}


# Send iiiit.
$request = Invoke-RestMethod -Uri $Config.webhook -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'

# Write error if message fails to send to Discord.
If ($request.Length -gt '0') {
	Write-LogMessage -Tag 'ERROR' -Message 'Failed to send message to Discord. Response below.'
	Write-LogMessage -Tag 'ERROR' -Message "$request"
}


# Trigger update if there's a newer version available.
If (($updateStatus.CurrentVersion -lt $updateStatus.latestVersion) -and $Config.auto_update) {
	# Copy update script out of working directory.
	Copy-Item $PSScriptRoot\Updater.ps1 $PSScriptRoot\..\VDNotifs-Updater.ps1
	Unblock-File $PSScriptRoot\..\VDNotifs-Updater.ps1

	# Run update script.
	$updateArgs = "-file $PSScriptRoot\..\VDNotifs-Updater.ps1", "-LatestVersion $latestVersion"
	Start-Process -FilePath 'powershell' -Verb runAs -ArgumentList $updateArgs -WindowStyle hidden
}

# Stop logging.
If ($Config.debug_log) {
	Stop-Logging
}
