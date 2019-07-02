# Pull in variables that were set when the script was started by Veeam
Param(
	[String]$JobName,
	[String]$Id
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
$currentversion = Get-Content "$PSScriptRoot\resources\version.txt" -Raw

## Get latest release from GitHub and use that to determine the latest version.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$latestrelease = Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/latest -Headers @{"Accept"="application/json"} -UseBasicParsing

## Release IDs are returned in a format of {"id":3622206,"tag_name":"v1.0"} so we need to extract tag_name.
$latestreleasejson = $latestrelease.Content | ConvertFrom-Json
$latestversion = $latestreleasejson.tag_name

## Define version announcement phrases and get a random one for the version info in the footer of the report.
$updateolderarray = @(
    "Jesus mate, you're out of date! Latest is $latestversion. Check your update logs.",
    "Bloody hell you muppet, you need to update! Latest is $latestversion. Check your update logs.",
    "Fuck me sideways, you're out of date! Latest is $latestversion. Check your update logs.",
    "Shitting heck lad, you need to update! Latest is $latestversion. Check your update logs.",
    "Christ almighty, you're out of date! Latest is $latestversion. Check your update logs."
)
$updatecurrentarray = @(
    "Nice work mate, you're up to date.",
    "Good shit buddy, you're up to date.",
    "Top stuff my dude, you're running the latest version.",
    "Good job fam, you're all up to date.",
    "Lovely stuff mate, you're running the latest version."
)
$updatenewerarray = @(
    "Wewlad, check you out running a pre-release version, latest is $latestversion!",
    "Christ m8e, this is mental, you're ahead of release, latest is $latestversion!",
    "You nutter, you're running a pre-release version! Latest is $latestversion!",
    "Bloody hell mate, this is unheard of, $currentversion isn't even released yet, latest is $latestversion!"
    "Fuuuckin hell, $currentversion hasn't even been released! Latest is $latestrelease."
)

## Comparing local and latest versions and determine if an update is required, then use that information to build the footer text.
If ($currentversion -lt $latestversion) {
	$footeraddition = (Get-Random -InputObject $updateolderarray -Count 1)
}
Elseif ($currentversion -eq $latestversion) {
	$footeraddition = (Get-Random -InputObject $updatecurrentarray -Count 1)
}
Elseif ($currentversion -gt $latestversion) {
	$footeraddition = (Get-Random -InputObject $updatenewerarray -Count 1)
}

# Import Veeam module
Import-Module Veeam.Backup.PowerShell

# Get the session
$session = Get-VBRBackupSession | ? { ($_.OrigJobName -eq $JobName) -and ($Id -eq $_.Id.ToString()) }

# Wait for the session to finish up
while ($session.IsCompleted -eq $false) {
	Write-LogMessage 'Info' 'Session not finished Sleeping...'
	Start-Sleep -m 200
	$session = Get-VBRBackupSession | ? { ($_.OrigJobName -eq $JobName) -and ($Id -eq $_.Id.ToString()) }
}

# Gather session info
[String]$Status = $session.Result
$JobName = $session.Name.ToString().Trim()
$JobType = $session.JobTypeString.Trim()
[Float]$JobSize = $session.BackupStats.DataSize
[Float]$TransfSize = $session.BackupStats.BackupSize
[Float]$Speed = $session.Info.Progress.AvgSpeed

# Determine whether to report the job and actual data sizes in B, KB, MB, GB, or TB, depending on completed size. Will fallback to B[ytes] if no match.
## Job size
Switch ($JobSize) {
	( { $PSItem -lt 1KB }) {
		[String]$JobSizeRound = $JobSize
		$JobSizeRound += ' B'
		break
	}
	( { $PSItem -lt 1MB }) {
		$JobSize = $JobSize / 1KB
		[String]$JobSizeRound = [math]::Round($JobSize, 2)
		$JobSizeRound += ' KB'
		break
	}
	( { $PSItem -lt 1GB }) {
		$JobSize = $JobSize / 1MB
		[String]$JobSizeRound = [math]::Round($JobSize, 2)
		$JobSizeRound += ' MB'
		break
	}
	( { $PSItem -lt 1TB }) {
		$JobSize = $JobSize / 1GB
		[String]$JobSizeRound = [math]::Round($JobSize, 2)
		$JobSizeRound += ' GB'
		break
	}
	( { $PSItem -ge 1TB }) {
		$JobSize = $JobSize / 1TB
		[String]$JobSizeRound = [math]::Round($JobSize, 2)
		$JobSizeRound += ' TB'
		break
	}
	Default {
		[String]$JobSizeRound = $JobSize
		$JobSizeRound += ' B'
	}
}
## Transfer size
Switch ($TransfSize) {
	( { $PSItem -lt 1KB }) {
		[String]$TransfSizeRound = $TransfSize
		$TransfSizeRound += ' B'
		break
	}
	( { $PSItem -lt 1MB }) {
		$TransfSize = $TransfSize / 1KB
		[String]$TransfSizeRound = [math]::Round($TransfSize, 2)
		$TransfSizeRound += ' KB'
		break
	}
	( { $PSItem -lt 1GB }) {
		$TransfSize = $TransfSize / 1MB
		[String]$TransfSizeRound = [math]::Round($TransfSize, 2)
		$TransfSizeRound += ' MB'
		break
	}
	( { $PSItem -lt 1TB }) {
		$TransfSize = $TransfSize / 1GB
		[String]$TransfSizeRound = [math]::Round($TransfSize, 2)
		$TransfSizeRound += ' GB'
		break
	}
	( { $PSItem -ge 1TB }) {
		$TransfSize = $TransfSize / 1TB
		[String]$TransfSizeRound = [math]::Round($TransfSize, 2)
		$TransfSizeRound += ' TB'
		break
	}
	Default {
		[String]$TransfSizeRound = $TransfSize
		$TransfSizeRound += ' B'
	}
}

# Determine whether to report the job processing rate in B/s, KB/s, MB/s, or GB/s, depending on the figure. Will fallback to B[ytes] if no match.
Switch ($Speed) {
	( { $PSItem -lt 1KB }) {
		[String]$SpeedRound = $Speed
		$SpeedRound += ' B/s'
		break
	}
	( { $PSItem -lt 1MB }) {
		$Speed = $Speed / 1KB
		[String]$SpeedRound = [math]::Round($Speed, 2)
		$SpeedRound += ' KB/s'
		break
	}
	( { $PSItem -lt 1GB }) {
		$Speed = $Speed / 1MB
		[String]$SpeedRound = [math]::Round($Speed, 2)
		$SpeedRound += ' MB/s'
		break
	}
	( { $PSItem -lt 1TB }) {
		$Speed = $Speed / 1GB
		[String]$SpeedRound = [math]::Round($Speed, 2)
		$SpeedRound += ' GB/s'
		break
	}
	Default {
		[String]$SpeedRound = $Speed
		$SpeedRound += ' B/s'
	}
}
# Write "Unknown" processing speed if 0B/s to avoid confusion.
If ($SpeedRound -eq '0 B/s') {
	$SpeedRound = 'Unknown.'
}

# Calculate job duration
$Duration = $session.Info.EndTime - $session.Info.CreationTime
$TimeSpan = $Duration
$Duration = '{0:00}h {1:00}m {2:00}s' -f $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds

# Decide embed colour from session status
switch ($Status) {
	None { $colour = '16777215' }
	Warning { $colour = '16776960' }
	Success { $colour = '65280' }
	Failed { $colour = '16711680' }
	Default { $colour = '16777215' }
}

# Create embed and fields array
[System.Collections.ArrayList]$embedarray = @()
[System.Collections.ArrayList]$fieldarray = @()

# Thumbnail object
$thumbobject = [PSCustomObject]@{
	url = $config.thumbnail
}

# Field objects
$backupsizefield = [PSCustomObject]@{
	name   = 'Backup size'
	value  = [String]$JobSizeRound
	inline = 'true'
}
$transfsizefield = [PSCustomObject]@{
	name   = 'Transferred Data'
	value  = [String]$TransfSizeRound
	inline = 'true'
}
$dedupfield = [PSCustomObject]@{
	name   = 'Dedup Ratio'
	value  = [String]$session.BackupStats.DedupRatio
	inline = 'true'
}
$compressfield = [PSCustomObject]@{
	name   = 'Compression Ratio'
	value  = [String]$session.BackupStats.CompressRatio
	inline = 'true'
}
$durationfield = [PSCustomObject]@{
	name   = 'Job Duration'
	value  = $Duration
	inline = 'true'
}
$speedfield = [PSCustomObject]@{
	name   = 'Processing rate'
	value  = $SpeedRound
	inline = 'true'
}

# Add field objects to the field array
$fieldarray.Add($backupsizefield) | Out-Null
$fieldarray.Add($transfsizefield) | Out-Null
$fieldarray.Add($dedupfield) | Out-Null
$fieldarray.Add($compressfield) | Out-Null
$fieldarray.Add($durationfield) | Out-Null
$fieldarray.Add($speedfield) | Out-Null

# Build footer object
$footerobject = [PSCustomObject]@{
	text     = "tigattack's VeeamDiscordNotifications $currentversion. $footeraddition"
	icon_url = 'https://avatars0.githubusercontent.com/u/10629864'
}

# Embed object including field and thumbnail vars from above
$embedobject = [PSCustomObject]@{
	title       = $JobName
	description	= $Status
	color       = $colour
	thumbnail   = $thumbobject
	fields      = $fieldarray
	footer      = $footerobject
}

# Add embed object to the array created above
$embedarray.Add($embedobject) | Out-Null

# Decide whether to mention user
If (($config.mention_on_fail -and $Status -eq 'Failed') -or ($config.mention_on_warning -and $Status -eq 'Warning')) {
	$mention = $true
}

# Create payload
## Job report with mention
If ($mention -eq $true) {
	$payload = [PSCustomObject]@{
		content = "<@!$($config.userid)> $JobName - $Status"
		embeds  = $embedarray
	}
}
## Job report without mention
Else {
	$payload = [PSCustomObject]@{
		embeds	= $embedarray
	}
}

# Send iiiit after converting to JSON
$request = Invoke-RestMethod -Uri $config.webhook -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'

# Trigger update on outdated version
If ($currentversion -lt $latestversion -and $config.auto_update) {
	Copy-Item $PSScriptRoot\UpdateVeeamDiscordNotification.ps1 $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1
	Unblock-File $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1
	$powershellArguments = "-file $PSScriptRoot\..\UpdateVeeamDiscordNotification.ps1", "-LatestVersion $latestversion"
	Start-Process -FilePath "powershell" -Verb runAs -ArgumentList $powershellArguments -WindowStyle hidden
}

# Stop logging.
if ($config.debug_log) {
	Stop-Logging "$PSScriptRoot\log\debug.log"
}
