

# Check user has webhook URL ready
$userPrompt = Read-Host -Prompt "Do you have your webhook URL ready? Y/N"
if ($userprompt -ne 'Y') {
    Write-Output "Please create a Discord webhook before continuing."
    exit
}
    #Create Directory structure
    New-Item C:\VeeamScripts -Type directory
    $downloadlocation = Read-Host -Prompt "Please Type the full path of your download location including Drive letter"
    Expand-Archive $downloadlocation -DestinationPath C:\VeeamScripts
    Rename-Item C:\VeeamScripts\VeeamDiscordNotifications-v1.5 C:\VeeamScripts\VeeamDiscordNotifications

#Assign webhook url to variable
$webhookurl = Read-Host -Prompt "Please paste your Webhook URL now"

#Read Config File & Write the user webhook
$Config = (Get-Content C:\VeeamScripts\VeeamDiscordNotifications\config\conf.json) | ConvertFrom-Json
$Config.webhook = $webhookurl
#Write Config
ConvertTo-Json $Config | Set-Content C:\VeeamScripts\VeeamDiscordNotifications\config\conf.json
 # Unblock script files
 Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1
 Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\DiscordVeeamAlertSender.ps1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\resources\logger.psm1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\UpdateVeeamDiscordNotification.ps1


#Display the command for Veeam

Write-Host "Sucsess, copy the following command into Advanced Settings of Each Job you which to have reported."
Write-Host "Powershell.exe -File C:\VeeamScripts\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1"
