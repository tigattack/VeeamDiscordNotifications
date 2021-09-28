# Veeam Backup & Replication Notifications for Discord

Sends notifications from Veeam Backup & Replication to Discord.

## Installing

* Option 1 - Install script
  * Download [Installer.ps1](Installer.ps1).
  * Open PowerShell (as Administrator) and run `C:\path\to\Installer.ps1`.
* Option 2 - Manual install
  * Follow the [setup instructions](https://blog.tiga.tech/veeam-b-r-notifications-in-discord/).

![Chat Example](https://github.com/tigattack/VeeamDiscordNotifications/blob/master/asset/example.png)

### Looking for volunteers

If you enjoy this project and would like to help out, please do so. If you're interested in helping out, contact me on Discord - `tigatack#7987`

As much as I love this project, my free time is all but nonexistent and work is needed to add functionality for different types of jobs than just VM backups and to bring this project in-line with recent changes in Veeam Backup & Replication (VBR) and VBR's PowerShell module.

This is work that I will inevitably get to at some point, but I'd hate to see people left in the lurch with this and would love to have it done sooner rather than later.

## Configuration options

Configuration is set in ./config/conf.json

| Name                 | Type    | Required | Default           | Description                                                                                                |
|--------------------- |-------- |--------- |------------------ | ---------------------------------------------------------------------------------------------------------- |
| `webhook`            | string  | True     | null              | Your Discord webhook URL.                                                                                  |
| `thumbnail`          | string  | False    | See example above | Image URL for the thumbnail shown in the report embed.                                                     |
| `userid`             | string  | False    | null              | Your Discord user ID. Required if either of the following two options are `true`.                          |
| `mention_on_fail`    | boolean | False    | False             | When `true`, you will be mentioned when a job finishes in a failed state. Requires that `userid` is set.   |
| `mention_on_warning` | boolean | False    | False             | When `true`, you will be mentioned when a job finishes in a warning state. Requires that `userid` is set.  |
| `debug_log`          | boolean | False    | False             | When `true`, the script will log to a file in ./log/                                                       |
| `notify_update`      | boolean | False    | True              | When `true`, the script will notify (but not mention) you on Discord if there's a newer version available. |
| `self_update`        | boolean | False    | False             | When `true`, the script will update itself if there's a newer version available.                           |

---

## [Slack fork.](https://github.com/tigattack/VeeamSlackNotifications)

## [MS Teams fork.](https://github.com/tigattack/VeeamTeamsNotifications)

## Credits

[MelonSmasher](https://github.com/MelonSmasher)//[TheSageColleges](https://github.com/TheSageColleges) for [the project](https://github.com/TheSageColleges/VeeamSlackNotifications) on which this is (now loosely) based.

[dannyt66](https://github.com/dannyt66) for various things - Assistance with silly little issues, the odd bugfix here and there, and the inspiration for and first works on the `Updater.ps1` script.

[Lee_Dailey](https://reddit.com/u/Lee_Dailey) for general pointers and the first revision of the [`ConvertTo-ByteUnit` function](https://pastebin.com/srN5CKty).
