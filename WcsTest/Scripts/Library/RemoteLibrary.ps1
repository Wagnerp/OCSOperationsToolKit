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
# Internal Helper Function: Gets a valid target from ip, hostname, or object
#-------------------------------------------------------------------------------------
Function GetValidTarget($Target,$PrependHttp=$false,$SSL=$false)
{
    Switch($Target.GetType())
    {
        "string"
        { 
            If ($PrependHttp)
            {
                If ($SSL) { $Target = "https:\\{0}" -f $Target  }
                Else      { $Target = "http:\\{0}"  -f $Target  }
            }
            Write-Verbose "Adding string target '$Target'"
            Return $Target 
            break 
        }
        "hashtable"  
        {
            If ($Target.ContainsKey($WCS_TYPE))
            {
                If ($Target.IP -ne $WCS_NOT_AVAILABLE) 
                { 
                    If ($PrependHttp)
                    {
                        If ($Target.SSL) { $Target = "https:\\{0}" -f $Target.IP }
                        Else             { $Target = "http:\\{0}"  -f $Target.IP }
                        Write-Verbose ("Adding target '{0}'" -f $Target)
                        Return $Target
                    }
                    else
                    {
                        Write-Verbose ("Adding target '{0}'" -f $Target.IP)
                        Return $Target.IP
                    }
                }
                Else
                {
                    Write-Verbose ("Adding target '{0}'" -f $Target.Hostname)
                    Return $Target.Hostname
                }
            }
            Write-Verbose ("Invalid target '{0}' did not have WcsType" -f $Target)
            Return $null
        }
        default
        {
            Write-Verbose ("Invalid target '{0}' has type '{1}'" -f $Target, $Target.GetType())
            Return $null
        }
    }
}
#-------------------------------------------------------------------------------------
# Internal Helper Function: Gets a list of valid targets
#-------------------------------------------------------------------------------------
function GetTargets($TargetList,$PrependHttp=$false,$SSL=$false)
{
    If ($null -eq $TargetList) 
    { 
        Write-Host -ForegroundColor Red  "GetTargets: No targets provided"
        Return $null
    }

    If ($TargetList.GetType().BaseType.Name -eq "Array")
    {
        Write-Verbose ("Adding array of {0} targets " -f $TargetList.Count)
        $ReturnTargets = @()

        ForEach ($Target in $TargetList)
        {
            $NewTarget = (GetValidTarget $Target $PrependHttp $SSL)

            If ($null -eq $NewTarget)
            {
                Write-Host -ForegroundColor Red  ("GetTargets: Target '{0}' not a valid target in list" -f $Target)
                Return $null
            }
            Else
            {
                $ReturnTargets += $NewTarget
            }
        }
    }
    Else
    {
        $NewTarget = (GetValidTarget $TargetList $PrependHttp $SSL)
        If ($null -eq $NewTarget)
        {
            Write-Host -ForegroundColor Red  ("GetTargets: Target '{0}' not a valid target" -f $TargetList)
            Return $null
        }
        $ReturnTargets = [array] $NewTarget
    }  
    Return $ReturnTargets 
}
#-------------------------------------------------------------------------------------
# Internal Helper Function: Copies an entire directory and it's children
#-------------------------------------------------------------------------------------
Function CopyWcsDirectory($Source,$Dest)
{
    Try
    {
        If (-NOT (Test-Path $Dest))
        {
            New-Item $Dest -ItemType Container -Force | Out-Null
        }
        Copy-Item -Path $Source  -Destination $Dest -Recurse -Force -ErrorAction Stop | Out-Null
     
        Return 0

    }
    Catch
    {
        Return 1
    }
}

#-------------------------------------------------------------------------------------
# Internal Helper Function: Reads IP addresses from a file
#-------------------------------------------------------------------------------------
Function Get-IpFromFile($FileName)
{
    Return Get-Content -Path $FileName -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" }
}
#-------------------------------------------------------------------------------------
# Gets the credentials to use for accessing WCS Chassis Manager 
#-------------------------------------------------------------------------------------
Function Set-WcsChassisCredential()
{
 <#
  .SYNOPSIS
   Sets the credentials to use to access WCS Chassis Manager

  .DESCRIPTION
   Sets the credentials to use to access WCS Chassis Manager for the current 
   session.  Must be re-entered each time PowerShell starts.

  .EXAMPLE
   Set-WcsChassisCredential -SetDefault

   Restores the credentials to the defaults

  .EXAMPLE
   Set-WcsChassisCredential -User 'Admin' -Password 'NewPassword'

   Sets new credentials that will be used for all commands that remotely access
   or communicate with chassis managers.

  .PARAMETER SetDefault
   Sets the credentials to the default credentials

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Remote
 
#>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$true)] [string]  $User,
        [Parameter(Mandatory=$true)] [string]  $Password,
                                     [switch]  $SetDefault
    )
    If ($SetDefault) { $Global:ChassisManagerCredential = $Global:ChassisManagerCredential  }
    Else             { $Global:ChassisManagerCredential =  new-object system.management.automation.pscredential($User,  (ConvertTo-SecureString $Password -asPlainText  -Force))}
}

#-------------------------------------------------------------------------------------
# Gets the credentials to use for accessing WCS Blades 
#-------------------------------------------------------------------------------------
Function Set-WcsBladeCredential()
{
 <#
  .SYNOPSIS
   Sets the credentials to use to access WCS Blades

  .DESCRIPTION
   Sets the credentials to use to access WCS Blades for the current session.     
   Must be re-entered each time PowerShell starts.

  .EXAMPLE
   Set-WcsBladeCredential -SetDefault

   Restores the credentials to the defaults

  .EXAMPLE
   Set-WcsBladeCredential -User 'Admin' -Password 'NewPassword'

   Sets new credentials that will be used for all commands that remotely access
   or communicate with WCS blades.

  .PARAMETER SetDefault
   Sets the credentials to the default credentials

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Remote

#>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$true)] [string]  $User,
        [Parameter(Mandatory=$true)] [string]  $Password,
                                     [switch]  $SetDefault
    )
    If ($SetDefault) { $Global:BladeCredential = $Global:BladeDefaultCredential  }
    Else             { $Global:BladeCredential =  new-object system.management.automation.pscredential($User,  (ConvertTo-SecureString $Password -asPlainText  -Force))}
}

