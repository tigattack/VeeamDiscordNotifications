# Pull version from script trigger
Param (
    [string]$LatestVersion
)

# Import functions
Import-Module "$PSScriptRoot\VeeamDiscordNotifications\resources\logger.psm1"

# Logging
## Set log file name
$date = (Get-Date -UFormat %Y-%m-%d_%T | ForEach-Object { $_ -replace ":", "." })
$logFile = "$PSScriptRoot\Log_Update-$date.log"
## Start logging to file
Start-Logging $logFile

# Set error action preference.
Write-Output 'Set error action preference.'
$ErrorActionPreference = 'Stop'

# Notification function
function Update-Notification {
    Write-Output 'Building notification.'
    # Create embed and fields array
    [System.Collections.ArrayList]$embedArray = @()
    [System.Collections.ArrayList]$fieldArray = @()
    # Thumbnail object
    $thumbObject = [PSCustomObject]@{
	    url = $currentConfig.thumbnail
    }
    # Field objects
    $resultField = [PSCustomObject]@{
	    name = 'Update Result'
        value = $result
        inline = 'false'
    }
    $newVersionField = [PSCustomObject]@{
	    name = 'New version'
        value = $newVersion
        inline = 'false'
    }
    $oldVersionField = [PSCustomObject]@{
	    name = 'Old version'
        value = $oldVersion
        inline = 'false'
    }
    # Add field objects to the field array
    $fieldArray.Add($oldVersionField) | Out-Null
    $fieldArray.Add($newVersionField) | Out-Null
    $fieldArray.Add($resultField) | Out-Null
    # Send error if exist
    If ($null -ne $errorVar) {
        $errorField = [PSCustomObject]@{
	        name = 'Update Error'
            value = $errorVar
            inline = 'false'
        }
        $fieldArray.Add($errorField) | Out-Null
    }
    # Embed object including field and thumbnail vars from above
    $embedObject = [PSCustomObject]@{
        title		= 'Update'
        color		= '1267393'
        thumbnail	= $thumbObject
        fields		= $fieldArray
    }
    # Add embed object to the array created above
    $embedArray.Add($embedObject) | Out-Null
    # Build payload
    $payload = [PSCustomObject]@{
    	embeds	= $embedArray
    }
    Write-Output 'Sending notification.'
    # Send iiit
    Try {
        Invoke-RestMethod -Uri $currentConfig.webhook -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'
    }
    Catch {
        $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
        Write-Warning 'Update notification failed to send to Discord.'
        Write-Output "$errorVar"
    }
}

# Success function
function Update-Success {
    # Set error action preference so that errors while ending the script don't end the script prematurely.
    Write-Output 'Set error action preference.'
    $ErrorActionPreference = 'Continue'

    # Set result var for notification and script output
    $result = 'Success!'

    # Copy logs directory from copy of previously installed version to new install
    Write-Output 'Copying logs from old version to new version.'
    Copy-Item -Path $PSScriptRoot\VeeamDiscordNotifications-old\log -Destination $PSScriptRoot\VeeamDiscordNotifications\ -Recurse -Force

    # Remove copy of previously installed version
    Write-Output 'Removing old version.'
    Remove-Item -Path $PSScriptRoot\VeeamDiscordNotifications-old -Recurse -Force

    # Trigger the Update-Notification function and then End-Script function.
    Invoke-Expression Update-Notification
    Invoke-Expression End-Script
}

# Failure function
function Update-Fail {
    # Set error action preference so that errors while ending the script don't end the script prematurely.
    Write-Output 'Set error action preference.'
    $ErrorActionPreference = 'Continue'

    # Set result var for notification and script output
    $result = 'Failure!'

    # Take action based on the stage at which the error occured
    Switch ($fail) {
        download {
            Write-Warning 'Failed to download update.'
        }
        unzip {
            Write-Warning 'Failed to unzip update. Cleaning up and reverting.'
            Remove-Item -Path $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -Force
        }
        rename_old {
            Write-Warning 'Failed to rename old version. Cleaning up and reverting.'
            Remove-Item -Path $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -Force
            Remove-Item -Path $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion -Recurse -Force
        }
        rename_new {
            Write-Warning 'Failed to rename new version. Cleaning up and reverting.'
            Remove-Item -Path $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -Force
            Remove-Item -Path $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion -Recurse -Force
        	Rename-Item $PSScriptRoot\VeeamDiscordNotifications-old $PSScriptRoot\VeeamDiscordNotifications
        }
        after_rename_new {
            Write-Warning 'Failed after renaming new version. Cleaning up and reverting.'
            Remove-Item -Path $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -Force
            Remove-Item -Path $PSScriptRoot\VeeamDiscordNotifications -Recurse -Force
        	Rename-Item $PSScriptRoot\VeeamDiscordNotifications-old $PSScriptRoot\VeeamDiscordNotifications
        }
    }

    # Trigger the Update-Notification function and then End-Script function.
    Invoke-Expression Update-Notification
    Invoke-Expression End-Script
}

