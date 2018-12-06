# This function logs messages with a type tag
function Write-LogMessage($tag, $message) {
    Write-Host "[$tag] $message"
}

# This function handles Logging
function Start-Logging($path) {
    try {
        Start-Transcript -path $path -force -append 
        Write-LogMessage -Tag 'Info' -Message "Transcript is being logged to $path"
    } catch [Exception] {
        Write-LogMessage -Tag 'Info' -Message "Transcript is already being logged to $path"
    }
}