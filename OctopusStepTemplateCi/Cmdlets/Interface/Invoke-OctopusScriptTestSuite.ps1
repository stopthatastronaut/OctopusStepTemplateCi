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
    Invoke-OctopusScriptTestSuite
    
.SYNOPSIS
    Invokes the Pester tests to validate the Octopus step template / script module

.DESCRIPTION
    This will run the Pester tests written specifically for the step tempate / script module, along with Pester tests to confirm
    that the format of the step template / script module file is in the correct 
    
.PARAMETER Path
    The path to the step template / script module to run the tests against
    
.PARAMETER ResultFilesPath
    The path of the folder to store the Pester results files in

.PARAMETER StepTemplateFilter
    A filter to identify the step template files

.PARAMETER ScriptModuleFilter
    A filter to identify the script module files

.PARAMETER TestSettings
    A hash table of settings for the tests that are run against the script module / step template
    
.PARAMETER SuppressPesterOutput
    Invoke Pester with the 'Quiet' parameter set

.INPUTS
    None. You cannot pipe objects to Invoke-OctopusScriptTestSuite.

.OUTPUTS
    None.
#>
function Invoke-OctopusScriptTestSuite
{

    [CmdletBinding()]
    [OutputType("System.Collections.Hashtable")]
    param
    (

        [Parameter(Mandatory=$false)]
        [ValidateScript({ Test-Path $_ })]
        [string] $Path = $PWD,

        [Parameter(Mandatory=$false)]
        [ValidateScript({ Test-Path $_ })]
        [string] $ResultFilesPath = $PWD,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $StepTemplateFilter = "*.steptemplate.ps1",

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string] $ScriptModuleFilter = "*.scriptmodule.ps1",

        [Parameter(Mandatory=$false)]
        [ValidateNotNull()]
        [hashtable] $TestSettings = @{},

        [Parameter(Mandatory=$false)]
        [switch] $SuppressPesterOutput

    )

    $ErrorActionPreference = "Stop";
    $ProgressPreference = "SilentlyContinue";
    #$VerbosePreference = "Continue";
    Set-StrictMode -Version "Latest";

    write-verbose "*****************************";
    write-verbose "Invoke-OctopusScriptTestSuite";
    write-verbose "*****************************";
    write-verbose "path                   = '$Path'";
    write-verbose "result files path      = '$ResultFilesPath'";
    write-verbose "step template filter   = '$StepTemplateFilter'";
    write-verbose "script module filter   = '$ScriptModuleFilter'";
    write-verbose "test settings          = '$(ConvertTo-PSSource -InputObject $TestSettings)'";
    write-verbose "suppress pester output  = $(ConvertTo-PSSource -InputObject $SuppressPesterOutput)";

    $stepTemplates  = @(Get-ChildItem -Path $Path -File -Recurse -Filter $StepTemplateFilter);
    $scriptModules  = @(Get-ChildItem -Path $Path -File -Recurse -Filter $ScriptModuleFilter);

    $filesToProcess = @($stepTemplates + $scriptModules) | ? Name -NotLike "*.Tests.ps1";

    $allTestResults = @( $filesToProcess | % {

        $sut = $_.FullName;

        # this file is generated by the first set of tests, and used as input in
        # the remaining sets of tests. watch out for $baseResultsFile vs $testResultsFile.
        $baseResultsFile = Join-Path $ResultFilesPath $_.Name.Replace(".ps1", ".TestResults.xml");

        $testScriptFile  = $_.FullName.Replace(".ps1", ".Tests.ps1");
        $testResultsFile = $baseResultsFile;
        $testResults = Invoke-PesterForTeamCity -TestName        $_.Name `
                                                -Script          $testScriptFile `
                                                -TestResultsFile $testResultsFile `
                                                -SuppressPesterOutput:$SuppressPesterOutput;
        write-output $testResults;
        
        $testScriptInfo = @(
            Get-ChildItem -Path (Join-Path (Get-ScriptValidationTestsPath) "\Generic\*.ScriptValidationTest.ps1") -File `
                | % {
                    @{
                        "Path"       = $_.FullName
                        "Parameters" = @{
                            "sut"             = $sut
                            "TestResultsFile" = $baseResultsFile
                            "Settings"        = $TestSettings
                        }
                    }
                }
        );
        $testResultsFile = Join-Path $ResultFilesPath $_.Name.Replace(".ps1", ".generic.TestResults.xml");
        $testResults = Invoke-PesterForTeamCity -TestName        $_.Name `
                                                -Script          $testScriptInfo `
                                                -TestResultsFile $testResultsFile `
                                                -SuppressPesterOutput:$SuppressPesterOutput;
        write-output $testResults;

        if( $_.Name -like $ScriptModuleFilter )
        {
            $testScriptInfo = @(
                Get-ChildItem -Path (Join-Path (Get-ScriptValidationTestsPath) "\ScriptModules\*.ScriptValidationTest.ps1") -File `
                    | % {
                        @{
                            "Path"       = $_.FullName
                            "Parameters" = @{
                                "sut"             = $sut
                                "TestResultsFile" = $baseResultsFile
                                "Settings"        = $TestSettings
                            }
                        }
                    }
            );
            $testResultsFile = Join-Path $ResultFilesPath $_.Name.Replace(".ps1", ".script-module.TestResults.xml");
            $testResults = Invoke-PesterForTeamCity -TestName        $_.Name `
                                                    -Script          $testScriptInfo `
                                                    -TestResultsFile $testResultsFile `
                                                    -SuppressPesterOutput:$SuppressPesterOutput;
            write-output $testResults;
        }
        elseif( $_.Name -like $StepTemplateFilter )
        {
            $testScriptInfo = @(
                Get-ChildItem -Path (Join-Path (Get-ScriptValidationTestsPath) "\StepTemplates\*.ScriptValidationTest.ps1") -File `
                    | % {
                        @{
                            "Path"       = $_.FullName
                            "Parameters" = @{
                                "sut"             = $sut
                                "TestResultsFile" = $baseResultsFile
                                "Settings"        = $TestSettings
                            }
                        }
                    }
            );
            $testResultsFile = Join-Path $ResultFilesPath $_.Name.Replace(".ps1", ".step-template.TestResults.xml");
            $testResults = Invoke-PesterForTeamCity -TestName        $_.Name `
                                                    -Script          $testScriptInfo `
                                                    -TestResultsFile $testResultsFile `
                                                    -SuppressPesterOutput:$SuppressPesterOutput;
            write-output $testResults;
        }

    });

    $testResultTotals = $allTestResults | Measure-Object -Sum -Property @("Passed", "Failed");

    $testResultStats = @{
        "Success" = ($testResultTotals | ? Property -EQ 'Failed' | % Sum | % { $_ -eq 0 })
        "Passed"  = ($testResultTotals | ? Property -EQ 'Passed' | % Sum)
        "Failed"  = ($testResultTotals | ? Property -EQ 'Failed' | % Sum)
    };

    return $testResultStats;

}