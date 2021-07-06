# Check user has webhook URL ready
$userPrompt = Read-Host -Prompt "Do you have your webhook URL ready? Y/N"
if ($userprompt -ne 'Y') {
    Write-Output "Please create a Discord webhook before continuing."
    exit
}
#Create Directory structure
New-Item C:\VeeamScripts -Type directory# Get latest release from GitHub.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$latestRelease = Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/latest -Headers @{"Accept"="application/json"} -UseBasicParsing
# Release IDs are returned in a format of {"id":3622206,"tag_name":"v1.0"} so we need to extract tag_name.
$latestVersion = $latestRelease.Content | ConvertFrom-Json | Select-Object tag_name -ExpandProperty tag_name
# Pull latest version of script from GitHub
Invoke-WebRequest -Uri https://github.com/tigattack/VeeamDiscordNotifications/releases/download/$LatestVersion/VeeamDiscordNotifications-$LatestVersion.zip -OutFile $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip
# Expand downloaded ZIP
Expand-Archive $PSScriptRoot\VeeamDiscordNotifications-$LatestVersion.zip -DestinationPath C:\VeeamScripts

#Assign webhook url to variable
$webhookurl = Read-Host -Prompt "Please paste your Webhook URL now"

#Get the config file and write the user webhook
$Config = (Get-Content C:\VeeamScripts\VeeamDiscordNotifications\config\conf.json) | ConvertFrom-Json
$Config.webhook = $webhookurl
#Write Config
ConvertTo-Json $Config | Set-Content C:\VeeamScripts\VeeamDiscordNotifications\config\conf.json
#Unblock script files
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\DiscordVeeamAlertSender.ps1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\resources\logger.psm1
Unblock-File C:\VeeamScripts\VeeamDiscordNotifications\UpdateVeeamDiscordNotification.ps1


#Display the command for Veeam
Write-Output "Success. Copy the following command into the following area of each job you would like to have reported."
Write-Output "`Job settings -> Storage -> Advanced -> Scripts -> Post-Job Script"
Write-Output "Powershell.exe -ExecutionPolicy Bypass -File C:\VeeamScripts\VeeamDiscordNotifications\DiscordNotificationBootstrap.ps1"
