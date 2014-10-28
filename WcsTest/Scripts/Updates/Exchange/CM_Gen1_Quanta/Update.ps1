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

#==================================================================================
#  This is an example file showing how to call other update files to update the CM
#  programmables.  You must add your own update scripts and utilities for your 
#  system.
#==================================================================================


$Invocation                =  (Get-Variable MyInvocation -Scope 0).Value
$ThisScriptDirectory       =  (Split-Path $Invocation.MyCommand.Path).ToLower()
$ThisScriptDirectory       =   Split-Path $ThisScriptDirectory  -NoQualifier

$RootUpdateDirectory       = '\updates'
#--------------------------------------------------------------------------------------------------------------------------
# If libraries have not been loaded then load them
#--------------------------------------------------------------------------------------------------------------------------
If ($WCS_UPDATE_ACTION -eq $null)
{
    If ($ThisScriptDirectory.LastIndexOf($RootUpdateDirectory) -ne -1) 
    { 
       $BasePath = "{0}" -f $ThisScriptDirectory.Substring(0,$ThisScriptDirectory.LastIndexOf($RootUpdateDirectory))  

        .  "$BasePath\wcsScripts.ps1"
    }
    Else
    {
       Write-Host "Did not find the root update directory '$RootUpdateDirectory'"
       Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}
#----------------------------------------------------------------------
# Constants specific to this update script
#----------------------------------------------------------------------
$UPDATE_NAME             = 'Chassis Manager'
 
#----------------------------------------------------------------------
# Start a transcript locally.  If one already started then will fail
# and continue to use the original
#----------------------------------------------------------------------
Try
{
   Start-Transcript -Append -Path ".\UpdateTranscript.log" | Out-Null
}
Catch
{
    #NOP:  If fail then a transcript already active from calling function
}
 
#----------------------------------------------------------------------
# Main script
#----------------------------------------------------------------------
Try
{
    $RebootRequired     = $false       # Used to track if any action required at end of update
    $PowerCycleRequired = $false       # Ditto

    #---------------------------------------------------- 
    # Verify a Quanta Chassis Manager (BIOS T6MC*)
    #---------------------------------------------------- 
    $BiosInfo = Get-WmiObject Win32_BIOS

    If (-NOT $BiosInfo.SMBIOSBIOSVersion.StartsWith("T6MC")) 
    { 
        Write-Host -ForegroundColor Red  "`tCannot update service because system is not a WCS Chassis Manager`r`n"
        Return $WCS_RETURN_CODE_NOP
    }
    #---------------------------------------------------- 
    # Display update information for user
    #---------------------------------------------------- 
    Write-Host  ("`r`n$WCS_HEADER_LINE `r`n $UPDATE_NAME update started `r`n$WCS_HEADER_LINE `r"-f (Get-Date)) 

    #----------------------------------------------------------------------
    # Update the Service
    #----------------------------------------------------------------------
    $ReturnCode = & "$ThisScriptDirectory\Service\$WCS_UPDATE_SCRIPTFILE"  
    #----------------------------------------------------------------------
    # Service must return SUCCESS error code since not reboot or power cycle required
    #----------------------------------------------------------------------
    If ($ReturnCode -ne 0)           
    { 
        Write-Host -ForegroundColor Red  ("$WCS_HEADER_LINE `r`n $UPDATE_NAME UPDATE DID NOT COMPLETE: Service Update returned code {0} `r`n$WCS_HEADER_LINE `r"-f $ReturnCode)
        Return $ReturnCode 
    }
    #----------------------------------------------------------------------
    # Update the environment variable and take action if specified
    #----------------------------------------------------------------------
    Write-Host  ("`r`n$WCS_HEADER_LINE `r`n $UPDATE_NAME update completed `r`n$WCS_HEADER_LINE`r"-f (Get-Date)) 

    Return $WCS_RETURN_CODE_SUCCESS
}
#----------------------------------------------------------------------
# Catch any unknown errors and return error
#----------------------------------------------------------------------
Catch
{
    Write-Host -ForegroundColor Red "Unknown error - Exiting `r"  
    Write-Host -ForegroundColor Red  $_     
    Return $WCS_RETURN_CODE_UNKNOWN_ERROR
}
