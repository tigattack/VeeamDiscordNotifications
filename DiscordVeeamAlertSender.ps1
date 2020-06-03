# Pull in variables from the DiscordNotificationBootstrap script
Param(
	[String]$jobName,
	[String]$id
)

# Import functions
Import-Module "$PSScriptRoot\resources\logger.psm1"
Import-Module "$PSScriptRoot\resources\ConvertTo-ByteUnits.psm1"

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

# Determine if an update is required
## Get currently downloaded version of this project.
$currentVersion = Get-Content "$PSScriptRoot\resources\version.txt" -Raw

## Get latest release from GitHub and use that to determine the latest version.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$latestRelease = Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/latest -Headers @{"Accept"="application/json"} -UseBasicParsing
## Release IDs are returned in a format of {"id":3622206,"tag_name":"v1.0"}, so we need to extract tag_name.
$latestVersion = ConvertFrom-Json $latestRelease.Content | ForEach-Object {$_.tag_name}

## Define version announcement phrases.
$updateOlderArray = @(
    "Jesus mate, you're out of date! Latest is $latestVersion. Check your update logs.",
    "Bloody hell you muppet, you need to update! Latest is $latestVersion. Check your update logs.",
    "Fuck me sideways, you're out of date! Latest is $latestVersion. Check your update logs.",
    "Shitting heck lad, you need to update! Latest is $latestVersion. Check your update logs.",
    "Christ almighty, you're out of date! Latest is $latestVersion. Check your update logs."
)
$updateCurrentArray = @(
    "Nice work mate, you're up to date.",
    "Good shit buddy, you're up to date.",
    "Top stuff my dude, you're running the latest version.",
    "Good job fam, you're all up to date.",
    "Lovely stuff mate, you're running the latest version."
)
$updateNewerArray = @(
    "Wewlad, check you out running a pre-release version, latest is $latestVersion!",
    "Christ m8e, this is mental, you're ahead of release, latest is $latestVersion!",
    "You nutter, you're running a pre-release version! Latest is $latestVersion!",
    "Bloody hell mate, this is unheard of, $currentVersion isn't even released yet, latest is $latestVersion!"
    "Fuuuckin hell, $currentVersion hasn't even been released! Latest is $latestVersion."
)

## Comparing local and latest versions and determine if an update is required, then use that information to build the footer text.
## Picks a phrase at random from the list above for the version statement in the footer of the backup report.
If ($currentVersion -lt $latestVersion) {
    $footerAddition = (Get-Random -InputObject $updateOlderArray -Count 1)
}
Elseif ($currentVersion -eq $latestVersion) {
    $footerAddition = (Get-Random -InputObject $updateCurrentArray -Count 1)
}
Elseif ($currentVersion -gt $latestVersion) {
    $footerAddition = (Get-Random -InputObject $updateNewerArray -Count 1)
}

# Add Veeam snap-in.
Add-PSSnapin VeeamPSSnapin

# Get the backup session information.
$session = Get-VBRBackupSession | Where-Object{($_.OrigjobName -eq $jobName) -and ($id -eq $_.Id.ToString())}

# Wait for the backup session to finish.
While ($session.IsCompleted -eq $false) {
	Write-LogMessage -Tag 'Info' -Message 'Session not finished. Sleeping...'
	Start-Sleep -m 200
	$session = Get-VBRBackupSession | Where-Object{($_.OrigjobName -eq $jobName) -and ($id -eq $_.Id.ToString())}
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
$jobSizeRound = ConvertTo-ByteUnits -InputObject $jobSize
$transferSizeRound = ConvertTo-ByteUnits -InputObject $transferSize
## Convert speed in B/s to rounded units and append '/s'
$speedRound = (ConvertTo-ByteUnits -InputObject $speed) + '/s'

# Write "Unknown" processing speed if 0B/s to avoid confusion.
If ($speedRound -eq '0 B/s') {
    $speedRound = 'Unknown.'
}

# Calculate difference between job start and end time.
$duration = $jobEndTime - $jobStartTime
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
	    name = 'Backup size'
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
        name = 'Processing rate'
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
        value = '{0}:{1}:{2}' -f $jobStartTime.Hour, $jobStartTime.Minute, $jobStartTime.Second
        inline = 'true'
    }
    [PSCustomObject]@{
        name = 'Time Completed'
        value = '{0}:{1}:{2}' -f $jobEndTime.Hour, $jobEndTime.Minute, $jobEndTime.Second
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

# Trigger update if there's a newer version available.
If ($currentVersion -lt $latestVersion -and $config.auto_update) {
    Copy-Item $PSScriptRoot\UpdateVeeamDiscordNotification.ps1 $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1
    Unblock-File $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1
    $powershellArguments = "-file $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1", "-LatestVersion $latestVersion"
    Start-Process -FilePath "powershell" -Verb runAs -ArgumentList $powershellArguments -WindowStyle hidden
}

# Stop logging.
if($config.debug_log) {
	Stop-Logging $logFile
}