#-------------------------------------------------------------------------------------
# Invoke-WcsCommand 
#-------------------------------------------------------------------------------------
Function Invoke-WcsCommand()
{    
<#
  .SYNOPSIS
   Runs a WCS command on one or more remote WCS systems (targets)

  .DESCRIPTION
   Runs a WCS commandon one or more remote WCS systems (targets).  Targets must be 
   specified by their IP address.  
   
   All targets must use the same credentials, be accessible on the network, and have
   the OS configured for remote execution.  

  .EXAMPLE
   Invoke-WcsCommand -TargetList $BladeList -Command 'Log-WcsConfig (Get-WcsConfig) ConfigFile' 

   The above command logs the configuration of all WCS blades in $BladeList to their
   <InstallDir>\Configurations directory

  .PARAMETER TargetList
   List of remote targets to run the script on either as a single IP address or 
   array of IP addresses. Examples:

   192.168.200.10
   @(192.168.200.10, 192.168.200.11)

  .PARAMETER Command
   Command to run enclosed in single quotes

  .PARAMETER Chassis
   If specified uses the default chassis manager credentials.  If not specified uses the default
   blade credentials.

  .PARAMETER WaitTimeInSec
   Time to wait for the command to complete in seconds

  .PARAMETER CommandResults
   Reference to an array holding the exit code returned by the command for each target.  Command typically return
   0 when pass and non-zero when fail.  The array index is the same as the TargetList index.  For example, the 
   result of TargetList[3] is CommandResults[3].

  .OUTPUTS
   Returns number of errors found.  A target that returns an error for the command is considered one error.

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Remote


#>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$true)]                  $TargetList,
        [Parameter(Mandatory=$true)]   [string]       $Command,
        [Parameter(Mandatory=$false)]  [switch]       $Chassis,
        [Parameter(Mandatory=$false)]  [int]          $WaitTimeInSec = 300,
        [Parameter(Mandatory=$false)]  [ref]          $CommandResults
    )

    Try
    {        
        $ErrorCount = 0
        $Credential = $null

        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Get the credentials
        #-------------------------------------------------------
        If ($null -eq $Credential)
        {
            If ($Chassis) { $Credential = $Global:ChassisManagerCredential  }
            Else          { $Credential = $Global:BladeCredential           }
        }                  
        
        $UserName =  $Credential.UserName
        $Password =  $Credential.GetNetworkCredential().Password                 
        #-------------------------------------------------------
        # Get the IPs from the target list
        #-------------------------------------------------------
        $TargetIpList = [array] (GetTargets $TargetList)
        
        If ($CommandResults -ne $null) { $CommandResults.Value = @() }

        $MyProcess    = New-Object 'System.Object[]'   $TargetIpList.Count 
        $MyProcessErr = New-Object 'System.Object[]'   $TargetIpList.Count 
        $MyProcessOut = New-Object 'System.Object[]'   $TargetIpList.Count 
        #---------------------------------------------------------------------
        # Create full path to the script file
        #---------------------------------------------------------------------
        $Script      = "$WCS_SCRIPT_DIRECTORY\invoke-remote.ps1"

        #-------------------------------------------------------
        # Start script on each target, don't wait for it to finish
        #--------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            $PsCommand =  ("\\{0} -accepteula -u {1} -p {2} powershell -command set-content {3} (Get-executionpolicy);set-executionpolicy remotesigned; exit(. $Script '$Command')" -f $TargetIpList[$IpAddress],$UserName,$Password,$WCS_SET_EXECUTION_TEMPFILE)
            Write-Verbose ("Running psexec command '{0}'" -f $PsCommand )
            $MyProcess[$IpAddress], $MyProcessOut[$IpAddress], $MyProcessErr[$IpAddress] =   BaseLib_StartProcess $WCS_PSEXEC64_BINARY $PsCommand 
        }
        #-------------------------------------------------------
        # Wait
        #--------------------------------------------------------
        For ($Timeout=0;$TimeOut -lt $WaitTimeInSec; $Timeout++)
        {
            $AllExited = $true

            For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
            {
                If ($MyProcess[$IpAddress].HasExited -eq $false) { $AllExited = $false }
            }
            If ($AllExited) {break}
            
            Start-Sleep -Milliseconds 500
        }
        #-------------------------------------------------------
        # Check the command finished
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            $ExitCode,$Output = BaseLib_GetProcessOutput $MyProcess[$IpAddress]   $MyProcessOut[$IpAddress]   $MyProcessErr[$IpAddress]  0 -IgnoreExitCode

            If ($CommandResults -ne $null) { $CommandResults.Value += $ExitCode }

            If (0 -ne $ExitCode)   
            {  
                $ErrorCount++
                If ($ExitCode -eq 1326)
                {
                    Write-Host -ForegroundColor Red   ("`t`t[{0}] Failed to complete command, returned code {1}.  Access denied" -f $TargetIpList[$IpAddress],$ExitCode) 
                }
                Else
                {
                    Write-Host -ForegroundColor Red   ("`t`t[{0}] Command returned error code {1}" -f $TargetIpList[$IpAddress],$ExitCode) 
                }
            }
            Else                   
            {  
                Write-Verbose ("`t`t[{0}] Command completed" -f $TargetIpList[$IpAddress]) 
            }
        }

        Return $ErrorCount
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
    
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}
#-------------------------------------------------------------------------------------
# Invoke-WcsScript 
#-------------------------------------------------------------------------------------
Function Invoke-WcsScript()
{    
<#
  .SYNOPSIS
   Runs a WCS PowerShell script on one or more remote WCS systems (targets)

  .DESCRIPTION
   Runs a WCS PowerShell script on one or more remote WCS systems (targets).  Targets must be 
   specified by their IP address.  
   
   All targets must use the same credentials, be accessible on the network, and have
   the OS configured for remote execution.  

  .EXAMPLE
   Invoke-WcsScript -TargetList $ChassisManagerList -Script Updates\BIOS\3A07\Update  

   Updates the BIOS on all the chassis managers in the $ChassisManagerList to 3A07

  .PARAMETER TargetList
   List of remote targets to run the script on.  Single IP address or array of IP addresses

  .PARAMETER Script
   Path to script to run under <InstallDir>.  Default <InstallDir> is \WcsTest.
   Accepts script names with or without .ps1 extension.  For example, 
   to run <InstallDir>\updates\bios\WcsUpdate.ps1 use one of:

      -script updates\bios\WcsUpdate 
      -script updates\bios\WcsUpdate.ps1

  .PARAMETER ScriptArgs
   Arguments to be passed to the script.  If multiple arguments surround in quotes.  For example:

      -ScriptArgs '-arg1 value -arg2 value2'

  .PARAMETER Chassis
   If specified uses the default chassis manager credentials.  If not specified uses the default
   blade credentials.

  .PARAMETER WaitTimeInSec
   Time to wait for the command to complete

  .PARAMETER ScriptResults
   Reference to an array holding the exit code returned by the script for each target.  Scripts typically return
   0 when pass and non-zero when fail.  The array index is the same as the TargetList index.  For example, the 
   result of TargetList[3] is ScriptResults[3].

  .OUTPUTS
   Returns number of errors found.  A target that returns an error for the command is considered one error.

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Remote

#>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    ( 
        [Parameter(Mandatory=$true)]                    $TargetList,
        [Parameter(Mandatory=$true)]     [string]       $Script,
        [Parameter(Mandatory=$false)]    [string]       $ScriptArgs  = "",
        [Parameter(Mandatory=$false)]    [switch]       $Chassis,
        [Parameter(Mandatory=$false)]    [int]          $WaitTimeInSec = 300,
        [Parameter(Mandatory=$false)]    [ref]          $ScriptResults
    )

    Try
    {        
        $ErrorCount = 0
        $Credential = $null
        $Command = "$Script $ScriptArgs"
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation 
 
        #-------------------------------------------------------
        # Get the credentials
        #-------------------------------------------------------
        If ($null -eq $Credential)
        {
            If ($Chassis) { $Credential = $Global:ChassisManagerCredential  }
            Else          { $Credential = $Global:BladeCredential           }
        }                  
        
        $UserName =  $Credential.UserName
        $Password =  $Credential.GetNetworkCredential().Password                 
        #-------------------------------------------------------
        # Get the IPs from the target list
        #-------------------------------------------------------
        $TargetIpList = [array] (GetTargets $TargetList)
        
        If ($ScriptResults -ne $null) { $ScriptResults.Value = @() }

        $MyProcess    = New-Object 'System.Object[]'   $TargetIpList.Count 
        $MyProcessErr = New-Object 'System.Object[]'   $TargetIpList.Count 
        $MyProcessOut = New-Object 'System.Object[]'   $TargetIpList.Count 
        #---------------------------------------------------------------------
        # Create full path to the script file, add .ps1 extension if missing
        #---------------------------------------------------------------------
        $Script =  "$WCS_BASE_DIRECTORY_NO_DRIVE\" + $Script 

        If (-NOT $Script.ToLower().EndsWith(".ps1")) { $Script += ".ps1" }

        #-------------------------------------------------------
        # Start script on each target, don't wait for it to finish
        #--------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            $PsCommand =  ("\\{0} -accepteula -u {1} -p {2} powershell -command `"set-content {3} (Get-executionpolicy);set-executionpolicy remotesigned; exit(. $Script $ScriptArgs)`"" -f $TargetIpList[$IpAddress],$UserName,$Password,$WCS_SET_EXECUTION_TEMPFILE)
            Write-Verbose ("Running psexec command '{0}'" -f $PsCommand )
            $MyProcess[$IpAddress], $MyProcessOut[$IpAddress], $MyProcessErr[$IpAddress] =   BaseLib_StartProcess $WCS_PSEXEC64_BINARY $PsCommand 
        }
        #-------------------------------------------------------
        # Wait
        #--------------------------------------------------------
        For ($Timeout=0;$TimeOut -lt $WaitTimeInSec; $Timeout++)
        {
            $AllExited = $true

            For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
            {
                If ($MyProcess[$IpAddress].HasExited -eq $false) { $AllExited = $false }
            }
            If ($AllExited) {break}
            
            Start-Sleep -Milliseconds 500
        }
        #-------------------------------------------------------
        # Check the command finished
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            $ExitCode,$Output = BaseLib_GetProcessOutput $MyProcess[$IpAddress]   $MyProcessOut[$IpAddress]   $MyProcessErr[$IpAddress]  0 -IgnoreExitCode

            If ($ScriptResults -ne $null) { $ScriptResults.Value += $ExitCode }

            If (0 -ne $ExitCode)   
            {  
                $ErrorCount++
                If ($ExitCode -eq 1326)
                {
                    Write-Host -ForegroundColor Red   ("`t`t[{0}] Failed to complete command, returned code {1}.  Access denied" -f $TargetIpList[$IpAddress],$ExitCode) 
                }
                Else
                {
                    Write-Host -ForegroundColor Red   ("`t`t[{0}] Command returned error code {1}" -f $TargetIpList[$IpAddress],$ExitCode) 
                }
            }
            Else                   
            {  
                Write-Verbose ("`t`t[{0}] Command completed" -f $TargetIpList[$IpAddress]) 
            }
        }
        Return $ErrorCount
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
     
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-------------------------------------------------------------------------------------
# Copy-WcsFile 
#-------------------------------------------------------------------------------------
Function Copy-WcsFile()
{  
<#
  .SYNOPSIS
   Copies  files from the local machine to one or more WCS machines  

  .DESCRIPTION
   Copies  files from the local machine to one or more WCS machines 

  .EXAMPLE
   Copy-WcsFile -TargetList $ListOfIpAddresses -Directory Updates\BIOS_3A07 -Clean

   Copies the files from local directory <InstallDir>\Updates\BIOS_3A07 to all the machines
   listed in $ListOfIpAddresses.  Deletes the remote directories before copying.

   Default <InstallDir> is \WcsTest.

  .PARAMETER TargetList
   List of targets to update

  .PARAMETER Directory
   Directory to copy under <InstallDir>.   Default <InstallDir> is \WcsTest.

   .PARAMETER Chassis
   If specified uses the default chassis manager account.  If not specified uses the default
   blade account.

   .PARAMETER Clean
   If specified deletes the entire directory before copying

   .PARAMETER CopyResults
   Reference to an array holding the result for each target. If copy was successful returns 0, if not 
   successful returns non-zero.  The array index is the same as the TargetList index.  For example, the 
   result of TargetList[3] is CopyResults[3].

  .OUTPUTS
   Returns number of errors found where one error is one target that was not copied to.

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Remote

#>
    [CmdletBinding(PositionalBinding=$false)]  

    Param
    ( 
        [Parameter(Mandatory=$true)]  [array]    $TargetList,
        [Parameter(Mandatory=$true)]  [string]   $LocalDirectory,
        [Parameter(Mandatory=$false)] [string]   $RemoteDirectory='',
                                      [switch]   $Chassis,
                                      [switch]   $Clean,
        [Parameter(Mandatory=$false)] [ref]      $CopyResults
    )


    Try
    {  
        $ErrorCount = 0
        $Credential  = $null

        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation 
        
        #-------------------------------------------------------
        # Get the credentials
        #-------------------------------------------------------
        If ($null -eq $Credential)
        {
            If ($Chassis) { $Credential = $Global:ChassisManagerCredential  }
            Else          { $Credential = $Global:BladeCredential           }
        }                  
        
        $UserName =  $Credential.UserName
        $Password =  $Credential.GetNetworkCredential().Password   
                              
        #-------------------------------------------------------
        # Setup vars and constants
        #-------------------------------------------------------
        $Directory = $LocalDirectory  

        If ('' -eq $RemoteDirectory) 
        {  
            $RemoteDirectory = Split-Path $LocalDirectory.TrimEnd("\*")  -NoQualifier -Resolve -ErrorAction Stop
        }
        
        If (-NOT (Test-Path $Directory)) 
        {
            Write-Host -ForegroundColor Red  "Could not find directory '$Directory' on local machine"
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        
        $TargetIpList = [array] (GetTargets $TargetList) 

        $MyProcess    = New-Object 'System.Object[]'   $TargetIpList.Count 
        $MyProcessErr = New-Object 'System.Object[]'   $TargetIpList.Count 
        $MyProcessOut = New-Object 'System.Object[]'   $TargetIpList.Count 
        #-------------------------------------------------------
        # Read the drives already mapped
        #-------------------------------------------------------
        $NetUseStatus = @{}
        net use | ForEach-Object {

            If ($_.Trim().EndsWith("Microsoft Windows Network"))
            {
               $NetUseStatus[ ($_ -split '\s+')[1] ] = ($_ -split '\s+')[0]     
               Write-Verbose ("Adding '{0}' - Status {1} "-f   ($_ -split '\s+')[1] ,($_ -split '\s+')[0])
            }
        }
        $DriveMapped = New-Object 'System.Object[]'   $TargetIpList.Count  
                               
        #-------------------------------------------------------
        # If not already there start net server
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            $MapDrive = ("\\{0}\c`$" -f $TargetIpList[$IpAddress])
            
            Write-Verbose ("Checking '{0}'" -f $MapDrive)

            If ($NetUseStatus.ContainsKey($MapDrive) -and (Test-Path $MapDrive)) 
            { 
                $DriveMapped[$IpAddress] = $true 
                Write-Verbose ("{0} drive mapped" -f $MapDrive)
            }
            Else
            { 
                $DriveMapped[$IpAddress] = $false                
                $PsCommand =  ("\\{0} -accepteula -u {1} -p {2} net start /Y Server " -f $TargetIpList[$IpAddress],$UserName,$Password)
                Write-Verbose ("Running psexec command '{0}'" -f $PsCommand )
                $MyProcess[$IpAddress], $MyProcessOut[$IpAddress], $MyProcessErr[$IpAddress] =   BaseLib_StartProcess $WCS_PSEXEC64_BINARY $PsCommand
            }
        }
        #-------------------------------------------------------
        # Wait for net start 
        #-------------------------------------------------------
        For ($Timeout=0;$TimeOut -lt 180; $Timeout++)
        {
            $AllExited = $true

            For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
            {
                If (-NOT $DriveMapped[$IpAddress] -and  $MyProcess[$IpAddress].HasExited -eq $false) { $AllExited = $false }
            }
            If ($AllExited) {break}
            
            Start-Sleep -Milliseconds 500
        }
        #-------------------------------------------------------
        # Check that net start finished
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            If (-NOT $DriveMapped[$IpAddress])
            {
                $ExitCode,$Output = BaseLib_GetProcessOutput $MyProcess[$IpAddress]   $MyProcessOut[$IpAddress]   $MyProcessErr[$IpAddress]  0  -IgnoreExitCode   

                # Exit code of 2 means service already running so that is also OK

                If ((0 -ne $ExitCode) -and (2 -ne $ExitCode))   
                { 
                    $ErrorCount++
                    Write-Host -ForegroundColor Red   ("`t`t[{0}] Failed to start net server" -f $TargetIpList[$IpAddress]) 
                }
                Else                   
                { 
                    Write-Verbose ("`t`t[{0}] started net server" -f $TargetIpList[$IpAddress]) 
                }
            }
        }
        #-------------------------------------------------------
        # Map the drive with net use
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            If (-NOT $DriveMapped[$IpAddress])
            {
                $MyProcess[$IpAddress], $MyProcessOut[$IpAddress], $MyProcessErr[$IpAddress] =   BaseLib_StartProcess "net.exe" ("use \\{0}\c`$ {1} /USER:{2} /PERSISTENT:no" -f $TargetIpList[$IpAddress],$Password,$UserName) 
                
                $ExitCode,$Output = BaseLib_GetProcessOutput $MyProcess[$IpAddress]   $MyProcessOut[$IpAddress]   $MyProcessErr[$IpAddress]  -IgnoreExitCode

                If (0 -ne $ExitCode) 
                { 
                    $ErrorCount++
                     Write-Host -ForegroundColor Red   ("`t`t[{0}] Failed to start net use" -f $TargetIpList[$IpAddress]) 
                }
                Else                   
                { 
                    Write-Verbose ("`t`t[{0}] started net use" -f $TargetIpList[$IpAddress]) 
                }
            }
        }
        #-------------------------------------------------------
        # Copy latest files
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            Try
            {
                If ($Clean)
                {
                    Remove-Item  ("\\{0}\c`$$RemoteDirectory" -f $TargetIpList[$IpAddress])  -Recurse -Force  -ErrorAction SilentlyContinue | Out-Null
                }

                If (0 -ne  (CopyWcsDirectory $Directory ("\\{0}\c`$$RemoteDirectory"  -f $TargetIpList[$IpAddress] ))) { Throw "Copy failed" }

                If ($CopyResults -ne $null) { $CopyResults.Value += 0 }                
                Write-Host ("`t`t[{0}] files copied" -f $TargetIpList[$IpAddress]) 
            }
            Catch
            {
                If ($CopyResults -ne $null) { $CopyResults.Value += 1 }

                $ErrorCount++
                Write-Host -ForegroundColor Red   ("`t`t[{0}] Could not copy the files. Check directory name and credentials" -f $TargetIpList[$IpAddress]) 
            }
        }

        Return $ErrorCount
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
  
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}
#-------------------------------------------------------------------------------------
# Copy-WcsRemoteFile 
#-------------------------------------------------------------------------------------
Function Copy-WcsRemoteFile()
{  
<#
  .SYNOPSIS
   Copies files from the one or more remote machines to local machine 

  .DESCRIPTION
   Copies files from the one or more remote machines to local machine

   Copies from remote target's <InstallDir>\$Directory\* to local machine's
   <InstallDir>\RemoteFiles\{Target}\$Directory where {Target} is the IP address or hostname
   of the remote target. 

   Default <InstallDir> is \WcsTest.

  .EXAMPLE
   Copy-WcsRemoteFile -TargetList $ListOfIpAddresses -Directory Updates\BIOS_3A07  

   Copies the files from remote directory \<InstallDir>\Updates\BIOS_3A07 on all the machines
   listed in $ListOfIpAddresses to local machine \<InstallDir>\RemoteFiles\{Target}
   
   For example, if Target is 192.168.200.10 and <InstallDir> is WcsTest then copies to 
   
    \WcsTest\RemoteFiles\192.168.200.10\Updates\BIOS_3A07

  .PARAMETER TargetList
   List of targets to copy files from

  .PARAMETER Directory
   Directory to copy from on the remote targets

   .PARAMETER Chassis
   If specified uses the default chassis manager credentials.  If not specified uses the default
   blade credentials.

   .PARAMETER Clean
   If specified deletes the entire local machines directory before copying

   .PARAMETER CopyResults
   Reference to an array holding the result for each target. If copy was successful returns 0, if not 
   successful returns non-zero.  The array index is the same as the TargetList index.  For example, the 
   result of TargetList[3] is CopyResults[3].

  .OUTPUTS
   Returns number of errors found where one error is one target that was not copied from.

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Remote
#>
    [CmdletBinding(PositionalBinding=$false)]  

    Param
    ( 
        [Parameter(Mandatory=$true)] [array]         $TargetList,
        [Parameter(Mandatory=$true)] [string]        $RemoteDirectory,
        [Parameter(Mandatory=$false)][ref]           $CopyResults,
                                     [switch]        $Chassis,
                                     [switch]        $Clean
    )
    Try
    {  
        $ErrorCount = 0
        $Credential  = $null
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Get the credentials
        #-------------------------------------------------------
        If ($null -eq $Credential)
        {
            If ($Chassis) { $Credential = $Global:ChassisManagerCredential  }
            Else          { $Credential = $Global:BladeCredential           }
        }                  
        
        $UserName =  $Credential.UserName
        $Password =  $Credential.GetNetworkCredential().Password                      
        #-------------------------------------------------------
        # Get the IPs from the target list
        #-------------------------------------------------------              
        $TargetIpList = [array] (GetTargets $TargetList) 

        $MyProcess    = New-Object 'System.Object[]'   $TargetIpList.Count 
        $MyProcessErr = New-Object 'System.Object[]'   $TargetIpList.Count 
        $MyProcessOut = New-Object 'System.Object[]'   $TargetIpList.Count 
        #-------------------------------------------------------
        # Read the drives already mapped
        #-------------------------------------------------------
        $NetUseStatus = @{}
        net use | ForEach-Object {

            If ($_.Trim().EndsWith("Microsoft Windows Network"))
            {
               $NetUseStatus[ ($_ -split '\s+')[1] ] = ($_ -split '\s+')[0]     
               Write-Verbose ("Adding '{0}' - Status {1} "-f   ($_ -split '\s+')[1] ,($_ -split '\s+')[0])
            }
        }
        $DriveMapped = New-Object 'System.Object[]'   $TargetIpList.Count  
                               
        #-------------------------------------------------------
        # If not already there start net server
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            $MapDrive = ("\\{0}\c`$" -f $TargetIpList[$IpAddress])
            
            Write-Verbose ("Checking '{0}'" -f $MapDrive)

            If ($NetUseStatus.ContainsKey($MapDrive) -and (Test-Path $MapDrive)) 
            { 
                $DriveMapped[$IpAddress] = $true 
                Write-Verbose ("{0} drive mapped" -f $MapDrive)
            }
            Else
            { 
                $DriveMapped[$IpAddress] = $false                
                $PsCommand =  ("\\{0} -accepteula -u {1} -p {2} net start /Y Server " -f $TargetIpList[$IpAddress],$UserName,$Password)
                Write-Verbose ("Running psexec command '{0}'" -f $PsCommand )
                $MyProcess[$IpAddress], $MyProcessOut[$IpAddress], $MyProcessErr[$IpAddress] =   BaseLib_StartProcess $WCS_PSEXEC64_BINARY $PsCommand
            }
        }
        #-------------------------------------------------------
        # Wait for net start 
        #-------------------------------------------------------
        For ($Timeout=0;$TimeOut -lt 180; $Timeout++)
        {
            $AllExited = $true

            For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
            {
                If (-NOT $DriveMapped[$IpAddress] -and  $MyProcess[$IpAddress].HasExited -eq $false) { $AllExited = $false }
            }
            If ($AllExited) {break}
            
            Start-Sleep -Milliseconds 500
        }

        #-------------------------------------------------------
        # Check that net start finished
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            If (-NOT $DriveMapped[$IpAddress])
            {
                $ExitCode,$Output = BaseLib_GetProcessOutput $MyProcess[$IpAddress]   $MyProcessOut[$IpAddress]   $MyProcessErr[$IpAddress]  0  -IgnoreExitCode   

                # Exit code of 2 means service already running so that is also OK

                If ((0 -ne $ExitCode) -and (2 -ne $ExitCode))   
                { 
                    $ErrorCount++
                    Write-Host -ForegroundColor Red   ("`t`t[{0}] Failed to start net server" -f $TargetIpList[$IpAddress]) 
                }
                Else                   
                { 
                    Write-Verbose ("`t`t[{0}] started net server" -f $TargetIpList[$IpAddress]) 
                }
            }
        }

        #-------------------------------------------------------
        # Map the drive with net use
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            If (-NOT $DriveMapped[$IpAddress])
            {
                $MyProcess[$IpAddress], $MyProcessOut[$IpAddress], $MyProcessErr[$IpAddress] =   BaseLib_StartProcess "net.exe" ("use \\{0}\c`$ {1} /USER:{2} /PERSISTENT:no" -f $TargetIpList[$IpAddress],$Password,$UserName) 
                
                $ExitCode,$Output = BaseLib_GetProcessOutput $MyProcess[$IpAddress]   $MyProcessOut[$IpAddress]   $MyProcessErr[$IpAddress]  -IgnoreExitCode

                If (0 -ne $ExitCode) 
                { 
                    $ErrorCount++
                     Write-Host -ForegroundColor Red   ("`t`t[{0}] Failed to start net use" -f $TargetIpList[$IpAddress]) 
                }
                Else                   
                { 
                    Write-Verbose ("`t`t[{0}] started net use" -f $TargetIpList[$IpAddress]) 
                }
            }
        }
        #-------------------------------------------------------
        # Copy latest files
        #-------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            Try
            {
                If ($Clean)
                {
                    Remove-Item  ("$WCS_REMOTE_RESULTS_DIRECTORY\{0}\$RemoteDirectory" -f $TargetIpList[$IpAddress])  -Recurse -Force  -ErrorAction SilentlyContinue | Out-Null
                }

                If (0 -ne (CopyWcsDirectory ("\\{0}\c`$$RemoteDirectory" -f $TargetIpList[$IpAddress] )   ("$WCS_REMOTE_RESULTS_DIRECTORY\{0}\$RemoteDirectory" -f  $TargetIpList[$IpAddress] )))   { Throw "Copy failed" }

                If ($CopyResults -ne $null) { $CopyResults.Value += 0 }   
                             
                Write-Host ("`t`t[{0}] files copied" -f $TargetIpList[$IpAddress]) 
            }
            Catch
            {
                If ($CopyResults -ne $null) { $CopyResults.Value += 1 }

                $ErrorCount++
                Write-Host -ForegroundColor Red     ("`t`t[{0}] Could not copy the files.  Check directory name and credentials" -f $TargetIpList[$IpAddress]) 
            }
        }

        Return $ErrorCount
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
  
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#----------------------------------------------------------------------------------------------
# Get-Subnet 
#----------------------------------------------------------------------------------------------
Function Get-Subnet() {

   <#
  .SYNOPSIS
   Gets dynamic IP and MAC addresses on a subnet

  .DESCRIPTION
   Gets dynamic IP and MAC addresses on a subnet. If subnet not specified then
   uses 192.168.xxx.xxx

   Returns a hash table with IP addresses as value and MAC as key and another
   hash table with MAC addresses as value and IP as key

  .EXAMPLE
   $IpAddressByMac,$MacAddressByIp = Get-Subnet

   Reads the current server configuration and stores in $IpAddressByMac,$MacAddressByIp

   $IpAddressByMac[$MacAddress] returns the IP associated with $MacAddress
   $MacAddressByIP[$IPAddress] returns the MAC associated with $IpAddress

  .PARAMETER Subnet
   Subnet to get

  .OUTPUTS
   Two hash tables, one with MAC addresses and other with IP addresses

   #>

    [CmdletBinding()]

    Param
    ( 
        [string] $Subnet       = "192.168" 
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #--------------------------------------------------------
        # Get the interface to search based on specified subnet
        #--------------------------------------------------------
        $NicInterface = $null

        (arp -a) | Where-Object { $_.Contains("Interface:") } | ForEach-Object {
                         
            Write-Verbose "Found NIC interface $_`r" 

            if ( ($_.split()[1]).StartsWith($Subnet))
            {
                if ($null -ne $NicInterface)
                {
                    Throw ("Host PC has more than one private network {0} {1}" -f $NicInterface, ($_.split()[1]))
                }
                $NicInterface = ($_.split()[1])               
            }
        }
        if ($null -eq $NicInterface)
        {
            Throw "Did not find NIC interface"
        }

        Write-Verbose ("Using NIC interface: $NicInterface`r")
        #-------------------------------------------------------
        # Get the dynamic IP and MAC addresses on the interface
        #-------------------------------------------------------
        $SubnetIpAddresses  = @{}
        $SubnetMacAddresses = @{}

        (arp -a -N $NicInterface) | Where-Object { $_ -ne $null } | ForEach-Object {
        
            $InputLine = ($_ -split '\s+')

            If (($InputLine.Count -ge 4) -and  ($InputLine[3] -eq "dynamic"))
            {
                #---------------------------------------------------------
                # Create hash table where key is the MAC and value is IP
                #---------------------------------------------------------
                $MacAddress = (($_ -split '\s+')[2]).ToString()
                $IpAddress  = (($_ -split '\s+')[1]).ToString()
                $SubnetMacAddresses[$IpAddress]= $MacAddress
                $SubnetIpAddresses[$MacAddress]= $IpAddress

                Write-Verbose ("Adding IP address {0} with MAC {1}`r" -f $IpAddress, $MacAddress)
            }
        }
        Write-Output  $SubnetIpAddresses,$SubnetMacAddresses
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
    }
}

