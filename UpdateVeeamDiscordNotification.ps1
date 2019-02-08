# Pull version from script trigger
Param (
    [string]$LatestVersion
)
# Notification script block
$notification = {
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
    # Send iiit
    Invoke-RestMethod -Uri $currentconfig.webhook -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'
}

# Get currently downloaded version
$oldversion = Get-Content "$PSScriptRoot\VeeamDiscordNotifications\resources\version.txt"
# Import functions
Import-Module "$PSScriptRoot\VeeamDiscordNotifications\resources\logger.psm1"
# Start logging
Start-Logging "$PSScriptRoot\update.log"

# Pull current config to variable
$currentConfig = (Get-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json

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
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/download/$LatestVersion/VeeamDiscordNotifications-$LatestVersion.zip -OutFile $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip
# Expand downloaded ZIP
Expand-Archive $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -DestinationPath $PSScriptRoot
# Rename old version to make room for the new version
Rename-Item $PSScriptRoot\VeeamDiscordNotifications $PSScriptRoot\VeeamDiscordNotifications-old
# Rename extracted update
Rename-Item $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion $PSScriptRoot\VeeamDiscordNotifications
# Pull configuration from new conf file
$newConfig = (Get-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json
# Unblock script files
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\DiscordVeeamAlertSender.ps1
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\resources\logger.psm1
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\UpdateVeeamDiscordNotification.ps1
# Set conf.json as it was before
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

# Get newly downloaded version
$newversion = Get-Content "$PSScriptRoot\VeeamDiscordNotifications\resources\version.txt"

# Send notification
If ($newversion -eq $LatestVersion) {
    $result = 'Success!'
    Remove-Item –Path $PSScriptRoot\VeeamDiscordNotifications-old –Recurse -Force
    Write-Output 'Successfully updated.'
    Invoke-Command -ScriptBlock $notification
}
Else {
    $result = 'Failure!'
    Remove-Item –Path $PSScriptRoot\VeeamDiscordNotifications –Recurse -Force
    Rename-Item $PSScriptRoot\VeeamDiscordNotifications-old $PSScriptRoot\VeeamDiscordNotifications
    Write-Output 'Update failed, reverted to previous version.'
    Invoke-Command -ScriptBlock $notification
}

# Clean up.
Remove-Item "$PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip"
Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force

# Stop logging
Stop-Logging "$PSScriptRoot\update.log"
# Copy item
Move-Item "$PSScriptRoot\update.log" "$PSScriptRoot\VeeamDiscordNotifications\log\update.log"
