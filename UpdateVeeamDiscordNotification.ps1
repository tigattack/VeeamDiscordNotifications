Param (
    [string]$LatestVersion
    )
$currentConfig = (Get-Content "C:\VeeamScripts\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json
Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/download/$LatestVersion/VeeamDiscordNotifications-$LatestVersion.zip -OutFile C:\VeeamScripts\VeeamDiscordNotifications-$LatestVersion.zip
Expand-Archive C:\VeeamScripts\VeeamDiscordNotifications-$LatestVersion.zip -DestinationPath C:\VeeamScripts
Remove-Item C:\VeeamScripts\VeeamDiscordNotifications -Recurse -Force
Rename-Item C:\VeeamScripts\VeeamDiscordNotifications-$LatestVersion C:\VeeamScripts\VeeamDiscordNotifications
Remove-Item C:\VeeamScripts\VeeamDiscordNotifications-$LatestVersion.zip
$newConfig = (Get-Content "C:\VeeamScripts\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\DiscordVeeamAlertSender.ps1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\resources\logger.psm1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\UpdateVeeamDiscordNotification.ps1
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
ConvertTo-Json $newConfig | Set-Content "C:\VeeamScripts\VeeamDiscordNotifications\config\conf.json"