#----------------------------------------------------------------------------------------------
# Get-WcsChassis
#----------------------------------------------------------------------------------------------
Function Get-WcsChassis()
{
   <#
  .SYNOPSIS
   Returns WCS chassis managers on a network subnet [Internal Evaluation Only]

  .DESCRIPTION
   Searches the specified subnet for all chassis managers.  If not subnet specified then
   searches the default subnet

   Returns one or more chassis manager XML objects.  To view chassis managers on a 
   subnet use View-WcsChassis

  .EXAMPLE
   $AllChassis = Get-WcsChassis

   Stores all chassis managers on default subnet in the variable $AllChassis

  .EXAMPLE
   $ChassisManagers = Get-WcsChassis -subnet "192.168.200"

   Stores all chassis managers on 192.168.200 subnet into the $ChassisManagers
   variable. 

  .PARAMETER Subnet
   IPV4 subnet to search. For example "192.168.200".  

  .PARAMETER Credential
   Powershell Credentials to use.  If not specified uses the default.

  .PARAMETER TimeoutInMs
   Time to wait for an IP address to respond to REST command

  .PARAMETER Quiet
   If specified then suppresses output.  Useful when running inside another script that
   manages output

  .PARAMETER NoDrive
   If specified then does not map the c: of the chassis manager

  .OUTPUTS
   Array of chassis manager objects

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$false,Position=0)] [string]        $Subnet          = "192.168",
        [Parameter(Mandatory=$false)]                            $Credential      = $Global:ChassisManagerCredential,
        [Parameter(Mandatory=$false)]            [int]           $TimeOutInMs     = 15000,
                                                 [switch]        $Quiet
   )
 
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        $ChassisManagers = @()

        #-----------------------------------------
        # Get the IP addresses
        #-----------------------------------------
        $IpAddressByMac,$MacAddressesByIp  = Get-Subnet -Subnet $Subnet

        If ($null -eq $IpAddressByMac)
        {
            Write-Host -ForegroundColor Red   ("Did not find any IP address on subnet '$Subnet'`r")
            Return $null
        }
        $IpAddresses = $IpAddressByMac.Values
        Write-Verbose  ("Looking for chassis managers on subnet $Subnet`r")

        #---------------------------------------------------------------------------------------------------------------------------
        # For each IP ask if it is chassis manager, suppress error messages since some IP are not chassis managers and will error
        #---------------------------------------------------------------------------------------------------------------------------
        $httpsResponders  = [array] ( Invoke-WcsRest  -Target $IpAddresses  -Command "GetServiceVersion?" -TimeoutInMs $TimeoutInMs -Asynchronous  -SSL  -ErrorAction SilentlyContinue )
        $httpResponders   = [array] ( Invoke-WcsRest  -Target $IpAddresses  -Command "GetServiceVersion?" -TimeoutInMs 5000         -Asynchronous        -ErrorAction SilentlyContinue )
        #-----------------------------------------------------------------------
        # Check which IP addresses responded, add those that responded to list
        #----------------------------------------------------------------------
        $Index = 0

        $IpAddresses | Where-Object { $_ -ne $null } |  ForEach-Object {
             
            if (($null -ne $httpResponders) -and ($null -ne $httpResponders[$Index]))
            {

# Add check for valid response

                $ChassisManagers     += $WCS_CHASSISMANAGER_OBJECT.Clone()  # Clone hashtables in powershell so copy values not ref
                $CurrentChassis       =  $ChassisManagers.Count - 1

                $ChassisManagers[$CurrentChassis].IP             = $_
                $ChassisManagers[$CurrentChassis].ActiveMAC      = $MacAddressesByIp[$_]
                $ChassisManagers[$CurrentChassis].Service        = $httpResponders[$Index].ServiceVersionResponse.ServiceVersion
                $ChassisManagers[$CurrentChassis].SSL            = $false
                
                Write-Verbose  ("Found chassis manager at {0}  MAC {1} Version {2} `r" -f $_,$MacAddressesByIp[$_],$httpResponders[$Index].ServiceVersionResponse.ServiceVersion)
            }

            if (($null -ne $httpsResponders) -and ($null -ne $httpsResponders[$Index]))
            {
                $ChassisManagers     += $WCS_CHASSISMANAGER_OBJECT.Clone()  # Clone hashtables in powershell so copy values not ref
                $CurrentChassis       =  $ChassisManagers.Count - 1
# Add check for valid response

                $ChassisManagers[$CurrentChassis].IP             = $_
                $ChassisManagers[$CurrentChassis].ActiveMAC      = $MacAddressesByIp[$_]
                $ChassisManagers[$CurrentChassis].Service        = $httpsResponders[$Index].ServiceVersionResponse.ServiceVersion
                $ChassisManagers[$CurrentChassis].SSL            = $true

                Write-Verbose  ("Found chassis manager at {0} (https) MAC {1} Version {2}`r" -f $_,$MacAddressesByIp[$_],$httpsResponders[$Index].ServiceVersionResponse.ServiceVersion)
            }
            $Index++
        }        
        #----------------------------------------------------------------------
        # If not chassis managers found then return
        #----------------------------------------------------------------------
        If ($null -eq $ChassisManagers) 
        {
            Write-Host -ForegroundColor Red   ("Did not find any chassis managers on subnet '$Subnet'`r")
            Return $null
        }

        #----------------------------------------------------------------------
        # Get additional chassis information 
        #----------------------------------------------------------------------
        $ChassisInfoResponse   = [array] (Invoke-WcsRest -Target $ChassisManagers -Command "GetChassisInfo" -Async)

        If ($null -eq $ChassisInfoResponse) 
        {
            Write-Host -ForegroundColor Red   ("Failed to get ChassisInfo`r")
            Return $null
        }

        $ChassisHealthResponse = [array] (Invoke-WcsRest -Target $ChassisManagers -Command "GetChassisHealth" -Async )

        If ($null -eq $ChassisHealthResponse) 
        {
            Write-Host -ForegroundColor Red   ("Failed to get ChassisHealth`r")
            Return $null
        }


        $Chassis = 0
        $ChassisManagersIP = @()
        $ChassisManagers | Where { $_ -ne $null} | ForEach-Object { $ChassisManagersIP += $_.IP }

        $ChassisManagersIP | Where-Object { $_ -ne  $null }  | ForEach-Object {

            $ChassisManagers[$Chassis].Info     =  $ChassisInfoResponse[$Chassis] 
            $ChassisManagers[$Chassis].Health   =  $ChassisHealthResponse[$Chassis] 

 # check for null response here too

            $ChassisManagers[$Chassis].AssetTag =  $ChassisManagers[$Chassis].Info.ChassisInfoResponse.ChassisController.AssetTag   
            $ChassisManagers[$Chassis].MAC1     =  ($ChassisManagers[$Chassis].Info.ChassisInfoResponse.ChassisController.NetworkProperties.ChassisNetworkPropertyCollection.ChassisNetworkProperty[0].MacAddress).Replace(':','-').ToLower()
            $ChassisManagers[$Chassis].MAC2     =  ($ChassisManagers[$Chassis].Info.ChassisInfoResponse.ChassisController.NetworkProperties.ChassisNetworkPropertyCollection.ChassisNetworkProperty[1].MacAddress ).Replace(':','-').ToLower()

            If ($ChassisManagers[$Chassis].MAC1  -eq  $ChassisManagers[$Chassis].ActiveMAC)
            {
                $ChassisManagers[$Chassis].HostName = $ChassisManagers[$Chassis].Info.ChassisInfoResponse.ChassisController.NetworkProperties.ChassisNetworkPropertyCollection.ChassisNetworkProperty[0].dnsHostName
            }
            ElseIf ($ChassisManagers[$Chassis].MAC2 -eq  $ChassisManagers[$Chassis].ActiveMAC)
            {
                $ChassisManagers[$Chassis].HostName = $ChassisManagers[$Chassis].Info.ChassisInfoResponse.ChassisController.NetworkProperties.ChassisNetworkPropertyCollection.ChassisNetworkProperty[1].dnsHostName
            }
            Else
            {
                $ChassisManagers[$Chassis].Error = "ERROR: Could not match MACs. "
            }
 
            $UserName =  $ChassisManagerCredential.UserName
            $Password =  $ChassisManagerCredential.GetNetworkCredential().Password   

            $MyProcess , $MyProcessOut , $MyProcessErr  =   BaseLib_StartProcess "net.exe" ("use \\{0}\c`$ /DELETE /Yes" -f $_ )        
            $ExitCode,$Output = BaseLib_GetProcessOutput $MyProcess  $MyProcessOut  $MyProcessErr -IgnoreExitCode

            $MyProcess , $MyProcessOut , $MyProcessErr  =   BaseLib_StartProcess "net.exe" ("use \\{0}\c`$ {1} /USER:{2} /PERSISTENT:no" -f $_ ,$Password,$UserName)        
            $ExitCode,$Output = BaseLib_GetProcessOutput $MyProcess  $MyProcessOut  $MyProcessErr -IgnoreExitCode

            If (0 -eq $ExitCode) 
            {
                $ChassisManagers[$Chassis].Drive   =  ("\\{0}\c`$" -f $_)
            }
            Else
            {
                $ChassisManagers[$Chassis].Error += "ERROR: Could not map drive. "
            }

            $Chassis++
        }

        If (-NOT $Quiet) { View-WcsChassis -ChassisManagers $ChassisManagers | Out-Null }


        Return ([array] $ChassisManagers) 
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
    }
}

