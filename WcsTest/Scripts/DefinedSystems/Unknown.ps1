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

 

#-----------------------------------------------------------------------------------------------------------------------
# This file defines functions specific to the Quanta Mt Rainier compute blade for WCS that allow:
#
#  1. Decoding system specific SEL entries
#  2. Displaying physical location of components
#
#-----------------------------------------------------------------------------------------------------------------------

$SystemDefined_EventErrors = $null

#-----------------------------------------------------------------------------------------------------------------------
# Helper function that converts DIMM number to location
#-----------------------------------------------------------------------------------------------------------------------
# Mt Rainier has 12 DIMMS.  This maps DIMM number to physical location.  It also maps the device locator property
# from Win32_PhysicalMemory to physical location because it does not match the board silkscreen.
#-----------------------------------------------------------------------------------------------------------------------
Function DefinedSystem_GetDimmLocation()
{   
    
     Write-Output 'DIMM N/A' 
    
}
#-----------------------------------------------------------------------------------------------------------------------
# Decode of Mt Rainier specific SEL entries.  Refer to the Mt Rainier BIOS and BMC specifications for details
#-----------------------------------------------------------------------------------------------------------------------
Function DefinedSystem_DecodeSelEntry() 
{
    Param
    ( 
        [Parameter(Mandatory=$true)] [ref] $SelEntry, 
                                           $LastSelEntry
    )

    Try
    {
        IpmiLib_DecodeSelEntry  ($SelEntry) 
    }

    #------------------------------------------------------------
    # Default Catch block to handle all errors
    #------------------------------------------------------------
    Catch
    {
        $_.ErrorDetails  = CoreLib_FormatException $_  -FunctionInfo $FunctionInfo
        #----------------------------------------------
        # Take action (do nothing if SilentlyContinue)
        #---------------------------------------------- 
        If      ($ErrorActionPreference -eq 'Stop')             { Throw $_ }
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
    
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR 
    }
}
#-------------------------------------------------------------------------------------
# Helper function that gets disk location
#-------------------------------------------------------------------------------------
Function DefinedSystem_GetDiskLocation()
{
    Param
    (
        [Parameter(Mandatory=$true)]    $DiskInfo,
        [Parameter(Mandatory=$true)]    $EnclosureId,
        [Parameter(Mandatory=$true)]    $SlotId
    )

    Write-Output $DiskInfo.DeviceId
}
#-----------------------------------------------------------------------------------------------------------------------
# Helper function that gets the base FRU inforamtion
#-----------------------------------------------------------------------------------------------------------------------
Function DefinedSystem_GetFruInformation()
{     
    [CmdletBinding()]

    Param( )
    Throw "Reading FRU information is not supported on this system type"
}