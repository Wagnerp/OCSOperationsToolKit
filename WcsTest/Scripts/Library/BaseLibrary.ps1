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

Set-StrictMode -Version Latest                     # Enforce coding rules and best practices

Function VbOn() { $Global:VerbosePreference="Continue"         }
Function VbOff(){ $Global:VerbosePreference="SilentlyContinue" }

Set-Alias -Name wcshelp     -Value Get-WcsHelp
Set-Alias -Name ocshelp     -Value Get-WcsHelp
Set-Alias -Name Get-OcsHelp -Value Get-WcsHelp
Set-Alias -Name View-OcsVersion -Value View-WcsVersion

#-----------------------------------------------------------------------------------------
# Internal Helper Function: Gets string with size and it's unit
#-----------------------------------------------------------------------------------------
Function BaseLib_GetSizeStringXiB( $Size)
{
    If ($Size -gt $WCS_BYTES_IN_TIB)  { Return ("{0:F1} TiB" -f ([double] $Size/ [double] $WCS_BYTES_IN_TIB)) }
    If ($Size -gt $WCS_BYTES_IN_GIB)  { Return ("{0:F1} GiB" -f ([double] $Size/ [double] $WCS_BYTES_IN_GIB)) }
    If ($Size -gt $WCS_BYTES_IN_MIB)  { Return ("{0:F1} MiB" -f ([double] $Size/ [double] $WCS_BYTES_IN_MIB)) }
    
    Return "{0}" -f $Size
}

#-----------------------------------------------------------------------------------------
# Internal Helper Function: Gets string with size and it's unit
#-----------------------------------------------------------------------------------------
Function BaseLib_GetSizeStringXB([int64] $Size)
{
    If ($Size -gt $WCS_BYTES_IN_TB)  { Return "{0:F1} TB" -f ([double] $Size/ [double] $WCS_BYTES_IN_TB) }
    If ($Size -gt $WCS_BYTES_IN_GB)  { Return "{0:F1} GB" -f ([double] $Size/ [double] $WCS_BYTES_IN_GB) }
    If ($Size -gt $WCS_BYTES_IN_MB)  { Return "{0:F1} MB" -f ([double] $Size/ [double] $WCS_BYTES_IN_MB) }
    
    Return "{0}" -f $Size
}
#----------------------------------------------------------------------------------------------
# Internal Helper Function:  Returns date and time in simjple format for file names
#----------------------------------------------------------------------------------------------
Function BaseLib_SimpleDate()
{
    (Get-Date -Uformat "%Y.%m.%d_%H.%M.%S")
}

#----------------------------------------------------------------------------------------------
# Internal Helper Function: Creates a log directory
#----------------------------------------------------------------------------------------------
Function BaseLib_GetLogDirectory($LogDirectory='',$FunctionName="No-Function")
{
    Try
    {
        If ($LogDirectory -eq '')
        {
            $ResultsDirectory = ("{0}\{1}\{2}" -f $WCS_RESULTS_DIRECTORY,$FunctionName,(BaseLib_SimpleDate))
        }
        Else
        {
            $ResultsDirectory =  $LogDirectory 
        }

        New-Item -ItemType Directory $ResultsDirectory -ErrorAction SilentlyContinue | Out-Null

        $ResultsDirectory = (Resolve-Path $ResultsDirectory).Path  # return full path
    }
    Catch
    {
        Throw ("BaseLib_GetLogDirectory failed to create {0}" -f $ResultsDirectory)
    }

    # Return the value
    #---------------------
    $ResultsDirectory    
 }
