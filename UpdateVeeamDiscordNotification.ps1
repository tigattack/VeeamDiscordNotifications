# Pull version from script trigger
Param (
    [string]$LatestVersion
)

# Import functions
Import-Module "$PSScriptRoot\VeeamDiscordNotifications\resources\logger.psm1"
# Start logging
Start-Logging "$PSScriptRoot\update.log"

# Set error action preference.
Write-Output 'Set error action preference.'
$ErrorActionPreference = 'Stop'

# Notification function
function notification {
    Write-Output 'Building notification.'
    # Create embed and fields array
    [System.Collections.ArrayList]$embedarray = @()
    [System.Collections.ArrayList]$fieldarray = @()
    # Thumbnail object
    $thumbobject = [PSCustomObject]@{
	    url = $currentconfig.thumbnail
    }
    # Field objects
    $resultfield = [PSCustomObject]@{
	    name = 'Update Result'
        value = $result
        inline = 'false'
    }
    $newversionfield = [PSCustomObject]@{
	    name = 'New version'
        value = $newversion
        inline = 'false'
    }
    $oldversionfield = [PSCustomObject]@{
	    name = 'Old version'
        value = $oldversion
        inline = 'false'
    }
    # Add field objects to the field array
    $fieldarray.Add($oldversionfield) | Out-Null
    $fieldarray.Add($newversionfield) | Out-Null
    $fieldarray.Add($resultfield) | Out-Null
    # Send error if exist
    If ($errorvar -ne $null) {
        $errorfield = [PSCustomObject]@{
	        name = 'Update Error'
            value = $errorvar
            inline = 'false'
        }
        $fieldarray.Add($errorfield) | Out-Null
    }
    # Embed object including field and thumbnail vars from above
    $embedobject = [PSCustomObject]@{
        title		= 'Update'
        color		= '1267393'
        thumbnail	= $thumbobject
        fields		= $fieldarray
    }
    # Add embed object to the array created above
    $embedarray.Add($embedobject) | Out-Null
    # Build payload
    $payload = [PSCustomObject]@{
    	embeds	= $embedarray
    }
    Write-Output 'Sending notification.'
    # Send iiit
    Invoke-RestMethod -Uri $currentconfig.webhook -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json' -ErrorAction Continue
}
# Success function
function success {
    Write-Output 'Successfully updated.'
    $result = 'Success!'
    Remove-Item –Path $PSScriptRoot\VeeamDiscordNotifications-old –Recurse -Force
    Invoke-Expression notification
}
# Failure function
function fail {
    Write-Output 'Update failed, reverting to previous version.'
    $result = 'Failure!'
    Remove-Item –Path $PSScriptRoot\VeeamDiscordNotifications –Recurse -Force
    Rename-Item $PSScriptRoot\VeeamDiscordNotifications-old $PSScriptRoot\VeeamDiscordNotifications
    Invoke-Expression notification
}

# Get currently downloaded version
Try {
    Write-Output 'Getting currently downloaded version of the script.'
    $oldversion = Get-Content "$PSScriptRoot\VeeamDiscordNotifications\resources\version.txt"
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Pull current config to variable
Try {
	Write-Output 'Pull current config to variable.'
	$currentConfig = (Get-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Wait until the alert sender has finished running, or quit this if it's still running after 60s. It should never take that long.
while (Get-WmiObject win32_process -filter "name='powershell.exe' and commandline like '%DiscordVeeamAlertSender.ps1%'") {
    $timer++
    Start-Sleep -Seconds 1
    If ($timer -eq '60') {
        Write-Output 'Timeout reached. Updater quitting as DiscordVeeamAlertSender.ps1 is still running after 60 seconds.'
        exit
    }
}

# Pull latest version of script from GitHub
Try {
	Write-Output 'Pull latest version of script from GitHub.'
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/download/$LatestVersion/VeeamDiscordNotifications-$LatestVersion.zip -OutFile $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Expand downloaded ZIP
Try {
	Write-Output 'Expand downloaded ZIP.'
	Expand-Archive $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -DestinationPath $PSScriptRoot
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Rename old version to make room for the new version
Try {
	Write-Output 'Rename old version to make room for the new version.'
	Rename-Item $PSScriptRoot\VeeamDiscordNotifications $PSScriptRoot\VeeamDiscordNotifications-old
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Rename extracted update
Try {
	Write-Output 'Rename extracted update.'
	Rename-Item $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion $PSScriptRoot\VeeamDiscordNotifications
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Pull configuration from new conf file
Try {
	Write-Output 'Pull configuration from new conf file.'
	$newConfig = (Get-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Unblock script files
Write-Output 'Unblock script files.'
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1 -ErrorAction Continue
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\DiscordVeeamAlertSender.ps1 -ErrorAction Continue
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\resources\logger.psm1 -ErrorAction Continue
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\UpdateVeeamDiscordNotification.ps1 -ErrorAction Continue

# Populate conf.json with previous configuration
Try {
	Write-Output 'Populate conf.json with previous configuration.'
	$newConfig.webhook = $currentConfig.webhook
    $newConfig.userid = $currentConfig.userid
    if ($currentConfig.mention_on_fail -ne $newConfig.mention_on_fail) {
        $newConfig.mention_on_fail = $currentConfig.mention_on_fail
    }
    if ($currentConfig.debug_log -ne $newConfig.debug_log) {
        $newConfig.debug_log = $currentConfig.debug_log
    }
    if ($currentConfig.auto_update -ne $newConfig.auto_update) {
        $newConfig.auto_update = $currentConfig.auto_update
    }
    ConvertTo-Json $newConfig | Set-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json"
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Get newly downloaded version
Try {
	Write-Output 'Get newly downloaded version.'
	$newversion = Get-Content "$PSScriptRoot\VeeamDiscordNotifications\resources\version.txt"
}
Catch {
    $errorvar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorvar"
    Invoke-Expression fail
}

# Send notification
If ($newversion -eq $LatestVersion) {
    Invoke-Expression success
}
Else {
    Invoke-Expression fail
}

# Clean up.
Write-Output 'Remove downloaded ZIP.'
Remove-Item "$PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip"
Write-Output 'Remove UpdateVeeamDiscordNotification.ps1.'
Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force

# Stop logging
Write-Output 'Stop logging.'
Stop-Logging "$PSScriptRoot\update.log"
# Move log file
Write-Output 'Move log file.'
Move-Item "$PSScriptRoot\update.log" "$PSScriptRoot\VeeamDiscordNotifications\log\update.log"
Write-Output 'Exiting.'
