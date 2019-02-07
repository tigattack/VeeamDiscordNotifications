# Pull version from script trigger
Param (
    [string]$LatestVersion
)
# Import functions
Import-Module "$PSScriptRoot\VeeamDiscordNotifications\resources\logger.psm1"
# Start logging
Start-Logging "$PSScriptRoot\VeeamDiscordNotifications\log\update.log"

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
Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/download/$LatestVersion/VeeamDiscordNotifications-$LatestVersion.zip -OutFile $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip
# Expand downloaded ZIP
Expand-Archive $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -DestinationPath $PSScriptRoot
# Remove old version except log files.
Get-ChildItem $PSScriptRoot\VeeamDiscordNotifications\ -Include *.* -Exclude '*.log*', -File -Recurse | Remove-Item -Force
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

# Clean up.
Remove-Item "$PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip"
Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force
# Stop logging
Stop-Logging "$PSScriptRoot\VeeamDiscordNotifications\log\update.log"