#----------------------------------------------------------------------------------------------
#  Internal Helper Function: Run a process and wait until it exits or a timeout occurs
#----------------------------------------------------------------------------------------------
Function BaseLib_RunProcessAndWait($Process,$Arguments,$TimeoutInSec=180 )
{
    $TimeoutInMs  = $TimeoutInSec * 1000  

    Try
    {
        $ProcessInfo  = New-Object System.Diagnostics.ProcessStartInfo

        $ProcessInfo.FileName               = $Process
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError  = $true
        $ProcessInfo.Arguments              = $Arguments
        $ProcessInfo.UseShellExecute        = $false
        $ProcessInfo.CreateNoWindow         = $true

        $NewProcess   = New-Object System.Diagnostics.Process

        Unregister-Event -SourceIdentifier "WcsStandardOutput"  -ErrorAction "SilentlyContinue"
        Unregister-Event -SourceIdentifier "WcsErrorOutput"     -ErrorAction "SilentlyContinue"

        Remove-Event     -SourceIdentifier "WcsStandardOutput"  -ErrorAction "SilentlyContinue"
        Remove-Event     -SourceIdentifier "WcsErrorOutput"     -ErrorAction "SilentlyContinue"

        $BackgroundReadOutput = Register-ObjectEvent -InputObject $NewProcess -EventName "OutputDataReceived"  -SourceIdentifier "WcsStandardOutput"
        $BackgroundReadError  = Register-ObjectEvent -InputObject $NewProcess -EventName "ErrorDataReceived"   -SourceIdentifier "WcsErrorOutput"

        $NewProcess.StartInfo  = $ProcessInfo

        $NewProcess.Start() | Out-Null

        $NewProcess.BeginOutputReadLine()
        $NewProcess.BeginErrorReadLine()
         

        if ($NewProcess.WaitForExit($TimeoutInMs) -eq $false) 
        {
            $NewProcess.Kill()
 
            Throw (" {0} did not exit in {1} seconds" -f $Process,$TimeoutInSec)
        }
        
        Start-Sleep -Milliseconds 500

        $CombinedOutput = ""

        Get-Event | Where-Object { ($_.SourceIdentifier -eq "WcsStandardOutput") -or ($_.SourceIdentifier -eq "WcsErrorOutput") } | ForEach-Object { $CombinedOutput += ($_.SourceArgs[1].Data + "`r") }

        Unregister-Event -SourceIdentifier "WcsStandardOutput"-ErrorAction "SilentlyContinue"
        Unregister-Event -SourceIdentifier "WcsErrorOutput"   -ErrorAction "SilentlyContinue"

        Write-Output  @{ExitCode=$NewProcess.ExitCode;Output=$CombinedOutput}
    }
    #------------------------------------------------
    # Command failed so Throw exception with details
    #------------------------------------------------
    Catch
    {
        Write-Verbose ("RunProcessAndWait: `r" + $_.Exception.Message )
        Write-Output  @{ExitCode=-1;Output=$null}
    }
  } 
#----------------------------------------------------------------------------------------------
# Internal Helper Function: Starts a process but does not wait to complete
#----------------------------------------------------------------------------------------------
Function BaseLib_StartProcess($Process,$Arguments,$SourceId )
{
        $StdOut = $SourceId + "StdOut"
        $StdErr = $SourceId + "StdErr"

        $ProcessInfo  = New-Object System.Diagnostics.ProcessStartInfo

        $ProcessInfo.FileName               = $Process
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError  = $true
        $ProcessInfo.Arguments              = $Arguments
        $ProcessInfo.UseShellExecute        = $false
        $ProcessInfo.CreateNoWindow         = $true

        $NewProcess   = New-Object System.Diagnostics.Process

        Unregister-Event -SourceIdentifier $StdOut  -ErrorAction "SilentlyContinue"
        Unregister-Event -SourceIdentifier $StdErr  -ErrorAction "SilentlyContinue"

        Remove-Event     -SourceIdentifier $StdOut  -ErrorAction "SilentlyContinue"
        Remove-Event     -SourceIdentifier $StdErr  -ErrorAction "SilentlyContinue"

        $BackgroundReadOutput = Register-ObjectEvent -InputObject $NewProcess -EventName "OutputDataReceived"  -SourceIdentifier $StdOut
        $BackgroundReadError  = Register-ObjectEvent -InputObject $NewProcess -EventName "ErrorDataReceived"   -SourceIdentifier $StdErr

        $NewProcess.StartInfo  = $ProcessInfo

        $NewProcess.Start() | Out-Null

        $NewProcess.BeginOutputReadLine()
        $NewProcess.BeginErrorReadLine()
         
        Return $NewProcess, $StdOut,$StdErr
}
#-----------------------------------------------------------------------------------------------------------
# Internal Helper Function:  Gets the std out and std error from a process started by BaseLib_StartProcess
#-----------------------------------------------------------------------------------------------------------
Function BaseLib_GetProcessOutput([ System.Diagnostics.Process] $NewProcess,$StdOut,$StdErr,$TimeoutInMs = 30000,[switch] $IgnoreExitCode)
{
        if ($NewProcess.WaitForExit($TimeoutInMs) -eq $false) 
        {
            $NewProcess.Kill()
 
            Write-Host -ForegroundColor Red  (" Process did not exit in {0} seconds`r" -f ($TimeoutInMs / 1000))
        }

        If (-Not $NewProcess.HasExited)
        {
            Return -1,$null
        }

        if (-NOT $IgnoreExitCode -and ($NewProcess.ExitCode -ne 0))
        {
           Write-Host -ForegroundColor Red  (" Process returned error code {0}`r" -f ($NewProcess.ExitCode))
        }       
        
        [string] $CombinedOutput = ""

        if ( ((Get-Date) - $NewProcess.ExitTime).TotalMilliseconds -lt 5000) { Start-Sleep 5 }

        Get-Event | Where-Object { ($_.SourceIdentifier -eq $StdOut) -or ($_.SourceIdentifier -eq $StdErr) } | ForEach-Object { $CombinedOutput += ($_.SourceArgs[1].Data + "`r") }

        Unregister-Event -SourceIdentifier $StdOut   -ErrorAction "SilentlyContinue"
        Unregister-Event -SourceIdentifier $StdErr   -ErrorAction "SilentlyContinue"

        Write-Output $NewProcess.ExitCode, $CombinedOutput     
  }        
 
