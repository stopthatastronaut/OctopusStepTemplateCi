<#
Copyright 2016 ASOS.com Limited

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

<#
.NAME
	Convert-ToOctopusJson.Tests

.SYNOPSIS
	Pester tests for Convert-ToOctopusJson.
#>
Set-StrictMode -Version Latest

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Convert-ToOctopusJson" {
    It "Converts an object into JSON" {
        Convert-ToOctopusJson -InputObject @{test = 1} | % Replace "`r" '' | % Replace "`n" '' | % Replace ' ' '' | Should Be '{"test":1}'
    }
    
    It "Should collapse empty hash tables" {
        Convert-ToOctopusJson -InputObject @{} | Should Be '{}'
    }
    
    It "Should correct escaped single quotes" {
        Convert-ToOctopusJson -InputObject "'" | Should Be "`"'`""
    }

    It "Should not mangle literal strings with whitespace between curly brackets" {
        Convert-ToOctopusJson -InputObject "{    }" | Should Be "`"{    }`""
    }

    It "Should not mangle literal strings that look like unicode character escape sequences" {
        Convert-ToOctopusJson -InputObject "\u0027" | Should Be `""\\u0027`""
    }

}
