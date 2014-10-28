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

#-----------------------------------------------------------------------------------------
# Constants specific to all scripts
#-----------------------------------------------------------------------------------------
Set-Variable  -Name WCS_UPDATE_ACTION                       -Value  'WCS_UPDATE_ACTION'  -Option ReadOnly -Force
Set-Variable  -Name WCS_UPDATE_ACTION_NONE                  -Value  'NONE'               -Option ReadOnly -Force
Set-Variable  -Name WCS_UPDATE_ACTION_REBOOT                -Value  'REBOOT'             -Option ReadOnly -Force
Set-Variable  -Name WCS_UPDATE_ACTION_POWERCYCLE            -Value  'POWERCYCLE'         -Option ReadOnly -Force

Set-Variable  -Name WCS_RETURN_CODE_SUCCESS                  -Value ([int] 0)           -Option ReadOnly -Force
Set-Variable  -Name WCS_RETURN_CODE_GENERIC_ERROR            -Value ([int] 0xA0000001)  -Option ReadOnly -Force 
Set-Variable  -Name WCS_RETURN_CODE_UNKNOWN_ERROR            -Value ([int] 0xA0000002)  -Option ReadOnly -Force
Set-Variable  -Name WCS_RETURN_CODE_UPDATE_ERROR             -Value ([int] 0xA0000004)  -Option ReadOnly -Force
Set-Variable  -Name WCS_RETURN_CODE_REBOOT                   -Value ([int] 0xA0000005)  -Option ReadOnly -Force
Set-Variable  -Name WCS_RETURN_CODE_POWERCYCLE               -Value ([int] 0xA0000006)  -Option ReadOnly -Force
Set-Variable  -Name WCS_RETURN_CODE_INCOMPLETE               -Value ([int] 0xA0000010)  -Option ReadOnly -Force
Set-Variable  -Name WCS_RETURN_CODE_INCOMPLETE_REBOOT        -Value ([int] 0xA0000015)  -Option ReadOnly -Force
Set-Variable  -Name WCS_RETURN_CODE_INCOMPLETE_POWERCYCLE    -Value ([int] 0xA0000016)  -Option ReadOnly -Force
Set-Variable  -Name WCS_RETURN_CODE_NOP                      -Value ([int] 0)           -Option ReadOnly -Force

Set-Variable  -Name WCS_RETURN_CODE_FULLPOWERCYCLE           -Value ([int] 0xA0000020)  -Option ReadOnly -Force
 
Set-Variable  -Name WCS_HEADER_LINE                          -Value  ('-' * 70)         -Option ReadOnly -Force
Set-Variable  -Name WCS_NOT_AVAILABLE                        -Value "N/A"  -Option ReadOnly -Force
#-----------------------------------------------------------------------------------------
# Core function that determines if running on WinPe.  If WinPE returns $true 
#-----------------------------------------------------------------------------------------
Function CoreLib_IsWinPE()
{
    Return (Get-ItemProperty  HKLM:\System\ControlSet001\Control).SystemStartOptions.Contains("MININT") 

}
#-----------------------------------------------------------------------------------------
# Core function that formats function info into a hash table
#-----------------------------------------------------------------------------------------
Function CoreLib_FormatFunctionInfo($InvocationInfo)
{
    Try
    {
        $Info = @{ Name    = $InvocationInfo.MyCommand.Name; 
                   Line    = $InvocationInfo.Line.Trim(); 
                   Entry   = $InvocationInfo.PositionMessage.split('+')[0];
                   Inputs  = ''; 
                   Details = ''
                 }

        $InvocationInfo.BoundParameters.GetEnumerator() | ForEach-Object {  $Info.Inputs += ("{0}='{1}'  " -f $_.Key,$_.Value) }

        $Info.Details  = ("[{0} called]`r`n`t+ Called {1}`t+ Called As '{2}'`r`n`t+ Called With Inputs: {3}" -f  $Info.Name,$Info.Entry,$Info.Line,$Info.Inputs)

        Write-Verbose $Info.Details
        Write-Output $Info 
    }
    Catch 
    {
        Write-Output @{ Name='N/A';Line='N/A';Entry='N/A';Inputs  = 'N/A'; Details = 'N/A'}
    }
}
#-----------------------------------------------------------------------------------------
# Core function that writes an entry to a log file.  Prepend with function name and
# date and time,  appends `r for Notepad compatibility if -PassThu used
#-----------------------------------------------------------------------------------------
Function CoreLib_WriteLog([string] $Value='',[string] $FunctionName,[string] $LogFile,[switch] $PassThru)
{
    $OutString = ("[{0}] [{1}] {2}`r" -f (Get-Date -Format G),$FunctionName,$Value)
    Add-Content -Value $OutString -Path $LogFile
    
    If ($PassThru) 
    { 
        Write-Output ($Value + "`r")
    }
}
#--------------------------------------------------------------
# Core function that formats an error record.
#--------------------------------------------------------------
Function CoreLib_FormatException($Exception=$null,$FunctionInfo=@{Name='N/A';Details='N/A'  },[string]$FriendlyErrorMessage='')
{
    #----------------------------------------------
    # Verify Exception exits
    #----------------------------------------------
    If ($null -eq $Exception) 
    {
        Write-Output ''
    }
    Else
    {
        #----------------------------------------------
        # Add friendly error message if details blank
        #----------------------------------------------
        If ($Exception.ErrorDetails -eq $null) 
        {   
            Try
            {
                $Position = $Exception.Exception.ErrorRecord.InvocationInfo.PositionMessage
            }
            Catch
            {
                $Position = $Exception.InvocationInfo.PositionMessage 
            }

            $Exception.ErrorDetails= ("ERROR [{0}] {1}`r`n{2}`r`n{3}" -f  $FunctionInfo.Name,$FriendlyErrorMessage,$Exception.Exception.Message ,$Position)
        }
        #------------------------------------------------------------
        # Add function call details
        #------------------------------------------------------------
        Write-Output ("{0}`r`n{1}`r`n"-f $Exception.ErrorDetails.Message,$FunctionInfo.Details)

        # Write-Output ("{0}`r`n"-f $Exception.ErrorDetails.Message)

    }
}    

 
