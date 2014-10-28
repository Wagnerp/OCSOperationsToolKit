#================================================================================================================================= 
# Copyright © Microsoft Open Technologies, Inc.
# All Rights Reserved
# Licensed under the Apache License, Version 2.0 (the ""License""); 
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at 
# http://www.apache.org/licenses/LICENSE-2.0 
# 
# THIS CODE IS PROVIDED ON AN *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES OR
# CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT. 
# See the Apache 2 License for the specific language governing permissions and limitations under the License.
#================================================================================================================================= 
Param( [string] $Expression="Out-Null", [switch] $IgnoreReturnCode)

Try
{
    $Invocation                   = (Get-Variable MyInvocation -Scope 0).Value
    $WcsScriptDirectory           =  Split-Path $Invocation.MyCommand.Path  
    $WCS_BASE_DIRECTORY           =  Split-Path $WcsScriptDirectory -Parent
    $WCS_BASE_DIRECTORY_NO_DRIVE  =  Split-Path $WCS_BASE_DIRECTORY -NoQualifier

    If ($WCS_BASE_DIRECTORY.Contains(' '))
    {
        Write-Host -ForegroundColor Red -NoNewline "These scripts do not support install directory with a space in the path`r"
    }

#-------------------------------------------------------------------
#  Include all other libraries
#-------------------------------------------------------------------
. "$WCS_BASE_DIRECTORY\Scripts\Library\CoreLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\ConstantDefines.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\CredentialLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\BaseLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\ConfigLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\StressLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\CycleLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\RemoteLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\CommLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\ErrorLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\IpmiLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\TestLibrary.ps1"


. "$WCS_BASE_DIRECTORY\Scripts\Library\RaidLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\LsiLibrary.ps1"
. "$WCS_BASE_DIRECTORY\Scripts\Library\MellanoxLibrary.ps1"

#-------------------------------------------------------------------
#  Load the library specific to this system
#-------------------------------------------------------------------
. "$WCS_BASE_DIRECTORY\Scripts\Library\SystemLookup.ps1"

$Global:ThisSystem = Lookup-WcsSystem 

. "$WCS_BASE_DIRECTORY\Scripts\DefinedSystems\${Global:ThisSystem}.ps1"

    #-------------------------------------------------------------------
    #  Setup command to stop on error
    #-------------------------------------------------------------------
    If (-NOT $Expression.Contains('-ErrorAction')) 
    {
        $Expression += ' -ErrorAction Stop'
    }

    #-------------------------------------------------------------------
    # Run command
    #-------------------------------------------------------------------
    Write-Verbose "Invoke-Remote called with '$Expression'`r"

    $Results = (Invoke-Expression $Expression)

    #-------------------------------------------------------------------
    # Return non-zero if (1) threw error (2) return code not null or 0 
    # and IgnoreReturnCode not true
    #-------------------------------------------------------------------
    If (-NOT $IgnoreReturnCode -and ($null -ne $Results) -and (0  -ne $Results))
    {
       Return ([int] $Results)
    }
    Else
    {
        Return 0
    }             
}
Catch
{
    Return $WCS_RETURN_CODE_UNKNOWN_ERROR 
}