#-------------------------------------------------------------------------------------
# Get-WcsHelp 
#-------------------------------------------------------------------------------------
Function Get-WcsHelp()
{    
   <#
  .SYNOPSIS
   Displays help on WCS Test Tool commands

  .DESCRIPTION
   Displays help on WCS Test Tool commands

   To display commands for a given function run Get-WcsHelp -<function>.  Example: Get-WcsHelp -Stress

  .EXAMPLE
   Get-WcsHelp

   Displays help info and lists all commands 

  .EXAMPLE
   Get-WcsHelp  -Stress

   Displays help info and lists only stress commands 

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Base

   #>
    Param(
            [switch] $Stress, [switch] $Cycle, [switch] $Remote, [switch] $Base, [switch] $Config, [switch] $Comm, [switch] $Test, [switch] $Error, [switch] $Ipmi, [switch] $Raid
    )

    cls    

    $FunctionalList  = @()

    If ($Stress) { $FunctionalList  += "Stress" }
    If ($Cycle)  { $FunctionalList  += "Cycle" }
    If ($Base)   { $FunctionalList  += "Base" }
    If ($Config) { $FunctionalList  += "Config" }
    If ($Remote) { $FunctionalList  += "Remote" }
    If ($Comm)   { $FunctionalList  += "Comm" }
    If ($Test)   { $FunctionalList  += "Test" }
    If ($Error)  { $FunctionalList  += "Error" }
    If ($Ipmi)   { $FunctionalList  += "Ipmi" }
    If ($RAID)   { $FunctionalList  += "RAID" }

    If ($null -eq $FunctionalList) { $FunctionalList += "*" }

    Write-Output  @"

 Microsoft Windows Cloud Server (WCS) Test Tools are a collection of scripts and utilities used for testing servers.    

    Scripts are located:    $WCS_SCRIPT_DIRECTORY
    Results are located:    $WCS_RESULTS_DIRECTORY 
    User Guide is located:  $WCS_DOC_DIRECTORY


 To display commands for a given function run Get-WcsHelp -<function>.  Example: Get-WcsHelp -Stress

 For more information on a command below run Get-Help <Command>
"@
    Write-Host ("`n`n {0,-25} {1,-15} {2}`r" -f "Command","Function","Synopsis") 
    Write-Host (" {0,-25} {1,-15} {2}`r" -f "-------------------","----------","-----------------------------------------------------------------") 
    Get-Help -Component WCS -Functionality $FunctionalList  | Sort-Object -Property Name | ForEach-Object { 
    
        Write-Host (" {0,-25} {1,-15} {2}`r" -f $_.Name,$_.Functionality,$_.Synopsis) 
    
    }
    Write-Host ("`r`n`r`n`r")

}

#-----------------------------------------------------------------------------------
# View-WcsVersion
#-----------------------------------------------------------------------------------
Function View-WcsVersion()
{
   <#
  .SYNOPSIS
   Displays the version of OCS Tool Set

  .DESCRIPTION
   Displays the version of OCS Tool Set

  .EXAMPLE
   View-WcsVersion

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Base

   #>

    Param()

    Write-Host (" {0,-50} {1} `r`n`r" -f "OCS Tool Set Version",$Global:WcsTestToolsVersion )
}
