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
param([switch] $RunDebug)
#-----------------------------------------------------------------------------------------------------
# WinPEBootloader  
#-----------------------------------------------------------------------------------------------------
# This script searches all logical drives for the WCS Test Tool scripts and then...
# ... loads the scripts
# ... runs the WinPe debug function
#
# This script is part of the WinPE image and is run from the RAM drive after boot
# Keep this script simple and small
#-----------------------------------------------------------------------------------------------------
$FoundWinPeDrive = $false

Try
{
    #-----------------------------------------------------------------------------------------------------
    # Check each drive, use the first one found
    #-----------------------------------------------------------------------------------------------------
    Get-WmiObject Win32_LogicalDisk | ForEach-Object {

        #-----------------------------------------------------------------------------------------------------
        # WinPE USB drives have a Volume name of WINPE.  Wcs Test Tools WinPE images also place a file in the 
        # \WcsTest directory to identify the drive contains the Wcs Test Tools
        #-----------------------------------------------------------------------------------------------------
        If (($_.VolumeName -eq 'WINPE') -and  (Test-Path ("{0}\WcsTest\WcsTest_WinPEImage.txt" -f $_.DeviceId)))
        {       
            $FoundWinPeDrive = $true

            #-----------------------------------------------
            # Change the working directory to the new drive
            #-----------------------------------------------
            Set-Location $_.DeviceId
            [System.IO.Directory]::SetCurrentDirectory($_.DeviceId)

            #-----------------------------------------------
            # Load the scripts
            #-----------------------------------------------
            . ("{0}\wcstest\scripts\wcsscripts.ps1" -f $_.DeviceId)

            #-----------------------------------------------
            # Run the Win PE debug function
            #-----------------------------------------------
            If ($RunDebug) { Start-WcsToolsForWinPeDebug }

            #-----------------------------------------------
            # Don't bother checking the rest of the drives
            #-----------------------------------------------
            break
        }
    }
    #-----------------------------------------------------------------------------------------------------
    # Display error message if did not find drive.  Must be corrupted image
    #-----------------------------------------------------------------------------------------------------
    If (-NOT $FoundWinPeDrive)
    {
        Write-Host 'Could not find WinPE drive'
        Write-Host 'Possible corrupted or invalid WinPE image'
    }
}
#-----------------------------------------------------------------------------------------------------
# Display error message if exception occurred.  Must be corrupted image
#-----------------------------------------------------------------------------------------------------
Catch
{
    Write-Host 'Unknown error occurred during the loading of the scripts'
    Write-Host 'Possible corrupted or invalid WinPE image'
}