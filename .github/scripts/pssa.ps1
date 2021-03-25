# Install PSSA module
Set-PSRepository PSGallery -InstallationPolicy Trusted
Install-Module PSScriptAnalyzer -ErrorAction Stop

# Run PSSA
Invoke-ScriptAnalyzer -Path * -Recurse -OutVariable issues | Out-Null

# Get results and separate types
$errors   = $issues.Where({$_.Severity -eq 'Error' -or $_.Severity -eq 'ParseError'})
$warnings = $issues.Where({$_.Severity -eq 'Warning'})
$infos    = $issues.Where({$_.Severity -eq 'Information'})

# Report results to GitHub Actions
Foreach ($i in $errors) {
  Write-Output "::error file=$($i.ScriptName),line=$($i.Line),col=$($i.Column)::$($i.RuleName) - $($i.Message)"
}
Foreach ($i in $warnings) {
  Write-Output "::warning file=$($i.ScriptName),line=$($i.Line),col=$($i.Column)::$($i.RuleName) - $($i.Message)"
}
Foreach ($i in $infos) {
  Write-Output "There were $($errors.Count) errors, $($warnings.Count) warnings, and $($infos.Count) infos in total." | Format-Table -AutoSize
}
