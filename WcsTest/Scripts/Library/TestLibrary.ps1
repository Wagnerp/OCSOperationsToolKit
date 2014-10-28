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

Set-Alias -Name posttest  -Value Post-WcsTest
Set-Alias -Name pretest   -Value Pre-WcsTest
#-------------------------------------------------------------------------------------
# Post-WcsTest  
#-------------------------------------------------------------------------------------
Function Post-WcsTest
{
   <#
  .SYNOPSIS
   Logs configuration and error logs for post-test (ALIAS: PostTest)

  .DESCRIPTION
   Logs configuration and reports suspect errors in BMC SEL and Windows System
   Event Log.  Typically used for post test clean up and checking.
   
   The command reports the number of errors found by Check-WcsError  

   Results are stored in \<InstallDir>\Results\<ResultsDirectory>\Post-Test where
   <InstallDir> is typically \WcsTest and <ResultsDirectory> is the input parameter

   Configuration information stored in Get-WcsConfig_<datetime> directory

   BMC SEL and Windows Event Logs are stored in Check-WcsError_<datetime> directory

   .PARAMETER $ResultsDirectory
   Child directory to store the results in.   

   For example, if install directory is \wcstest and $ResultsDirectory is "TEC123"
   the log directory is \wcsTest\Results\TEC123\Post-Test
  
  .PARAMETER IncludeSelFile
   XML file that contains SEL entries to include as suspect errors

   See <InstallDir>\Scripts\References\DataFiles for example file

  .PARAMETER ExcludeSelFile
   XML file that contains SEL entries to exclude as suspect errors

   See <InstallDir>\Scripts\References\DataFiles for example file

  .PARAMETER IncludeEventFile
   XML file that contains Windows System Events to include as suspect errors

   See <InstallDir>\Scripts\References\DataFiles for example file

  .PARAMETER ExcludeEventFile
   XML file that contains Windows System Events to exclude as suspect errors

   See <InstallDir>\Scripts\References\DataFiles for example file

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error

  .EXAMPLE
   Post-WcsTest TEC5000

   Logs configuration and error logs in \<InstallDir>\Results\TEC5000\Post-Test
   where <InstallDir> typically \WcsTest
          
  .COMPONENT
   WCS

  .FUNCTIONALITY
   Test  

   #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    ( 
        [Parameter(Mandatory=$true,Position=0)]                      [string]  $ResultsDirectory,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]      [string]  $IncludeSelFile    =  '',
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]      [string]  $ExcludeSelFile    =  '',
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]      [string]  $IncludeEventFile  =  '',
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]      [string]  $ExcludeEventFile  =  ''
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Create the directory
        #-------------------------------------------------------
        $LogDirectory = "$WCS_RESULTS_DIRECTORY\$ResultsDirectory\Post-Test"
        $ConfigDirectory    = ("$LogDirectory\Get-WcsConfig_{0}"-f (BaseLib_SimpleDate))
        $ErrorDir     = ("$LogDirectory\Check-WcsError_{0}" -f (BaseLib_SimpleDate)) 

        New-Item -Path $ConfigDirectory    -ItemType Container -ErrorAction SilentlyContinue | Out-Null
        New-Item -Path $LogDirectory       -ItemType Container -ErrorAction SilentlyContinue | Out-Null   
        #-------------------------------------------------------------------
        #  Display script header
        #-------------------------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  " Post-WcsTest:  This script will backup and check errors after a test`r"
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  " Log directory $LogDirectory `r`n`r"
        #-------------------------------------------------------------------
        #  Backup and check server errors
        #-------------------------------------------------------------------
        $ReturnCode   = Check-WcsError -LogDirectory $ErrorDir -IncludeEventFile $IncludeEventFile -ExcludeEventFile $ExcludeEventFile -IncludeSelFile $IncludeSelFile -ExcludeSelFile $ExcludeSelFile 
             
        $ReturnCode2  = Log-WcsConfig -Config (Get-WcsConfig) -File PostTestConfig -Path $ConfigDirectory  

        If (($ReturnCode -eq 0) -and ($ReturnCode2 -eq 0))
        {
            Write-Host  "`r`n Post-WcsTest Passed`r`n`r"
            Return $WCS_RETURN_CODE_SUCCESS       
        } 
        Else                                               
        { 
            Write-Host  "`r`n Post-WcsTest Failed`r`n`r" -ForegroundColor Yellow
            Return $ReturnCode +  $ReturnCode2
        }        
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
# Pre-WcsTest 
#-------------------------------------------------------------------------------------
Function Pre-WcsTest()
{
   <#
  .SYNOPSIS
   Logs configuration and clears error logs (ALIAS: pretest)

  .DESCRIPTION
   Logs configuration and clears the BMC SEL and Windows Event Logs.
   Typically run to prepare for a test (pretest)

   Information from msinfo32 and the WCS configuration are logged.
   
   Results are stored in \<InstallDir>\Results\<ResultsDirectory>\Pre-Test where
   <InstallDir> is \WcsTest by default and <ResultsDirectory> is the input parameter

   Configuration information stored in Get-WcsConfig_<datetime> directory

   MsInfo32 information stored in the Log-msinfo32_<datetime> directory.

   .PARAMETER $ResultsDirectory
   Child directory to store the results in.   

   For example, if install directory is \wcstest and $ResultsDirectory is "TEC123"
   the log directory is \wcsTest\Results\TEC123\Pre-Test

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error
    
  .EXAMPLE
   Pre-WcsTest TEC5000

   Logs configuration and error logs in \<InstallDir>\Results\TEC5000\Pre-Test
   where <InstallDir> typically \WcsTest
                
  .COMPONENT
   WCS

  .FUNCTIONALITY
   Test 

   #>

    [CmdletBinding()]
    Param
    (     
        [Parameter(Mandatory=$true)]  [string] $ResultsDirectory
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Create the directory
        #-------------------------------------------------------
        $LogDirectory     = "$WCS_RESULTS_DIRECTORY\$ResultsDirectory\Pre-Test"
        $ConfigDirectory  =  ("$LogDirectory\Get-WcsConfig_{0}" -f (BaseLib_SimpleDate)) 

        New-Item -Path $ConfigDirectory  -ItemType Container -ErrorAction SilentlyContinue | Out-Null
        New-Item -Path $LogDirectory     -ItemType Container -ErrorAction SilentlyContinue | Out-Null    # OK if this one already exists
        #-------------------------------------------------------------------
        #  Display script header
        #-------------------------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  " Pre-WcsTest:  This function prepares the server for a test`r"
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  " Log directory $LogDirectory `r`n`r"
        #-------------------------------------------------------------------
        #  Backup and clear server errors
        #-------------------------------------------------------------------
        $ReturnCode = Clear-WcsError   

        #-------------------------------------------------------------------
        #  Use msinfo32 to log system configuration
        #-------------------------------------------------------------------
        If ( -Not (CoreLib_IsWinPE))
        {
            $ReturnCode2 = Log-MsInfo32   -LogDirectory  ("$LogDirectory\Log-Msinfo32_{0}" -f (BaseLib_SimpleDate))
        }
        Else
        {
            $ReturnCode2 = 0
        }
        #-------------------------------------------------------------------
        #  Log basic system info
        #-------------------------------------------------------------------
        $ReturnCode3 = Log-WcsConfig -Config (Get-WcsConfig) -File PreTestConfig -Path $ConfigDirectory  

        If (($ReturnCode -eq 0) -and ($ReturnCode2 -eq 0) -and ($ReturnCode3 -eq 0))
        {
            Write-Host  "`r`n Pre-WcsTest Passed`r`n`r"
            Return $WCS_RETURN_CODE_SUCCESS       
        } 
        Else                                               
        { 
            Write-Host  "`r`n Pre-WcsTest Failed`r`n`r" -ForegroundColor Yellow
            Return $WCS_RETURN_CODE_UNKNOWN_ERROR   
        }      
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