# End of script function
function Stop-Script {
    # Clean up.
    Write-Output 'Remove downloaded ZIP.'
    If (Test-Path "$PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip") {
        Remove-Item "$PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip"
    }
    Write-Output 'Remove UpdateVeeamDiscordNotification.ps1.'
    Remove-Item -LiteralPath $PSCommandPath -Force

    # Stop logging
    Write-Output 'Stop logging.'
    Stop-Logging $logFile

    # Move log file
    Write-Output 'Move log file to log directory in VeeamDiscordNotifications.'
    Move-Item $logFile "$PSScriptRoot\VeeamDiscordNotifications\log\"

    # Report result and exit script
    Write-Output "Update result: $result"
    Write-Output 'Exiting.'
    Exit
}

# Pull current config to variable
Try {
	Write-Output 'Pull current config to variable.'
	$currentConfig = (Get-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json
}
Catch {
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    Invoke-Expression Update-Fail
}

# Get currently downloaded version
Try {
    Write-Output 'Getting currently downloaded version of the script.'
    [String]$oldVersion = Get-Content "$PSScriptRoot\VeeamDiscordNotifications\resources\version.txt" -Raw
}
Catch {
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    Invoke-Expression Update-Fail
}

# Wait until the alert sender has finished running, or quit this if it's still running after 60s. It should never take that long.
while (Get-WmiObject win32_process -filter "name='powershell.exe' and commandline like '%DiscordVeeamAlertSender.ps1%'") {
    $timer++
    Start-Sleep -Seconds 1
    If ($timer -eq '60') {
        Write-Output 'Timeout reached. Updater quitting as DiscordVeeamAlertSender.ps1 is still running after 60 seconds.'
    }
    Invoke-Expression Update-Fail
}

# Pull latest version of script from GitHub
Try {
	Write-Output 'Pull latest version of script from GitHub.'
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/download/$LatestVersion/VeeamDiscordNotifications-$LatestVersion.zip -OutFile $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip
}
Catch {
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    $fail = 'download'
    Invoke-Expression Update-Fail
}

# Expand downloaded ZIP
Try {
	Write-Output 'Expand downloaded ZIP.'
	Expand-Archive $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -DestinationPath $PSScriptRoot
}
Catch {
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    $fail = 'unzip'
    Invoke-Expression Update-Fail
}

# Rename old version to keep as a backup while the update is in progress.
Try {
	Write-Output 'Rename old version to make room for the new version.'
	Rename-Item $PSScriptRoot\VeeamDiscordNotifications $PSScriptRoot\VeeamDiscordNotifications-old
}
Catch {
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    $fail = 'rename_old'
    Invoke-Expression Update-Fail
}

# Rename extracted update
Try {
	Write-Output 'Rename extracted update.'
	Rename-Item $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion $PSScriptRoot\VeeamDiscordNotifications
}
Catch {
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    $fail = 'rename_new'
    Invoke-Expression Update-Fail
}

# Pull configuration from new conf file
Try {
	Write-Output 'Pull configuration from new conf file.'
	$newConfig = (Get-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json
}
Catch {
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    $fail = 'after_rename_new'
    Invoke-Expression Update-Fail
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
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    $fail = 'after_rename_new'
    Invoke-Expression Update-Fail
}

# Get newly downloaded version
Try {
	Write-Output 'Get newly downloaded version.'
	[String]$newVersion = Get-Content "$PSScriptRoot\VeeamDiscordNotifications\resources\version.txt" -Raw
}
Catch {
    $errorVar = $_.CategoryInfo.Activity + ' : ' + $_.ToString()
    Write-Output "$errorVar"
    $fail = 'after_rename_new'
    Invoke-Expression Update-Fail
}

# Send notification
If ($newVersion -eq $LatestVersion) {
    Invoke-Expression Update-Success
}
Else {
    Invoke-Expression Update-Fail
}