#----------------------------------------------------------------------------------------------
# Get-WcsBlade
#----------------------------------------------------------------------------------------------
Function Get-WcsBlade()
{
   <#
  .SYNOPSIS
   Returns all WCS blades connected to one ore more chassis [Internal Evaluation Only] 

  .DESCRIPTION
   Returns the blades connected to the specified chassis. If no chassis specified searches
   the default subnet for all chassis and then returns the blades connected to them,

  .EXAMPLE
   Get-WcsBlade

   Returns all chassis managers on default subnet in XML object

  .EXAMPLE
   Get-WcsBlade -Chassis $CM0

   Returns all blades connected to $CM0

  .PARAMETER ChassisManager
   One or more chassis manager objects

  .PARAMETER SubnetIpAddresses
   Hash table with IP and MAC addresses for a subnet returned by the Get-Subnet command

  .OUTPUTS
   Array of blade objects

   #>
    
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (                
        [Parameter(Mandatory=$false,Position=0)] [array]         $ChassisManagers = $null,
        [Parameter(Mandatory=$false,Position=1)] [string]        $Subnet          = "192.168",
        [Parameter(Mandatory=$false)]                            $Credential      = $Global:BladeCredential,
                                                 [switch]        $Quiet,
                                                 [switch]        $Full
    )
 
    Try
    {
        $Blades = @()
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
 

        $SubnetIPAddresses,$SubnetMacAddresses = Get-Subnet $Subnet
        If ($null -eq $SubnetIPAddresses)
        {
            Write-Host -ForegroundColor Red   ("No IP addresses found`r")
            Return @()
        }

        #-----------------------------------------
        # If not given chassis managers find them
        #-----------------------------------------
        If ($null -eq $ChassisManagers)
        {
            $ChassisManagers = [array] ( Get-WcsChassis -Quiet -Subnet $Subnet)
            If ($null -eq $ChassisManagers)        
            {           
                Write-Host -ForegroundColor Red   ("No chassis managers found`r")
                Return @()
            }
        }      

        Write-Host (" Found {0} chassis managers`r" -f $ChassisManagers.Count)
        #-----------------------------------------------------
        # For each slot on each chassis check for a blade
        #-----------------------------------------------------
        $IP    = New-Object 'object[,]'   $ChassisManagers.Count,$WCS_BLADES_PER_CHASSIS

        $TotalBladeIndex = 0

        For ($Chassis = 0; $Chassis -lt $ChassisManagers.Count; $Chassis++)
        {
            If ($ChassisManagers[$Chassis].WcsObject -ne $WCS_TYPE_CHASSIS)
            {
                Write-Host -ForegroundColor Red  "Illegal chassis type`r"
                Return @()
            }


            For ($BladeSlot=1;$BladeSlot -le $WCS_BLADES_PER_CHASSIS; $BladeSlot++)
            {    
                
                $BladeIP    = $null
                $BladeIndex = $BladeSlot - 1 #Slots count from 1 but arrays count from 0

                $BladeId    = $ChassisManagers[$Chassis].Info.ChassisInfoResponse.BladeCollections.BladeInfo[$BladeIndex].BladeNumber
                $BladeState = $ChassisManagers[$Chassis].Health.ChassisHealthResponse.BladeShellCollection.BladeShellResponse[ ($BladeId - 1 )].BladeState
                        
                $IP[$Chassis,$BladeIndex] = $WCS_NOT_AVAILABLE
                
                If ($Full)
                {
                    $Blades                                 += $WCS_BLADE_OBJECT.Clone()
                    $TotalBladeIndex                         = $Blades.Count - 1

                    $Blades[$TotalBladeIndex].Slot           = $BladeId
                    $Blades[$TotalBladeIndex].ChassisMac     = $ChassisManagers[$Chassis].ActiveMAC
                    $Blades[$TotalBladeIndex].State          = $BladeState
                    $Blades[$TotalBladeIndex].ChassisId      = ("{0} at  IP {1}   {3}" -f $ChassisManagers[$Chassis].Hostname,$ChassisManagers[$Chassis].IP, $ChassisManagers[$Chassis].ActiveMAC,$ChassisManagers[$Chassis].Error)
                }

                If ("Healthy" -eq  $BladeState) {   

                        $MAC = ($ChassisManagers[$Chassis].Info.ChassisInfoResponse.BladeCollections.BladeInfo[$BladeIndex].BladeMacAddress.NicInfo[0].MacAddress).Replace(":","-").ToLower()
                        $BladeIp = $SubnetIPAddresses[$MAC]

                        if ($null -eq $BladeIp)
                        {
                            $MAC = ($ChassisManagers[$Chassis].Info.ChassisInfoResponse.BladeCollections.BladeInfo[$BladeIndex].BladeMacAddress.NicInfo[1].MacAddress).Replace(":","-").ToLower()

                            $BladeIp = $SubnetIPAddresses[$MAC.Replace(":","-").ToLower()]
                        }

                        if ($null -ne $BladeIp)
                        {
                            if ($null -ne (Test-Connection $BladeIP -count 1 -ErrorAction SilentlyContinue))
                            {
                                If (-NOT $Full)
                                {
                                    $Blades                                 += $WCS_BLADE_OBJECT.Clone()
                                    $TotalBladeIndex                         = $Blades.Count - 1
                                    $Blades[$TotalBladeIndex].Slot           = $BladeId
                                    $Blades[$TotalBladeIndex].ChassisMac     = $ChassisManagers[$Chassis].ActiveMAC
                                    $Blades[$TotalBladeIndex].State          = $BladeState
                                    $Blades[$TotalBladeIndex].ChassisId      =  ("{0} at  IP {1}   {3}" -f $ChassisManagers[$Chassis].Hostname,$ChassisManagers[$Chassis].IP, $ChassisManagers[$Chassis].ActiveMAC,$ChassisManagers[$Chassis].Error)

 
                                }

                                $Blades[$TotalBladeIndex].IP             = $BladeIP
                                $Blades[$TotalBladeIndex].MAC            = $MAC
                                $IP[$Chassis,$BladeIndex] = $BladeIP
                            }
                        }
                        


                }

            }
        }     
        #-----------------------------------------
        # Restore the previous display mode
        #-----------------------------------------
        If (-NOT $Quiet) { View-WcsBlade $Blades}

        Write-Output ([array] $Blades)

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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }

        Write-Output @()
    }
 
}
#----------------------------------------------------------------------------------------------
# View-WcsBlade
#----------------------------------------------------------------------------------------------
Function View-WcsBlade()
{
   <#
  .SYNOPSIS
   Displays blades connected to one or more chassis [Internal Evaluation Only]

  .DESCRIPTION
   Displays information on blades connected to the chassis manager specified.  If no
   chassis manager specified searches subnet for all chassis managers and then all
   blades connected to each chassis.

  .EXAMPLE
   View-WcsBlade

   Displays all WcsBlade connected to all chassis managers on default subnet  

  .EXAMPLE
   View-WcsBlade -Chassis $MyChassis

   Displays all blades connected to chassis manager defined in $MyChassis variable

  .PARAMETER ChassisManagers
   Array of chassis manager xml objects returned by the Get-WcsChassis command

  .PARAMETER Subnet
   IPV4 subnet to search if no chassis managers specified

   #>
    
    [CmdletBinding()]

    Param
    (
        [Parameter(Mandatory=$false,Position=0)] [array]         $Blades          = $null,
        [Parameter(Mandatory=$false)]            [array]         $ChassisManagers = $null,
        [Parameter(Mandatory=$false)]            [string]        $Subnet          = "192.168",
        [Parameter(Mandatory=$false)]                            $BladeCredential = $Global:BladeCredential,
        [Parameter(Mandatory=$false)]                            $Credential      = $Global:ChassisManagerCredential,
                                                 [switch]        $Full
    )
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #---------------------------------------------------------
        # If blades provided use them and ignore CM and subnet
        #---------------------------------------------------------
        If ($null -eq $Blades)
        {
            #-----------------------------------------
            # If CM not specified find them
            #-----------------------------------------
            If ($null -eq $ChassisManagers)
            {
                Write-Host ("`tFinding chassis managers on {0}`r" -f $Subnet) 
                [array] $ChassisManagers =  (Get-WcsChassis -Quiet -Subnet $Subnet -Credential $Credential)
                If ($null -eq $ChassisManagers)
                {
                    Write-Host "`t`tNo chassis managers found`r"
                    Return
                }
            }
            Else
            {
                For ($Chassis = 0; $Chassis -lt $ChassisManagers.Count; $Chassis++) 
                {
                    If ($ChassisManagers[$Chassis].WcsObject -ne $WCS_TYPE_CHASSIS)
                    {
                        Throw "Illegal chassis type found"                      
                    }
                }
            }

            Write-Host ("`tFinding blades on {0} chassis managers`r" -f $ChassisManagers.Count) 
            #-----------------------------------------
            # Get all blades on all chassis
            #-----------------------------------------
            [array] $Blades = Get-WcsBlade -ChassisManager $ChassisManagers -Quiet -Full:$full -Credential $Global:BladeCredential
        }
        #-----------------------------------------
        # Display all blades on all chassis
        #-----------------------------------------
        $CurrentChassis = " "
        $CurrentChassisCount = 0

        If ($null -eq $Blades) { return $null}

        For ($Blade = 0; $Blade -lt $Blades.Count; $Blade++)
        {    

            If ($Blades[$Blade].WcsObject -ne $WCS_TYPE_BLADE)
            {
                Write-Host -ForegroundColor Red  "Illegal blade type`r"
                Return $null
            }
            If ($Blades[$Blade].ChassisId -ne $CurrentChassis)
            {
                $CurrentChassis  =$Blades[$Blade].ChassisId 
                If ($CurrentChassis.Contains("ERROR"))
                {
                    Write-Host -ForegroundColor Red  "`r`n`tCM[$CurrentChassisCount]  $CurrentChassis  `r`n`r"
                }
                Else
                {
                    Write-Host "`r`n`tCM[$CurrentChassisCount]  $CurrentChassis  `r`n`r"
                }
                $CurrentChassisCount++
            }        
            Write-Host ("`t`tBlade[{0,3}]  {1,-16}  Slot: {2,2}    IP: {3,-18} MAC: {4,-18}    State: {5,-15}   Model: {6}`r" -f $Blade,$Blades[$Blade].Hostname,$Blades[$Blade].Slot, $Blades[$Blade].IP,$Blades[$Blade].MAC,$Blades[$Blade].State,$Blades[$Blade].Type ) 
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
    }
}

