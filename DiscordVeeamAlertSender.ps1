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
if($config.debug_log) {
	Start-Logging "$PSScriptRoot\log\debug.log"
}

# Add Veeam snap-in
Add-PSSnapin VeeamPSSnapin

# Get the session
$session = Get-VBRBackupSession | ?{($_.OrigJobName -eq $JobName) -and ($Id -eq $_.Id.ToString())}

# Wait for the session to finish up
while ($session.IsCompleted -eq $false) {
	Write-LogMessage 'Info' 'Session not finished Sleeping...'
	Start-Sleep -m 200
	$session = Get-VBRBackupSession | ?{($_.OrigJobName -eq $JobName) -and ($Id -eq $_.Id.ToString())}
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
    ({$PSItem -lt 1KB}) {
        [String]$JobSizeRound = $JobSize
        $JobSizeRound += ' B'
        break
    }
    ({$PSItem -lt 1MB}) {
        $JobSize = $JobSize / 1KB
        [String]$JobSizeRound = [math]::Round($JobSize,2)
        $JobSizeRound += ' KB'
        break
    }
    ({$PSItem -lt 1GB}) {
        $JobSize = $JobSize / 1MB
        [String]$JobSizeRound = [math]::Round($JobSize,2)
        $JobSizeRound += ' MB'
        break
    }
    ({$PSItem -lt 1TB}) {
        $JobSize = $JobSize / 1GB
        [String]$JobSizeRound = [math]::Round($JobSize,2)
        $JobSizeRound += ' GB'
        break
    }
    ({$PSItem -ge 1TB}) {
        $JobSize = $JobSize / 1TB
        [String]$JobSizeRound = [math]::Round($JobSize,2)
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
    ({$PSItem -lt 1KB}) {
        [String]$TransfSizeRound = $TransfSize
        $TransfSizeRound += ' B'
        break
    }
    ({$PSItem -lt 1MB}) {
        $TransfSize = $TransfSize / 1KB
        [String]$TransfSizeRound = [math]::Round($TransfSize,2)
        $TransfSizeRound += ' KB'
        break
    }
    ({$PSItem -lt 1GB}) {
        $TransfSize = $TransfSize / 1MB
        [String]$TransfSizeRound = [math]::Round($TransfSize,2)
        $TransfSizeRound += ' MB'
        break
    }
    ({$PSItem -lt 1TB}) {
        $TransfSize = $TransfSize / 1GB
        [String]$TransfSizeRound = [math]::Round($TransfSize,2)
        $TransfSizeRound += ' GB'
        break
    }
    ({$PSItem -ge 1TB}) {
        $TransfSize = $TransfSize / 1TB
        [String]$TransfSizeRound = [math]::Round($TransfSize,2)
        $TransfSizeRound += ' TB'
        break
    }
    Default {
    [String]$TransfSizeRound = $TransfSize
    $TransfSizeRound += ' B'
    }
}

# Calculate job duration
$Duration = $session.Info.EndTime - $session.Info.CreationTime
$TimeSpan = $Duration
$Duration = '{0:00}h {1:00}m {2:00}s' -f $TimeSpan.Hours, $TimeSpan.Minutes, $TimeSpan.Seconds

# Switch on the session status
switch ($Status) {
    None {$colour = '16777215'}
    Warning {$colour = '16776960'}
    Success {$colour = '65280'}
    Failed {$colour = '16711680'}
    Default {$colour = '16777215'}
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
	name = 'Backup size'
    value = [String]$JobSizeRound
    inline = 'true'
}
$transfsizefield = [PSCustomObject]@{
	name = 'Transferred Data'
    value = [String]$TransfSizeRound
    inline = 'true'
}
$dedupfield = [PSCustomObject]@{
	name = 'Dedup Ratio'
    value = [String]$session.BackupStats.DedupRatio
    inline = 'true'
}
$compressfield = [PSCustomObject]@{
	name = 'Compression Ratio'
    value = [String]$session.BackupStats.CompressRatio
    inline = 'true'
}
$durationfield = [PSCustomObject]@{
	name = 'Job Duration'
    value = $Duration
    inline = 'true'
}

# Add field objects to the field array
$fieldarray.Add($backupsizefield) | Out-Null
$fieldarray.Add($transfsizefield) | Out-Null
$fieldarray.Add($dedupfield) | Out-Null
$fieldarray.Add($compressfield) | Out-Null
$fieldarray.Add($durationfield) | Out-Null

# Embed object including field and thumbnail vars from above
$embedobject = [PSCustomObject]@{
	title		= $JobName
	description	= $Status
	color		= $colour
	thumbnail	= $thumbobject
    fields		= $fieldarray
}

# Add embed object to the array created above
$embedarray.Add($embedobject) | Out-Null

# Create payload
$payload = [PSCustomObject]@{
	embeds	= $embedarray
}

# Send iiiit after converting to JSON
$request = Invoke-RestMethod -Uri $config.webhook -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'

# Stop logging.
if($config.debug_log) {
	Stop-Logging "$PSScriptRoot\log\debug.log"
}
