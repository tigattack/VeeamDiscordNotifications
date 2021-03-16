# Veeam Backup and Restore Notifications for Discord
Sends notifications from Veeam Backup & Restore to Discord.

Based upon [my fork](https://github.com/tigattack/VeeamSlackNotifications) of [TheSageColleges' original project](https://github.com/TheSageColleges/VeeamSlackNotifications).

## [Setup instructions](https://blog.tiga.tech/veeam-b-r-notifications-in-discord/)

![Chat Example](https://github.com/tigattack/VeeamDiscordNotifications/blob/master/asset/example.png)

## Configuration options
Configuration is set in ./config/conf.json

| Name                 	| Type    	| Required 	| Description                                                                                                        	|
|----------------------	|---------	|----------	|--------------------------------------------------------------------------------------------------------------------	|
| `webhook`            	| string  	| true     	| Your Discord webhook URL.                                                                                          	|
| `thumbnail`          	| string  	| true     	| Image URL for the thumbnail shown in the report embed.                                                             	|
| `userid`             	| string  	| false    	| Your Discord user ID. Only required if either of the following two options are `true`.                             	|
| `mention_on_fail`    	| boolean 	| false    	| When `true`, you will be mentioned when a job finishes in a failed state.                                          	|
| `mention_on_warning` 	| boolean 	| false    	| When `true`, you will be mentioned when a job finishes in a warning state.                                         	|
| `debug_log`          	| boolean 	| false    	| When `true`, the script will log to a file in ./log/                                                               	|
| `auto_update`        	| boolean 	| false    	| When `true`, the script will check for updates on each run and update itself if there's a newer version available. 	|

---
## [Slack fork.](https://github.com/tigattack/VeeamSlackNotifications)
## [MS Teams fork.](https://github.com/tigattack/VeeamTeamsNotifications)