#----------------------------------------------------------------------------------------------
# View-WcsChassis
#----------------------------------------------------------------------------------------------
Function View-WcsChassis()
{
   <#
  .SYNOPSIS
   Displays chassis manager information [Internal Evaluation Only]

  .DESCRIPTION
   Displays chassis manager information for the chassis specified.  If no
   chassis manager specified searches subnet for all chassis managers.

   Searches for all chassis manager on 192.168 by default

   Uses ARP table to find list of CM to try

  .EXAMPLE
   View-WcsChassis

   Displays all chassis managers on default subnet  

  .EXAMPLE
   View-WcsChassis -subnet "192.168.200"

   Displays all chassis managers on 192.168.200 subnet 

  .EXAMPLE
   View-WcsChassis $Chassis0

   Displays chassis managers in the $Chassis0 variable

  .PARAMETER ChassisManagers
   Array of chassis manager xml objects returned by the Get-WcsChassis command

  .PARAMETER Subnet
   IPV4 subnet to search if no chassis managers specified

   #>
      
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (

        [Parameter(Mandatory=$false,Position=0)] [array]         $ChassisManagers = $null,
        [Parameter(Mandatory=$false,Position=1)] [string]        $Subnet          = "192.168",
        [Parameter(Mandatory=$false)]                            $Credential      = $Global:ChassisManagerCredential
    )
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-----------------------------------------
        # If CM not specified find them
        #-----------------------------------------
        If ($null -eq $ChassisManagers)
        {
            [array] $ChassisManagers = Get-WcsChassis -Quiet -Subnet $Subnet -Credential  $Credential  
            If ($null -eq $ChassisManagers)
            {
                Write-Host "`n`tNo chassis managers found`r"
                Return 
            }
        }
        #-----------------------------------------
        # Display all chassis
        #-----------------------------------------
        Write-Host " `r"

        For ($Chassis = 0; $Chassis -lt $ChassisManagers.Count; $Chassis++)
        {       
            If ($ChassisManagers[$Chassis].WcsObject -ne $WCS_TYPE_CHASSIS)
            {
                Throw "Illegal chassis type found"
            }       
            If ($null -eq $ChassisManagers[$Chassis].Error)
            {
                Write-Host ("`tCM[$Chassis]  {5} at IP: {1,-17} MAC: {2,-18}   Service: {3}   Asset: {4}`r" -f $ChassisManagers[$Chassis].Position, $ChassisManagers[$Chassis].IP,$ChassisManagers[$Chassis].ActiveMAC,$ChassisManagers[$Chassis].Service,$ChassisManagers[$Chassis].AssetTag,$ChassisManagers[$Chassis].Hostname)
            }
            Else
            {
                Write-Host -ForegroundColor Red  ("`tCM[$Chassis]  {6} at IP: {1,-17} MAC: {2,-18}   Service: {3}   Asset: {4}  {5}`r" -f $ChassisManagers[$Chassis].Position, $ChassisManagers[$Chassis].IP,$ChassisManagers[$Chassis].ActiveMAC,$ChassisManagers[$Chassis].Service,$ChassisManagers[$Chassis].AssetTag,$ChassisManagers[$Chassis].Error,$ChassisManagers[$Chassis].Hostname)
            }
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
    }
}
#-------------------------------------------------------------------------------------
# Reboot-WcsChassis
#-------------------------------------------------------------------------------------
Function Reboot-WcsChassis()
{
   <#
  .SYNOPSIS
   Sends reboot command to one or more WCS chassis

  .DESCRIPTION
   Sends reboot command to one or more WCS chassis

  .EXAMPLE
   Reboot-WcsChassis -TargetList $ChassisManagerIp

  .PARAMETER TargetList
   List of remote targets to run the script on either as a single IP address or 
   array of IP addresses. Examples:

   192.168.200.10
   @(192.168.200.10, 192.168.200.11)

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Remote

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$true,Position=0)] $TargetList 
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Get targets and credentials
        #-------------------------------------------------------
        $TargetIpList = [array] (GetTargets $TargetList)

        $UserName =  $ChassisManagerCredential.UserName
        $Password =  $ChassisManagerCredential.GetNetworkCredential().Password  
        #------------------------------------------------------------------------
        # For each target reboot, don't wait for response because of the reboot
        #------------------------------------------------------------------------             
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            $PsCommand =  ("\\{0} -accepteula -u $UserName  -p $Password shutdown /r /t 5" -f $TargetIpList[$IpAddress])
            
            Write-Verbose ("Running psexec command '{0}'`r" -f $PsCommand )
            $MyProcess,$MyProcessOut,$MyProcessErr =   BaseLib_StartProcess $WCS_PSEXEC64_BINARY $PsCommand 
        }
        Return $WCS_RETURN_CODE_SUCCESS
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
    
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }

}
#-------------------------------------------------------------------------------------
# Reboot-WcsBlade
#-------------------------------------------------------------------------------------
Function Reboot-WcsBlade()
{
   <#
  .SYNOPSIS
   Sends reboot command to one or more WCS blades

  .DESCRIPTION
   Sends reboot command to one or more WCS blades

   Uses default blade credentials. Use Set-BladeCredential to change credentials

  .EXAMPLE
   Reboot-WcsBlade -TargetList $BladeIp

  .PARAMETER TargetList
   List of remote targets to run the script on either as a single IP address or 
   array of IP addresses. Examples:

   192.168.200.10
   @(192.168.200.10, 192.168.200.11)
  
  .PARAMETER WinPE
   If specified sends the WinPE reboot command instead of the Windows shutdown command

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Remote

   #>

    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$true,Position=0)]           $TargetList, 
                                                 [switch] $WinPE 
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Get targets and credentials
        #-------------------------------------------------------
        $TargetIpList = [array] (GetTargets $TargetList)

        $UserName =  $BladeCredential.UserName
        $Password =  $BladeCredential.GetNetworkCredential().Password  

        #------------------------------------------------------------------------
        # For each target reboot, don't wait for response because of the reboot
        #------------------------------------------------------------------------
        For ($IpAddress=0;$IpAddress -lt $TargetIpList.Count; $IpAddress++)
        {
            If ($WinPE)
            {
                $PsCommand =  ("\\{0} -accepteula -u $UserName  -p $Password Wpeutil reboot" -f $TargetIpList[$IpAddress])
            }
            Else
            {
                $PsCommand =  ("\\{0} -accepteula -u $UserName  -p $Password shutdown /r /t 5" -f $TargetIpList[$IpAddress])
            }

            Write-Verbose ("Running psexec command '{0}'`r" -f $PsCommand )
            $MyProcess,$MyProcessOut,$MyProcessErr =   BaseLib_StartProcess $WCS_PSEXEC64_BINARY $PsCommand 
        }
        Return $WCS_RETURN_CODE_SUCCESS
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red  $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}
