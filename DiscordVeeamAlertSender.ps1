# Pull in variables that were set when the script was started by Veeam
Param(
	[String]$jobName,
	[String]$id
)

# Import Functions
Import-Module "$PSScriptRoot\resources\logger.psm1"

# Get the config from your config file
$config = (Get-Content "$PSScriptRoot\config\conf.json") -Join "`n" | ConvertFrom-Json

# Log if enabled in config
if ($config.debug_log) {
	Start-Logging "$PSScriptRoot\log\debug.log"
}

# Determine if an update is required.
## Get currently downloaded version of this project.
$currentVersion = Get-Content "$PSScriptRoot\resources\version.txt" -Raw

## Get latest release from GitHub and use that to determine the latest version.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$latestRelease = Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/latest -Headers @{"Accept"="application/json"} -UseBasicParsing

## Release IDs are returned in a format of {"id":3622206,"tag_name":"v1.0"} so we need to extract tag_name.
$latestReleaseJson = $latestRelease.Content | ConvertFrom-Json
$latestVersion = $latestReleaseJson.tag_name

## Define version announcement phrases and get a random one for the version info in the footer of the report.
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
    "Fuuuckin hell, $currentVersion hasn't even been released! Latest is $latestRelease."
)

## Comparing local and latest versions and determine if an update is required, then use that information to build the footer text.
If ($currentVersion -lt $latestVersion) {
    $footerAddition = (Get-Random -InputObject $updateOlderArray -Count 1)
}
Elseif ($currentVersion -eq $latestVersion) {
    $footerAddition = (Get-Random -InputObject $updateCurrentArray -Count 1)
}
Elseif ($currentVersion -gt $latestVersion) {
    $footerAddition = (Get-Random -InputObject $updateNewerArray -Count 1)
}

# Import Veeam module
Import-Module Veeam.Backup.PowerShell

# Get the session
$session = Get-VBRBackupSession | ?{($_.OrigjobName -eq $jobName) -and ($id -eq $_.Id.ToString())}

# Wait for the session to finish up
while ($session.IsCompleted -eq $false) {
	Write-LogMessage 'Info' 'Session not finished Sleeping...'
	Start-Sleep -m 200
	$session = Get-VBRBackupSession | ?{($_.OrigjobName -eq $jobName) -and ($id -eq $_.Id.ToString())}
}

# Gather session info
[String]$status = $session.Result
$jobName = $session.Name.ToString().Trim()
$JobType = $session.JobTypeString.Trim()
[Float]$jobSize = $session.BackupStats.DataSize
[Float]$transferSize = $session.BackupStats.BackupSize
[Float]$speed = $session.Info.Progress.AvgSpeed

# Determine whether to report the job and actual data sizes in B, KB, MB, GB, or TB, depending on completed size. Will fallback to B[ytes] if no match.
## Job size
Switch ($jobSize) {
    ({$PSItem -lt 1KB}) {
        [String]$jobSizeRound = $jobSize
        $jobSizeRound += ' B'
        break
    }
    ({$PSItem -lt 1MB}) {
        $jobSize = $jobSize / 1KB
        [String]$jobSizeRound = [math]::Round($jobSize,2)
        $jobSizeRound += ' KB'
        break
    }
    ({$PSItem -lt 1GB}) {
        $jobSize = $jobSize / 1MB
        [String]$jobSizeRound = [math]::Round($jobSize,2)
        $jobSizeRound += ' MB'
        break
    }
    ({$PSItem -lt 1TB}) {
        $jobSize = $jobSize / 1GB
        [String]$jobSizeRound = [math]::Round($jobSize,2)
        $jobSizeRound += ' GB'
        break
    }
    ({$PSItem -ge 1TB}) {
        $jobSize = $jobSize / 1TB
        [String]$jobSizeRound = [math]::Round($jobSize,2)
        $jobSizeRound += ' TB'
        break
    }
    Default {
    [String]$jobSizeRound = $jobSize
    $jobSizeRound += ' B'
    }
}
## Transfer size
Switch ($transferSize) {
    ({$PSItem -lt 1KB}) {
        [String]$transferSizeRound = $transferSize
        $transferSizeRound += ' B'
        break
    }
    ({$PSItem -lt 1MB}) {
        $transferSize = $transferSize / 1KB
        [String]$transferSizeRound = [math]::Round($transferSize,2)
        $transferSizeRound += ' KB'
        break
    }
    ({$PSItem -lt 1GB}) {
        $transferSize = $transferSize / 1MB
        [String]$transferSizeRound = [math]::Round($transferSize,2)
        $transferSizeRound += ' MB'
        break
    }
    ({$PSItem -lt 1TB}) {
        $transferSize = $transferSize / 1GB
        [String]$transferSizeRound = [math]::Round($transferSize,2)
        $transferSizeRound += ' GB'
        break
    }
    ({$PSItem -ge 1TB}) {
        $transferSize = $transferSize / 1TB
        [String]$transferSizeRound = [math]::Round($transferSize,2)
        $transferSizeRound += ' TB'
        break
    }
    Default {
    [String]$transferSizeRound = $transferSize
    $transferSizeRound += ' B'
    }
}

