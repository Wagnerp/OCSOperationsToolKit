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

 
#-------------------------------------------------------------------------------------
# Flush-WcsRaidCache  
#-------------------------------------------------------------------------------------
Function Flush-WcsRaidCache
{
   <#
  .SYNOPSIS
   Flushes the RAID adapter's cache

  .DESCRIPTION
   Flushes the RAID cache using the RAID adapter utility.

   This may result in loss of data if the cache is dirty and a logical 
   disk is missing or failed.  Use with caution.

   Only supports the LSI 9270 RAID adapter

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error

  .EXAMPLE
   Flush-WcsRaidCache

   Flushes the RAID cache.
          
  .COMPONENT
   WCS

  .FUNCTIONALITY
   RAID    

   #>
    [CmdletBinding()]
    Param( )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        Write-Host (" Flushing the RAID cache with {0}`r`n`r" -f $FunctionInfo.Name)

        #-------------------------------------------------------
        # For now the only supported RAID is the LSI 9270
        #-------------------------------------------------------
        Return (Flush-LsiRaidCache -ErrorAction Stop)
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
