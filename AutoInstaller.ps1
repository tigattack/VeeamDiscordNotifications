

#CheckUser has webhook url ready
$userprompt = Read-Host -Prompt 'Confimation that you have your webhook URL ready? Y/N'
if ($userprompt -ne 'Y') {
    write-host'Please create your discord channel and generate your webhook before continuing'
    exit
}
    #Clean Up Download
Write-Host'Cleaning up download, please wait'
try {
    Rename-Item C:\VeeamScripts\VeeamDiscordNotifications-v1.5 C:\VeeamScripts\VeeamDiscordNotifications
    Remove-Item C:\VeeamScripts\VeeamDiscordNotifications-v1.5.zip
}
catch {
    write-host'Unable to remove download, please check permissions and try again'
    exit
}

#Assign webhook url to variable
$webhookurl = Read-Host -Prompt 'Please paste your Webhook URL now'

#Read Config File & Write the user webhook
$Config = (Get-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json") -Join "`n" | ConvertFrom-Json
$Config.webhook = $webhookurl
#Write Config
ConvertTo-Json $Config | Set-Content "$PSScriptRoot\VeeamDiscordNotifications\config\conf.json"
 # Unblock script files
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\DiscordVeeamAlertSender.ps1
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\resources\logger.psm1
Unblock-File $PSScriptRoot\VeeamDiscordNotifications\UpdateVeeamDiscordNotification.ps1  


#Display the command for Veeam

Write-Host'Sucsess, copy the following command into Advanced Settings of Each Job you which to have reported.' 
Write-Host'Powershell.exe -File C:\VeeamScripts\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1'
