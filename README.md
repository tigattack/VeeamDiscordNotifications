# Veeam Backup & Replication Notifications for Discord
Sends notifications from Veeam Backup & Replication to Discord.

Based upon [my fork](https://github.com/tigattack/VeeamSlackNotifications) of [TheSageColleges' original project](https://github.com/TheSageColleges/VeeamSlackNotifications).

### Looking for volunteers.

If you enjoy this project and would like to help out, please do so. If you're interested in helping out, contact me on Discord - `tigatack#7987`

As much as I love this project, my free time is all but nonexistent and work is needed to add functionality for different types of jobs than just VM backups and to bring this project in-line with recent changes in Veeam Backup & Replication (VBR) and VBR's PowerShell module.

This is work that I will inevitably get to at some point, but I'd hate to see people left in the lurch with this and would love to have it done sooner rather than later.

## [Setup instructions](https://blog.tiga.tech/veeam-b-r-notifications-in-discord/)

![Chat Example](https://github.com/tigattack/VeeamDiscordNotifications/blob/master/asset/example.png)

## Configuration options
Configuration is set in ./config/conf.json

| Name                 	| Type    	| Description                                                                                                        	|
|----------------------	|---------	|--------------------------------------------------------------------------------------------------------------------	|
| `webhook`            	| string  	| Your Discord webhook URL.                                                                                          	|
| `thumbnail`          	| string  	| Image URL for the thumbnail shown in the report embed.                                                             	|
| `userid`             	| string  	| Your Discord user ID. Only required if either of the following two options are `true`.                             	|
| `mention_on_fail`    	| boolean 	| When `true`, you will be mentioned when a job finishes in a failed state.                                          	|
| `mention_on_warning` 	| boolean 	| When `true`, you will be mentioned when a job finishes in a warning state.                                         	|
| `debug_log`          	| boolean 	| When `true`, the script will log to a file in ./log/                                                               	|
| `auto_update`        	| boolean 	| When `true`, the script will check for updates on each run and update itself if there's a newer version available. 	|

---
## [Slack fork.](https://github.com/tigattack/VeeamSlackNotifications)
## [MS Teams fork.](https://github.com/tigattack/VeeamTeamsNotifications)

## Credits
[MelonSmasher](https://github.com/MelonSmasher)//[TheSageColleges](https://github.com/TheSageColleges) for [the project](https://github.com/TheSageColleges/VeeamSlackNotifications) on which this is based.

[dannyt66](https://github.com/dannyt66) for various things - Assistance with silly little issues, the odd bugfix here and there, and the inspiration and first works on the `UpdateVeeamDiscordNotifications.ps1` script.

[Lee_Dailey](https://reddit.com/u/Lee_Dailey) for general pointers and the original [`ConvertTo-ByteUnit.psm1` function.](https://pastebin.com/srN5CKty)