# Determine whether to report the job processing rate in B/s, KB/s, MB/s, or GB/s, depending on the figure. Will fallback to B[ytes] if no match.
Switch ($speed) {
    ({$PSItem -lt 1KB}) {
        [String]$speedRound = $speed
        $speedRound += ' B/s'
        break
    }
    ({$PSItem -lt 1MB}) {
        $speed = $speed / 1KB
        [String]$speedRound = [math]::Round($speed,2)
        $speedRound += ' KB/s'
        break
    }
    ({$PSItem -lt 1GB}) {
        $speed = $speed / 1MB
        [String]$speedRound = [math]::Round($speed,2)
        $speedRound += ' MB/s'
        break
    }
    ({$PSItem -lt 1TB}) {
        $speed = $speed / 1GB
        [String]$speedRound = [math]::Round($speed,2)
        $speedRound += ' GB/s'
        break
    }
    Default {
        [String]$speedRound = $speed
        $speedRound += ' B/s'
    }
}
# Write "Unknown" processing speed if 0B/s to avoid confusion.
If ($speedRound -eq '0 B/s') {
    $speedRound = 'Unknown.'
}

# Calculate job duration
$TimeSpan = $session.Info.EndTime - $session.Info.CreationTime
If ($TimeSpan.Days -ge '1') {
        $Duration = '{0}d {1}h {2}m {3}s' -f $TimeSpan.Days, $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds
}
Else {
    $Duration = '{0}h {1}m {2}s' -f $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds
}

# Switch on the session status
switch ($status) {
    None {$colour = '16777215'}
    Warning {$colour = '16776960'}
    Success {$colour = '65280'}
    Failed {$colour = '16711680'}
    Default {$colour = '16777215'}
}

# Create embed and fields array
[System.Collections.ArrayList]$embedArray = @()
[System.Collections.ArrayList]$fieldArray = @()

# Thumbnail object
$thumbObject = [PSCustomObject]@{
	url = $config.thumbnail
}

# Field objects
$backupSizeField = [PSCustomObject]@{
	name = 'Backup size'
    value = [String]$jobSizeRound
    inline = 'true'
}
$transferSizeField = [PSCustomObject]@{
	name = 'Transferred Data'
    value = [String]$transferSizeRound
    inline = 'true'
}
$dedupField = [PSCustomObject]@{
	name = 'Dedup Ratio'
    value = [String]$session.BackupStats.DedupRatio
    inline = 'true'
}
$compressField = [PSCustomObject]@{
	name = 'Compression Ratio'
    value = [String]$session.BackupStats.CompressRatio
    inline = 'true'
}
$durationField = [PSCustomObject]@{
	name = 'Job Duration'
    value = $duration
    inline = 'true'
}
$speedField = [PSCustomObject]@{
	name = 'Processing rate'
    value = $speedRound
    inline = 'true'
}

# Add field objects to the field array
$fieldArray.Add($backupSizeField) | Out-Null
$fieldArray.Add($transferSizeField) | Out-Null
$fieldArray.Add($dedupField) | Out-Null
$fieldArray.Add($compressField) | Out-Null
$fieldArray.Add($durationField) | Out-Null
$fieldArray.Add($speedField) | Out-Null

# Build footer object
$footerObject = [PSCustomObject]@{
	text = "tigattack's VeeamDiscordNotifications $currentVersion. $footerAddition"
    icon_url = 'https://avatars0.githubusercontent.com/u/10629864'
}

# Embed object including field and thumbnail vars from above
$embedObject = [PSCustomObject]@{
	title		= $jobName
	description	= $status
	color		= $colour
	thumbnail	= $thumbObject
    fields		= $fieldArray
    footer		= $footerObject
}

# Add embed object to the array created above
$embedArray.Add($embedObject) | Out-Null

# Decide whether to mention user
If (($config.mention_on_fail -and $Status -eq 'Failed') -or ($config.mention_on_warning -and $Status -eq 'Warning')) {
	$mention = $true
}

# Create payload
## Mention user if job failed
If ($config.mention_on_fail -and $status -eq 'Failed') {
    $payload = [PSCustomObject]@{
        content = "<@!$($config.userid)> Job status $status"
    	embeds	= $embedArray
    }
}
## Job report without mention
Else {
    $payload = [PSCustomObject]@{
    	embeds	= $embedArray
    }
}

# Send iiiit after converting to JSON
$request = Invoke-RestMethod -Uri $config.webhook -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'

# Trigger update on outdated version
If ($currentVersion -lt $latestVersion -and $config.auto_update) {
    Copy-Item $PSScriptRoot\UpdateVeeamDiscordNotification.ps1 $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1
    Unblock-File $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1
    $powershellArguments = "-file $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1", "-LatestVersion $latestVersion"
    Start-Process -FilePath "powershell" -Verb runAs -ArgumentList $powershellArguments -WindowStyle hidden
}

# Stop logging.
if ($config.debug_log) {
	Stop-Logging "$PSScriptRoot\log\debug.log"
}
