# $Here = '.'
# Split-Path -Parent $MyInvocation.MyCommand.Path
# $Scripts = Get-ChildItem “$here\” -Filter ‘*.ps1’ -Recurse | Where-Object { $_.name -NotMatch 'pester.ps1’ }
# $Modules = Get-ChildItem “$here\” -Filter ‘*.psm1’ -Recurse
# $Rules = Get-ScriptAnalyzerRule
# Describe ‘Testing all Modules in this Repo to be be correctly formatted’ {
# 	foreach ($module in $modules) {
# 		Context “Testing Module  – $($module.BaseName) for Standard Processing” {
# 			foreach ($rule in $rules) {
# 				It “passes the PSScriptAnalyzer Rule $rule“ {
# 					(Invoke-ScriptAnalyzer -Path $module.FullName -IncludeRule $rule.RuleName).Count | Should -Be 0
# 				}
# 			}
# 		}
# 	}
# }
# Describe ‘Testing all Scripts in this Repo to be be correctly formatted’ {
# 	foreach ($script in $Scripts) {
# 		Context “Testing Module  – $($script.BaseName) for Standard Processing” {
# 			foreach ($rule in $Rules) {
# 				It “passes the PSScriptAnalyzer Rule $rule“ {
# 					(Invoke-ScriptAnalyzer -Path $script.FullName -IncludeRule $rule.RuleName).Count | Should -Be 0
# 				}
# 			}
# 		}
# 	}
# }

# Describe 'Testing against PSSA rules' {
# 	Context 'PSSA Standard Rules' {
# 		$analysis = Invoke-ScriptAnalyzer -Path  '.\DiscordVeeamAlertSender.ps1'
# 		$scriptAnalyzerRules = Get-ScriptAnalyzerRule
# 		forEach ($rule in $scriptAnalyzerRules) {
# 			It "Should pass $rule" {
# 				If ($analysis.RuleName -contains $rule) {
# 					$analysis |
# 						Where RuleName -EQ $rule -OutVariable failures | Out-Default
# 					$failures.Count | Should -Be 0
# 				}
# 			}
# 		}
# 	}
# }

Describe 'PSScriptAnalyzer analysis' {
    $ScriptAnalyzerRules = Get-ScriptAnalyzerRule

    Foreach ( $Rule in $ScriptAnalyzerRules ) {
        It "Should not return any violation for the rule : $($Rule.RuleName)" {
            Invoke-ScriptAnalyzer -Path '.\DiscordVeeamAlertSender.ps1' -IncludeRule $Rule.RuleName |
            Should -BeNullOrEmpty
        }
    }
}
