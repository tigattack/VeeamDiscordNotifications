Param (
    [string]$LatestVersion
    )
Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/download/$LatestVersion/VeeamDiscordNotifications-$LatestVersion.zip -OutFile C:\VeeamScripts\VeeamDiscordNotifications-$LatestVersion.zip
Expand-Archive C:\VeeamScripts\VeeamDiscordNotifications-$LatestVersion.zip
Remove-Item C:\VeeamScripts\VeeamDiscordNotifications -Recurse -Force
Rename-Item C:\VeeamScripts\VeeamDiscordNotifications-$LatestVersion C:\VeeamScripts\VeeamDiscordNotifications
Remove-Item C:\VeeamScripts\VeeamDiscordNotifications-$LatestVersion.zip
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\DiscordVeeamAlertSender.ps1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\resources\logger.psm1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\UpdateVeeamDiscordNotification.ps1
