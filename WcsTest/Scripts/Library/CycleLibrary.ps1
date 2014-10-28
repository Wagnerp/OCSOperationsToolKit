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
# Constants specific to this script
#-----------------------------------------------------------------------------------------
Set-Variable  -Name WCS_CYCLE_CONFIGURATION_MISMATCH              -Value ([byte] 0X1)            -Option ReadOnly -Force
Set-Variable  -Name WCS_CYCLE_UNEXPECTED_ERROR                    -Value ([byte] 0X2)            -Option ReadOnly -Force
Set-Variable  -Name WCS_CYCLE_UNKNOWN_ERROR                       -Value ([byte] 0XFF)           -Option ReadOnly -Force

Set-Variable  -Name WCS_CYCLE_SENSOR                              -Value ([byte] 0X0F)           -Option ReadOnly -Force
Set-Variable  -Name WCS_CYCLE_SENSORTYPE                          -Value ([byte] 0XC0)           -Option ReadOnly -Force
Set-Variable  -Name WCS_CYCLE_OEMCODE                             -Value ([byte] 0X70)           -Option ReadOnly -Force

#-------------------------------------------------------------------------------------------
# Helper function that returns true if autologin enabled and username and password not null
#-------------------------------------------------------------------------------------------
Function AutoLoginEnabled()
{
    Try
    {
        Return ( (    1 -eq (Get-ItemProperty  "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" -Name AutoAdminLogon  -ErrorAction Stop ).AutoAdminLogon)   -and `
                 ($null -ne (Get-ItemProperty  "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" -Name DefaultUsername -ErrorAction Stop ).DefaultUsername)  -and `
                 ($null -ne (Get-ItemProperty  "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" -Name DefaultPassword -ErrorAction Stop ).DefaultPassword) )
    }
    Catch
    {
        Return $false
    }
}
#-------------------------------------------------------------------------------------
# Set-AutoLogin 
#-------------------------------------------------------------------------------------
Function Set-AutoLogin()
{
<#
  .SYNOPSIS
   Enables autologin.  Prompts for username and password

  .DESCRIPTION
   Enables autologin. Autologin must be enabled for cycle testing so the 
   system will automatically login and run the startup batch file
   
   The script prompts for username and password then writes values into
   the registry at this location:

      HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon

   The registry can also be written directly via regedit.  For more info
   on autologin see MSDN

  .EXAMPLE
   Set-Autologin

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Cycle
#>

    If (CoreLib_IsWinPE)
    {
        Write-Host -ForegroundColor Red -NoNewline "This function does not run in the WinPE OS"
        Return
    }

    Write-Host -NoNewline "Enter the user name :"  
    $User = Read-Host
   
    Write-Host -NoNewline  "Enter the password :"  
    $Password = Read-Host

    If (($null -eq $User) -or ($null -eq $Password))
    {
        Write-Host "User and Password cannot be null`r"
        Return $null
    }
    Set-ItemProperty  "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" -Name AutoAdminLogon  -Value          1
    Set-ItemProperty  "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" -Name DefaultUsername -Value      $User
    Set-ItemProperty  "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon" -Name DefaultPassword -Value  $Password
}
#-------------------------------------------------------------------------------------
# Cycle-OsReboot 
#-------------------------------------------------------------------------------------
Function Cycle-OsReboot()
{
<#
  .SYNOPSIS
   Cycles system using OS reboot command

  .DESCRIPTION
   Cycles system using shutdown.exe /r.  
  
   On each cycle:
     (1) The config is read and compared against a reference config.  
     (2) The Windows System Event Log and BMC SEL are checked for suspect errors.
    
   By default the results are logged in <InstallDir>\Results\Cycle-OsReboot\<Date-Time>\
   Note the default <InstallDir> is \WcsTest

   RUN CYCLE-OSREBOOT WITH THE SAME ACCOUNT USED FOR AUTO-LOGIN.  
   DO NOT LOGIN WITH ANOTHER ACCOUNT WHILE RUNNING

   To run Cycle-OsReboot the following must be setup beforehand:

       1.  Autologin must be enabled.  To enable run "Set-Autologin" or write the registry
           directly. 
       
       2.  A reference configuration file must exist.  To generate a reference config file 
           run "Log-WcsConfig Reference".  Before generating a config file
           verify the current configuration is correct.
   
   Before each reboot there is a 30 second pause where the user can hit <Enter> to stop the 
   test.  
  
   Future Enhancement:  Verify time between cycles is within expected range
   
  .EXAMPLE
   Cycle-OsReboot -NumberOfCycles 200  

   Executes 200 OS reboot cycles and checks the config each cycle against Reference config.
   If config doesn't match and StopOnFail specified then stops the test

  .PARAMETER NumberOfCycles
   Number of cycles to run

  .PARAMETER ReferenceConfig
   Reference config which is compared on each cycle.  If not specified uses default config:
   
   <InstallDir>\Configurations\Reference

   Note the default <InstallDir> is \WcsTest

  .PARAMETER LogDirectory
   Logs results in this directory. If not specified logs results in:
   
    <InstallDir\Results\<FunctionName>\<DateTime>

  .PARAMETER IncludeSelFile
   XML file that contains SEL entries to include as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER ExcludeSelFile
   XML file that contains SEL entries to exclude as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER IncludeEventFile
   XML file that contains Windows System Events to include as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER ExcludeEventFile
   XML file that contains Windows System Events to exclude as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER StopOnFail
   If specified script stops when a failure occurs

  .PARAMETER Running
   For internal use only.  Do not specify.

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Cycle
   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param(
                [Parameter(Mandatory=$true,Position=0)]  [int]     $NumberOfCycles,
                [Parameter(Mandatory=$false)]            [string]  $RefConfig="Reference",
                [Parameter(Mandatory=$false)]            [string]  $LogDirectory='',
                [Parameter(Mandatory=$false)]            [string]  $IncludeSelFile    =  '',
                [Parameter(Mandatory=$false)]            [string]  $ExcludeSelFile    =  '',
                [Parameter(Mandatory=$false)]            [string]  $IncludeEventFile  =  '',
                [Parameter(Mandatory=$false)]            [string]  $ExcludeEventFile  =  '',
                                                         [switch]  $StopOnFail,
                                                         [switch]  $Running

    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Setup vars and constants
        #-------------------------------------------------------
        $STARTUP_BAT   =  "$WCS_OS_STARTUP_DIRECTORY\Cycle-OsReboot.Bat" 
        $ConfigResult  = $null
        $ErrorCount    = 0
        $CurrentFail   = 0
        $CurrentPass   = 0

        $LogDirectory  = BaseLib_GetLogDirectory $LogDirectory $FunctionInfo.Name

        $SUMMARY_FILE  = "$LogDirectory\OsReboot-Summary.log"
        $COUNT_FILE    = "$LogDirectory\OsReboot-Count.log"
        #-------------------------------------------------------------------
        #  Display Message
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host
        CoreLib_WriteLog -Value  (" Cycle-OsReboot: Cycle start time {0}" -f (Get-Date -Format G))     -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
        CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host

        #-----------------------------------------------------------
        # If starting make the setup .bat file and check autologin
        #----------------------------------------------------------- 
        If (-NOT $Running)
        {
            #-----------------------------------------------------------
            # Check for the config files before starting
            #-----------------------------------------------------------
            If (-NOT (Test-Path "$WCS_CONFIGURATION_DIRECTORY\$RefConfig.config.xml" ))
            {
                Throw "Could not find configuration file '$WCS_CONFIGURATION_DIRECTORY\$RefConfig.config.xml'" 
            }
            Else
            {
                $Mismatches = Compare-WcsConfig -RefConfig (Get-WcsConfig $RefConfig) -RefToResults ([ref] $ConfigResult) -Exact -Quiet

                If (($null -eq $Mismatches) -or (0 -ne $Mismatches))
                { 
                    Log-WcsConfig -Config $ConfigResult -File ConfigMisMatch -Path $LogDirectory
                    Throw ("Configuration file does not match current configuration. See results in {0}" -f    $LogDirectory)                  
                }

                Copy-Item "$WCS_CONFIGURATION_DIRECTORY\$RefConfig.config.xml" "$LogDirectory" -ErrorAction SilentlyContinue | Out-Null
            }
            #-----------------------------------------------------------
            # Verify autologin enabled
            #-----------------------------------------------------------
            If (-NOT (AutoLoginEnabled))
            {
                Throw " Autlogin is not enabled.  Please enable Autologin using regedit or Set-Autologin" 
            }
            #-----------------------------------------------------------
            # Setup the startup file for next cycle
            #-----------------------------------------------------------
            $CommandToRun = "powershell -command . $WCS_SCRIPT_DIRECTORY\wcsscripts.ps1;cycle-osreboot  $NumberOfCycles -LogDirectory $LogDirectory  -StopOnFail:`$$StopOnFail -Running" 

            #Remove any old cycling files

            Remove-Item "$WCS_OS_STARTUP_DIRECTORY\Cycle-*.*"  -Force -ErrorAction SilentlyContinue | Out-Null
      
            Set-Content -Value  $CommandToRun  -Path $STARTUP_BAT

            $CurrentCycle = 0
        }
        #-----------------------------------------------------------
        # Else get the current cycle
        #-----------------------------------------------------------
        Else
        {
            If (-NOT (Test-Path $STARTUP_BAT))
            {
                Throw "Did not find the startup bat file. DO NOT USE -Running"
            }

            If (-NOT (Test-Path $COUNT_FILE))
            {
                Throw "Aborting script because could not find the count file '$COUNT_FILE'"   
            }

            $CycleFileContent = (Get-Content $COUNT_FILE)
            
            $CurrentCycle =  ([int] $CycleFileContent.split()[0]) + 1
            $CurrentFail  =  [int] $CycleFileContent.split()[1]
            $CurrentPass  =  [int] $CycleFileContent.split()[2]
                
        }
        #-----------------------------------------------------------
        # Make a folder for the logs
        #----------------------------------------------------------- 
        $ErrorDirectory = ("$LogDirectory\Cycle{0}" -f $CurrentCycle)

        New-Item $ErrorDirectory -ItemType Container -ErrorAction SilentlyContinue | Out-Null
        #-------------------------------------------------------------------
        #  Display Message
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value  " Current cycle $CurrentCycle of $NumberOfCycles ($CurrentFail CYCLES FAILED)"     -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
        CoreLib_WriteLog -Value  " Log directory $ErrorDirectory" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host

        #----------------------------------------------------------------------------------
        # If start of test just backup and clear event logs, else backup and check for 
        # event logs for errors and check the configuration too
        #----------------------------------------------------------- ----------------------
        If (0 -eq $CurrentCycle) 
        {
            If (0 -ne (Clear-WcsError ))
            {
                $ErrorCount++
                CoreLib_WriteLog -Value 'Could not clear error logs'   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
            }
        }
        Else
        {
            $EventErrors = Check-WcsError -LogDirectory $ErrorDirectory -IncludeEventFile $IncludeEventFile -ExcludeEventFile $ExcludeEventFile -IncludeSelFile $IncludeSelFile -ExcludeSelFile $ExcludeSelFile 

            If (0 -ne $EventErrors)
            {
                $ErrorCount++
                CoreLib_WriteLog -Value ("Cycle {0} had errors in the event log. See results in {1}" -f  $CurrentCycle, $ErrorDirectory)  -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
            }

            If (0 -ne (Clear-WcsError ))
            {
                $ErrorCount++
                CoreLib_WriteLog -Value 'Could not clear error logs'   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
            }
             
            $Mismatches = Compare-WcsConfig -RefConfig (Get-WcsConfig $RefConfig) -RefToResults ([ref] $ConfigResult) -Exact

            If (0 -ne $Mismatches)
            {
                $ErrorCount++
                CoreLib_WriteLog -Value ("Cycle {0} had configuration mismatch. See results in {1}" -f  $CurrentCycle, $ErrorDirectory)  -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
                Log-WcsConfig -Config $ConfigResult -File ConfigMisMatch -Path $ErrorDirectory
            }
        }
        #-----------------------------------------------------------
        # If reached the number of cycles then stop
        #-----------------------------------------------------------
        If ($CurrentCycle -ge $NumberOfCycles)  
        {
            CoreLib_WriteLog -Value "Stopping cycle testing"     -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
            Remove-Item $STARTUP_BAT -Force -ErrorAction SilentlyContinue | Out-Null
            Return  $WCS_RETURN_CODE_SUCCESS  
        }
        #-----------------------------------------------------------
        # If have errors and stop on fail then stop
        #-----------------------------------------------------------
        ElseIf  (($ErrorCount -ne 0) -and ($StopOnFail))
        {
            CoreLib_WriteLog -Value "Aborting cycle testing because error found and StopOnFail true. "    -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
            Remove-Item $STARTUP_BAT -Force -ErrorAction SilentlyContinue | Out-Null
            Return 1 
        }
        #-----------------------------------------------------------
        # Reboot
        #-----------------------------------------------------------
        else
        {

            CoreLib_WriteLog -Value ' ' -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host

            If  ($ErrorCount -eq 0) 
            { 
                $CurrentPass++
                CoreLib_WriteLog -Value (" Cycle {1} passed.    Rebooting at {0}" -f (Get-Date -Format G),$CurrentCycle)   -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
            }
            Else                    
            { 
                $CurrentFail++
                CoreLib_WriteLog -Value (" Cycle {1} FAILED.    Rebooting at {0}" -f (Get-Date -Format G),$CurrentCycle)    -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
            }

            Set-Content -Value "$CurrentCycle $CurrentFail $CurrentPass" -Path $COUNT_FILE 

            Write-Host  "`n`r`n`r Hit <ENTER> to abort testing`r`n`r`n"

            For ($TimeOut=0;$TimeOut -lt 60;$TimeOut++)
            {
                Start-Sleep -Milliseconds 500
                if ([console]::KeyAvailable)
                {
                    [console]::ReadLine()
                    CoreLib_WriteLog -Value " User aborted testing."   -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
                    Remove-Item $STARTUP_BAT -Force -ErrorAction SilentlyContinue | Out-Null
                    Return $WCS_RETURN_CODE_INCOMPLETE 
                }
            }            
            shutdown.exe /r /t 1   | Out-Null        
        }
        Return $WCS_RETURN_CODE_SUCCESS  
    }
    #------------------------------------------------------------
    # Default Catch block to handle all errors
    #------------------------------------------------------------
    Catch
    {
        $_.ErrorDetails  = CoreLib_FormatException $_  -FunctionInfo $FunctionInfo

        CoreLib_WriteLog -Value $_.ErrorDetails -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  

        #----------------------------------------------
        # Take action (do nothing if SilentlyContinue)
        #---------------------------------------------- 
        If      ($ErrorActionPreference -eq 'Stop')             { Throw $_ }
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
            
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-------------------------------------------------------------------------------------
# Cycle-WcsCheck
#-------------------------------------------------------------------------------------
Function Cycle-WcsCheck()
{
<#
  .SYNOPSIS
   Checks configuration, BMC SEL, and Windows System Event Log for errors

  .DESCRIPTION
   This command allows config and error checking during cycle testing.  On each boot the 
   config is read and compared against a reference config.  In addition, the BMC SEL and 
   Windows System Event Log are checked for errors.
    
   By default the results are logged in <InstallDir>\Results\Cycle-WcsCheck\<Date-Time>\
   Note the default <InstallDir> is \WcsTest

   To run Cycle-WcsCheck the following must be setup beforehand:

       1.  Autologin must be enabled.  To enable run "Set-Autologin" or write the registry
           directly. 
       
       2.  A reference configuration file must exist.  To generate a reference config file 
           run "Log-WcsConfig Reference".  Before generating a config file
           verify the current configuration is correct.
          
       3.  Delete any old cycle bat files in the startup directory (ie: Cycle-*.bat)

       4.  The following command must be placed in a batch file in the startup directory of

            "\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Cycle-WcsCheck.Bat" 

            Powershell -Command ". \WcsTest\Scripts\WcsScripts.ps1 ; Cycle-WcsCheck"

            NOTE: It is likely that you will want to exclude events such as unexpected
            power loss in the Windows System Event Log.  To do this modify the file:

            Powershell -Command ". \WcsTest\Scripts\WcsScripts.ps1 ; Cycle-WcsCheck -ExcludeEventFile <path>"

            NOTE:  If not installed in \WcsTest then change the path above to match the 
            actual install directory.  An example of this batch file is also in 
            
            <InstallDir>\Scripts\References\CycleBatFiles

        5.  Before starting the test clear all errors using Clear-WcsError command

  .PARAMETER LogDirectory
   Logs results in this directory. If not specified logs results in:
   
    <InstallDir\Results\<FunctionName>\<DateTime>

  .PARAMETER IncludeSelFile
   XML file that contains SEL entries to include as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER ExcludeSelFile
   XML file that contains SEL entries to exclude as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER IncludeEventFile
   XML file that contains Windows System Events to include as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER ExcludeEventFile
   XML file that contains Windows System Events to exclude as suspect errors

   See <InstallDir>\Scripts\References for example file

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Cycle

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param(      
                [Parameter(Mandatory=$false)] [string]  $LogDirectory      ='',
                [Parameter(Mandatory=$false)] [string]  $IncludeSelFile    =  '',
                [Parameter(Mandatory=$false)] [string]  $ExcludeSelFile    =  '',
                [Parameter(Mandatory=$false)] [string]  $IncludeEventFile  =  '',
                [Parameter(Mandatory=$false)] [string]  $ExcludeEventFile  =  ''
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Setup vars and constants
        #-------------------------------------------------------
        $ConfigResult            = $null
        [byte] $ReturnCode       = 0
        $LogDirectory            = BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name
        $SUMMARY_FILE            = "$LogDirectory\Cycle-Summary.log"   
        #-------------------------------------------------------------------
        #  Display Message
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host
        CoreLib_WriteLog -Value  (" Cycle-WcsCheck: Cycle start time {0}" -f (Get-Date -Format G))     -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
        CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host
        CoreLib_WriteLog -Value  " Log directory $LogDirectory" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host                   
        #-----------------------------------------------------------
        # Check the configuration against the reference
        #----------------------------------------------------------- 
        $Mismatches = Compare-WcsConfig -RefConfig (Get-WcsConfig Reference) -RefToResults ([ref] $ConfigResult) -Exact -ErrorAction Stop

        If (0 -ne $Mismatches)
        {
            $ReturnCode = $ReturnCode -bor $WCS_CYCLE_CONFIGURATION_MISMATCH 

            CoreLib_WriteLog -Value ("Cycle had configuration mismatch. See results in {0}" -f $LogDirectory) -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  

            Log-WcsConfig -Config $ConfigResult -File ConfigMisMatch -Path $LogDirectory
        }
        Else
        {
            CoreLib_WriteLog -Value  'Cycle passed configuration check'  -Function $FunctionInfo.Name   -LogFile $SUMMARY_FILE  
        } 
        #-----------------------------------------------------------
        # Check for errors
        #----------------------------------------------------------- 
        $ErrorCount = Check-WcsError -LogDirectory $LogDirectory -ErrorAction Stop  -IncludeEventFile $IncludeEventFile -ExcludeEventFile $ExcludeEventFile -IncludeSelFile $IncludeSelFile -ExcludeSelFile $ExcludeSelFile 
        
        If (0 -ne $ErrorCount)
        {
            $ReturnCode = $ReturnCode -bor $WCS_CYCLE_UNEXPECTED_ERROR

            CoreLib_WriteLog -Value ("Cycle had unexpected errors. See results in {0}" -f $LogDirectory)   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE   
        }
        Else
        {
            CoreLib_WriteLog -Value  'Cycle passed error check' -Function $FunctionInfo.Name   -LogFile $SUMMARY_FILE 
        } 
        #-----------------------------------------------------------
        # Clear errors
        #-----------------------------------------------------------   
        If (0 -ne (Clear-WcsError))
        {
           Throw 'Could not clear error logs' 
        }
        #------------------------------------------------------------------------------------------
        # Write results to the SEL. If fail then won't get entry that indicates cycle completed
        #----------------------------------------------------------- ------------------------------
        [byte[]]$RequestData = @(0,0,2, 0,0,0,0, 0,1,4,  $WCS_CYCLE_SENSORTYPE, $WCS_CYCLE_SENSOR ,$WCS_CYCLE_OEMCODE, 0,0,$ReturnCode)
           
        $IpmiData = Invoke-WcsIpmi  0x44 $RequestData $WCS_STORAGE_NETFN -ErrorAction SilentlyContinue
        }
    #------------------------------------------------------------
    # Default Catch block to handle all errors
    #------------------------------------------------------------
    Catch
    {
        $_.ErrorDetails  = CoreLib_FormatException $_  -FunctionInfo $FunctionInfo

        CoreLib_WriteLog -Value $_.ErrorDetails -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  

        #----------------------------------------------
        # Take action (do nothing if SilentlyContinue)
        #---------------------------------------------- 
        If      ($ErrorActionPreference -eq 'Stop')             { Throw $_ }
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }

        #------------------------------------------------------------------------------------------
        # Write results to the SEL. If fail then won't get entry that indicates cycle completed
        #----------------------------------------------------------- ------------------------------
        [byte[]]$RequestData = @(0,0,2, 0,0,0,0, 0,1,4,  $WCS_CYCLE_SENSORTYPE, $WCS_CYCLE_SENSOR ,$WCS_CYCLE_OEMCODE, 0,0,$WCS_CYCLE_UNKNOWN_ERROR)
           
        $IpmiData = Invoke-WcsIpmi  0x44 $RequestData $WCS_STORAGE_NETFN -ErrorAction SilentlyContinue
    }
}

#-------------------------------------------------------------------------------------
# Cycle-WcsBladePower 
#-------------------------------------------------------------------------------------
Function Cycle-WcsBladePower()
{
<#
  .SYNOPSIS
   Cycles the power to blades in a chassis

  .DESCRIPTION
   Cycles power (chipset or full power) to all the blades in a chassis.  This must be run on the 
   Chassis Manager in the chassis to be tested.
    
   By default the results are logged in <InstallDir>\Results\Cycle-WcsBladePower\<Date-Time>\
   Note the default <InstallDir> is \WcsTest

   This command uses the default chassis manager credentials.  To change these credentials
   use the Set-WcsChassisCredential command.

   SSL Setting will be detected automatically based on Chassis Manager Config file

   THIS REQUIRES SETUP ON EVERY BLADE TO TEST:

       1.  Autologin must be enabled.  To enable run "Set-Autologin" or write the registry
           directly. 
       
       2.  A reference configuration file must exist.  To generate a reference config file 
           run "Log-WcsConfig Reference".  Before generating a config file
           verify the current configuration is correct.
             
       3.  Delete any old cycle bat files in the startup directory (ie: Cycle-*.bat)

       4.  The following command must be placed in a batch file in the startup directory:

            "\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\Cycle-WcsCheck.Bat" 

            Powershell -Command ". \WcsTest\Scripts\WcsScripts.ps1 ; Cycle-WcsCheck 
              -ExcludeEventFile C:\WcsTest\Scripts\References\ErrorFiles\ExcludePowerLossEvent.xml"

            NOTE:  If not installed in \WcsTest then change the path above to match the 
            actual install directory.  An example of this batch file is also in 
            
            <InstallDir>\Scripts\References\CycleBatFiles

       5.  Wcs Test Tools must be installed on each blade

       6.  Before starting the test clear all errors using Clear-WcsError command
              
  .PARAMETER NumberOfCycles
   The number of cycles to power cycle the blades

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

  .PARAMETER FullPower
   Full power includes standby power to the blade.  The default is to cycle chipset power
   without standby power

  .PARAMETER StopOnFail
   If specified script stops when a failure occurs

  .PARAMETER NumberOfBlades
   If specified the script verifies the number of blades being tested matches this value

  .PARAMETER SSL
   If specified the script uses SSL protocol for REST commands

  .PARAMETER OnTimeInSec
   Time to wait after power on

  .PARAMETER OffTimeInSec
   Time to wait after power off

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Cycle

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param(
                [Parameter(Mandatory=$false)]            [string]  $NumberOfCycles=1,
                [Parameter(Mandatory=$false)]            [string]  $LogDirectory='',
                                                         [int]     $OnTimeInSec=600,
                                                         [int]     $OffTimeInSec=30,
                                                         [int]     $NumberOfBlades=-1,
                                                         [switch]  $FullPower,
                                                         [switch]  $StopOnFail
                                                         #[switch]  $SSL
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Create the log directory
        #-------------------------------------------------------
        $LogDirectory            =  BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name
        $SUMMARY_FILE            = "$LogDirectory\CycleBladePower-Summary.log"
		$ERROR_FILE				="$LogDirectory\CycleBladePower-Error.log"
		$CurrentFail             = 0
        
        #-------------------------------------------------------
        # Set the type of cycling
        #-------------------------------------------------------
        If ($FullPower)
        {
            $OnCommand      = 'SetAllPowerOn'  
            $OffCommand     = 'SetAllPowerOff'  
        }
        Else
        {
            $OnCommand      = 'SetAllBladesOn'   
            $OffCommand     = 'SetAllBladesOff'  
        }
        #-------------------------------------------------------------------
        #  Display Message
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host
        CoreLib_WriteLog -Value  (" Cycle-BladePower: Start time {0}" -f (Get-Date -Format G))     -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
        CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host

		CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $ERROR_FILE
        CoreLib_WriteLog -Value  (" Cycle-BladePower: Error Log File Start time {0}" -f (Get-Date -Format G))     -Function $FunctionInfo.Name  -LogFile $ERROR_FILE
        CoreLib_WriteLog -Value  (" Log directory $LogDirectory") -Function $FunctionInfo.Name  -LogFile $ERROR_FILE
		CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $ERROR_FILE

		#-------------------------------------------------------
		#Assigned default SSL setting as per Chassis Manager Configuration -  ?Need to check for error condition
        #-------------------------------------------------------
		$ChassisConfig			= [XML] (Get-Content $WCS_CHASSIS_MANAGER_CONFIG_FILE_PATH )
		$SSLValue				= ( $ChassisConfig.configuration.appsettings.SelectNodes("add") | Where-Object { $_.Key -eq "EnableSslEncryption" }).value
									if($SSLValue -eq 1 ){$SSL=$true} else {$SSL=$false}		
        CoreLib_WriteLog -Value  (" SSL Setting is {0} " -f $SSL) -Function $FunctionInfo.Name	-LogFile $SUMMARY_FILE	-PassThru | Write-Host
		
        #-------------------------------------------------------
        # Clear the blade logs and set the starting blades
        #-------------------------------------------------------
        $StartBlades = New-Object 'system.object[]' $WCS_BLADES_PER_CHASSIS 

        $BladeCount = 0

        For ($Blade = 1; $Blade -le $WCS_BLADES_PER_CHASSIS; $Blade++)
        {
            $BladeIndex = $Blade - 1

            $Response = Invoke-WcsRest -TargetList localhost -Command "ClearBladeLog?bladeid=$Blade" -SSL:$SSL -ErrorAction SilentlyContinue

            If (($Response -ne $null) -and ($Response.BladeResponse.CompletionCode -eq 'Success'))
            {
                CoreLib_WriteLog -Value " Testing blade $Blade"    -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru |  Write-Verbose 
                $StartBlades[$BladeIndex] = $true   
                $BladeCount++      
            }
            Else
            {
                $StartBlades[$BladeIndex] = $false
            }
        }
        CoreLib_WriteLog -Value " Testing $BladeCount blades"  -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru |  Write-Host

		#-------------------------------------------------------
        # Verify if None of the Blade connected to Chassis
        #-------------------------------------------------------
        If ( $BladeCount -eq 0 ) # Need to unit test
        {
            Throw ("NONE of the Blades are Connected/Working, found {0} blades " -f  $BladeCount)
        }

        #-------------------------------------------------------
        # Verify number of blades
        #-------------------------------------------------------
        If (($NumberOfBlades -ne -1) -and ($NumberOfBlades -ne $BladeCount))
        {
            Throw ("The number of blades found {0} doesn't match expected {1}" -f  $BladeCount,$NumberOfBlades)
        }
        #-------------------------------------------
        # Loop for the number of cycles specified
        #-------------------------------------------
        For ($Cycle = 1; $Cycle -le $NumberOfCycles; $Cycle++) 
        {
            $FoundError = $false
            #-------------------------------------------------------------------
            #  Display Message
            #-------------------------------------------------------------------
            CoreLib_WriteLog -Value  ' '   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host        
            CoreLib_WriteLog -Value  " Current cycle $Cycle of $NumberOfCycles ($CurrentFail CYCLES FAILURE) "     -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE   -PassThru | Write-Host
            CoreLib_WriteLog -Value  " Log directory $LogDirectory" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host
 
            #-------------------------------------------
            # Power off then on
            #-----------------------------------------
            CoreLib_WriteLog -Value  (" Power off at {0} and waiting {1} seconds" -f (Get-Date -Format G),$OffTimeInSec) -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host

            $Response = Invoke-WcsRest -TargetList localhost -Command $OffCommand -ErrorAction Stop -SSL:$SSL 

            Start-Sleep -Seconds $OffTimeInSec

            CoreLib_WriteLog -Value  (" Power on at {0} and waiting {1} seconds" -f (Get-Date -Format G),$OnTimeInSec) -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host

            $Response = Invoke-WcsRest -TargetList localhost -Command $OnCommand -ErrorAction Stop  -SSL:$SSL 

            Start-Sleep -Seconds $OnTimeInSec 
 
            CoreLib_WriteLog -Value  " Power cycle complete" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host
 
            #-----------------------------------------
            # Read, parse and clear blade logs
            #-----------------------------------------
            For ($Blade = 1; $Blade -le $WCS_BLADES_PER_CHASSIS ; $Blade++)
            {
                $BladeIndex = $Blade - 1
                #-----------------------------------------
                # Only check blades that were at the start
                #-----------------------------------------
                If ($StartBlades[$BladeIndex])
                {
                    $ChildLogDirectory = "$LogDirectory\BladeSlot$Blade"

                    New-Item $ChildLogDirectory -ItemType Container -Force -ErrorAction SilentlyContinue | Out-Null   
                    #--------------------        
                    # Read the blade log
                    #--------------------       
                    $SEL = [xml] (Invoke-WcsRest -TargetList localhost -Command "ReadBladeLog?bladeid=$Blade" -ErrorAction Stop -SSL:$SSL )

                    #---------------------------        
                    # Save the blade SEL as xml
                    #---------------------------        
                    $SEl.Save("$ChildLogDirectory\sel-$Cycle.xml")

                    #-----------------------------------
                    # Check if blade responded correctly
                    #-----------------------------------
                    If ($SEL.ChassisLogResponse.CompletionCode -ne 'Success')
                    {
                        CoreLib_WriteLog  " Blade $Blade FAILED!!! Could not read the SEL"    -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru |  Write-Host    
                        CoreLib_WriteLog  " Current cycle $Cycle ($CurrentFail CYCLES FAILURE) - Blade $Blade FAILED!!! Could not read the SEL"    -Function $FunctionInfo.Name  -LogFile $ERROR_FILE
                        $FoundError = $true                           
                    }
                    Else
                    {
                        $FoundResult = $false
                        #-------------------------------------
                        # Parse the SEL
                        #-------------------------------------
                        $Sel.ChassisLogResponse.logentries.ChildNodes | ForEach-Object {

                            #-------------------------------------------------------------
                            # If contains specific sensor an error occurred on the blade
                            #-------------------------------------------------------------
                            If ($_.EventDescription.Contains('OEM Event  |  OEM Event.  |  Sensor Type: Unknown  |  Sensor Name:   |  Sensor Number: 15  '))
                            {
                                $FoundResult = $true
								$EventDesc = $_.EventDescription
                                If ($_.EventDescription.Contains('Error Code: 0x000000'))
                                 {
                                    CoreLib_WriteLog -Value " Blade $Blade PASSED" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru |  Write-Host -ForegroundColor Green    
                                 }
                                 Else
                                 {
									CoreLib_WriteLog -Value " Blade $Blade FAILED!!!" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru |  Write-Host -ForegroundColor Red
                                    CoreLib_WriteLog -Value " Current cycle $Cycle ($CurrentFail CYCLES FAILURE) - Blade $Blade FAILED!!! `n	$EventDesc" -Function $FunctionInfo.Name  -LogFile $ERROR_FILE -PassThru
                                    $FoundError = $true 
                                 }
                            }
                            #-------------------------
                            # Append to SEL log file
                            #-------------------------
                            Add-Content -Value $_.EventDescription -Path "$ChildLogDirectory\Sel.log"
                        }
                        #-------------------------------------
                        # Verify found the correct SEL entry
                        #-------------------------------------
                        If (-NOT $FoundResult) 
                        {
                            CoreLib_WriteLog -Value " Blade $Blade FAILED!!! Did not find cycle test pass" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru |  Write-Host        
                            CoreLib_WriteLog -Value " Current cycle $Cycle - Blade $Blade FAILED!!! Did not find cycle test pass" -Function $FunctionInfo.Name  -LogFile $ERROR_FILE

                            $FoundError = $true 
                        }
                        #----------------------
                        # Clear the SEL
                        #----------------------wcscli
                        $Response = Invoke-WcsRest -TargetList localhost -Command "ClearBladeLog?bladeid=$Blade" -ErrorAction Stop  -SSL:$SSL 
                    }
                }
            }
            #----------------------------
            # Stop if found an error
            #----------------------------
            If ($FoundError)
            {
                $CurrentFail++
                CoreLib_WriteLog -Value (" Cycle {0} FAILED" -f $Cycle)    -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
                CoreLib_WriteLog -Value (" Cycle {0} FAILED of $NumberOfCycles " -f $Cycle)    -Function $FunctionInfo.Name -LogFile $ERROR_FILE

                If ($StopOnFail)
                {
                    CoreLib_WriteLog -Value "Stopping cycle test because found error and StopOnFail set" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru |  Write-Host       
                    CoreLib_WriteLog -Value "Stopping cycle test because found error and StopOnFail set" -Function $FunctionInfo.Name  -LogFile $ERROR_FILE       
                    break
                }
            }
            Else
            {
                CoreLib_WriteLog -Value (" Cycle {0} passed" -f $Cycle)   -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
            }
       }
      
    }
    # Exception for File not Found
	Catch [System.IO.DirectoryNotFoundException] # / System.Management.Automation.ItemNotFoundException
	{
		$_.ErrorDetails  = CoreLib_FormatException $_  -FunctionInfo $FunctionInfo
		CoreLib_WriteLog -Value $_.ErrorDetails -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE
		CoreLib_WriteLog -Value $_.ErrorDetails -Function $FunctionInfo.Name  -LogFile $ERROR_FILE
		Write-Host "Chassis Manager: Config file not found to verify SSL setting - {0}" -f $_.ErrorDetails -ForegroundColor Red  
	}
    #------------------------------------------------------------
    # Default Catch block to handle all errors
    #------------------------------------------------------------
    Catch
    {
        $_.ErrorDetails  = CoreLib_FormatException $_  -FunctionInfo $FunctionInfo

        CoreLib_WriteLog -Value $_.ErrorDetails -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE   
		CoreLib_WriteLog -Value $_.ErrorDetails -Function $FunctionInfo.Name  -LogFile $ERROR_FILE   

        #----------------------------------------------
        # Take action (do nothing if SilentlyContinue)
        #---------------------------------------------- 
        If      ($ErrorActionPreference -eq 'Stop')             { Throw $_ }
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
            
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-------------------------------------------------------------------------------------
# Cycle-WcsUpdate 
#-------------------------------------------------------------------------------------
Function Cycle-WcsUpdate() {

   <#
  .SYNOPSIS
   Cycles between two WCS update scripts

  .DESCRIPTION
   Cycles between two versions, typically N and N-1 BIOS.  OS reboots are done between the updates.
  
   On each cycle:
     (1) The config is read and compared against a reference config.  
     (2) The Windows System Event Log and BMC SEL are checked for suspect errors.

   By default results are stored in <InstallDir>\Results\Cycle-WcsUpdate\<Date-Time>\ directory
   Note the default <InstallDir> is \WcsTest

   RUN CYCLE-WCSUPDATE WITH THE SAME ACCOUNT USED FOR AUTO-LOGIN
   DO NOT LOGIN WITH ANOTHER ACCOUNT WHILE RUNNING

   To run this command the following must be setup beforehand:

       1.  Autologin must be enabled.  To enable run "Set-Autologin" or write the registry
           directly. 
       
       2.  A folder for each version of the update located under <InstallDir>\Scripts\Updates
           For example, \WcsTest\Scripts\Updates\BIOS\3B05 for BIOS version 3B05
          
       3.  A reference configuration file must exist for both versions of updates.  To generate 
           a reference config file run "Log-WcsConfig Update -Path <path>" 
           where <path> is the complete path to the update folder such as...

            \WcsTest\Scripts\Updates\BIOS\3B05\

            GENERATE THE REFERENCE CONFIG FILES WITH THE CORRECT CONFIG!! 

       4.  An WcsUpdate.ps1 in each  folder that does the complete  update.  

   Before each reboot there is a 30 second pause where the user can hit <Enter> to stop the 
   test.  

  .EXAMPLE
   Cycle-WcsUpdate -NumberOfCycles 200 -NewUpdate BIOS\3b07 -OldUpdate BIOS\3b05

   Executes 200 BIOS update and OS reboot cycles going between BIOS 3b05 and 3b07   

  .PARAMETER NumberOfCycles
   Number of cycles to run

  .PARAMETER NewUpdate
   Directory name of the new update.  Script updates to new update on odd counts.
   The complete path is <InstallDir>\Scripts\Updates\$NewUpdate

  .PARAMETER OldUpdate
   Directory name of the old update to flash.  Script updates to old update on even counts
   The complete path is <InstallDir>\Scripts\Updates\$OldUpdate

  .PARAMETER LogDirectory
   Logs results in this directory. If not specified logs results in:
   
    <InstallDir\Results\<FunctionName>\<DateTime>

  .PARAMETER IncludeSelFile
   XML file that contains SEL entries to include as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER ExcludeSelFile
   XML file that contains SEL entries to exclude as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER IncludeEventFile
   XML file that contains Windows System Events to include as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER ExcludeEventFile
   XML file that contains Windows System Events to exclude as suspect errors

   See <InstallDir>\Scripts\References for example file

  .PARAMETER StopOnFail
   If specified script stops when a failure occurs

  .PARAMETER Running
   For internal use only.  Do not specify.

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Cycle

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param(
                [Parameter(Mandatory=$true,Position=0)]  [int]     $NumberOfCycles,
                [Parameter(Mandatory=$true)]             [string]  $NewUpdate,
                [Parameter(Mandatory=$true)]             [string]  $OldUpdate,
                [Parameter(Mandatory=$false)]            [string]  $LogDirectory      ='',
                [Parameter(Mandatory=$false)]            [string]  $IncludeSelFile    =  '',
                [Parameter(Mandatory=$false)]            [string]  $ExcludeSelFile    =  '',
                [Parameter(Mandatory=$false)]            [string]  $IncludeEventFile  =  '',
                [Parameter(Mandatory=$false)]            [string]  $ExcludeEventFile  =  '',
                                                         [switch]  $StopOnFail,
                                                         [switch]  $Running
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #------------------------------------------------
        # Verify not running in WinPE
        #------------------------------------------------
        If (CoreLib_IsWinPE)
        {
            Throw "This function does not run in the WinPE OS"
        }
        #-------------------------------------------------------
        # Setup vars and constants
        #-------------------------------------------------------
        $STARTUP_BAT   = "$WCS_OS_STARTUP_DIRECTORY\Cycle-WcsUpdate.Bat" 
        $ConfigResult  = $null
        $ErrorCount    = 0
        $CurrentFail   = 0
        $CurrentPass   = 0

        $LogDirectory  = BaseLib_GetLogDirectory $LogDirectory $FunctionInfo.Name

        $SUMMARY_FILE    = "$LogDirectory\CycleUpdate-Summary.log"
        $COUNT_FILE      = "$LogDirectory\CycleUpdate-Count.log"
        $OldUpdatePath   = "$WCS_UPDATE_DIRECTORY\$OldUpdate"
        $NewUpdatePath   = "$WCS_UPDATE_DIRECTORY\$NewUpdate"
        #-------------------------------------------------------------------
        #  Display Message
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host
        CoreLib_WriteLog -Value  (" Cycle-WcsUpdate: Cycle start time {0}" -f (Get-Date -Format G))     -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
        CoreLib_WriteLog -Value  $WCS_HEADER_LINE   -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host

        #-----------------------------------------------------------
        # Check for the config files before starting
        #-----------------------------------------------------------
        If (-NOT (Test-Path "$OldUpdatePath\Update.config.xml" ))
        {
            Throw "Could not find configuration file '$OldUpdatePath\Update.config.xml'"  
        }
        If (-NOT (Test-Path "$NewUpdatePath\Update.config.xml" ))
        {
            Throw "Could not find configuration file '$NewUpdatePath\Update.config.xml'"  
        }
        #-----------------------------------------------------------
        # If starting make the setup .bat file and reboot
        #----------------------------------------------------------- 
        If (-NOT $Running)
        {
            #-----------------------------------------------------------
            # Verify autologin enabled
            #-----------------------------------------------------------
            If (-NOT (AutoLoginEnabled))
            {
                Throw "Autlogin is not enabled.  Please enable Autologin using regedit or Set-Autologin" 
            }
            #-----------------------------------------------------------
            # Setup the startup file for next cycle
            #-----------------------------------------------------------
            $CommandToRun = "powershell -command . $WCS_SCRIPT_DIRECTORY\wcsscripts.ps1;cycle-wcsupdate  $NumberOfCycles -new $NewUpdate -old $OldUpdate -LogDirectory $LogDirectory  -StopOnFail:`$$StopOnFail -Running"  
 
            #Remove any old cycling files

            Remove-Item "$WCS_OS_STARTUP_DIRECTORY\Cycle-*.*"  -Force -ErrorAction SilentlyContinue | Out-Null
      
            Set-Content -Value  $CommandToRun  -Path $STARTUP_BAT

            $CurrentCycle = 0
        }
        #-----------------------------------------------------------
        # Else get the current cycle
        #-----------------------------------------------------------
        Else
        {
            If (-NOT (Test-Path $STARTUP_BAT))
            {
                Throw "Did not find the startup bat file. DO NOT USE -Running"  
            }

            If (-NOT (Test-Path $COUNT_FILE))
            {
                Throw "Aborting script because could not find the count file '$COUNT_FILE'"  
            }

            $CycleFileContent = (Get-Content $COUNT_FILE)
            
            $CurrentCycle =  ([int] $CycleFileContent.split()[0]) + 1
            $CurrentFail  =  [int] $CycleFileContent.split()[1]
            $CurrentPass  =  [int] $CycleFileContent.split()[2]
                     
#            $CurrentCycle  = (Get-Content $COUNT_FILE)
#            $CurrentCycle  = ([int] $CurrentCycle) + 1
        }
        #----------------------------------------------------------------------------------------------
        # If even count then update to the old update,  So on first cycle (0) updates to the old update
        #----------------------------------------------------------------------------------------------
        If (0 -eq ($CurrentCycle % 2))
        {
            $RefUpdateConfig       = Get-WcsConfig Update -Path $OldUpdatePath
            $UpdateArgs            = "$NewUpdatePath\$WCS_UPDATE_SCRIPTFILE"
        }
        Else
        {
            $RefUpdateConfig       = Get-WcsConfig Update -Path $NewUpdatePath
            $UpdateArgs            = "$OldUpdatePath\$WCS_UPDATE_SCRIPTFILE"
        }
        #-----------------------------------------------------------
        # Make a folder for the logs
        #----------------------------------------------------------- 
        $ErrorDirectory = ("$LogDirectory\Cycle{0}" -f $CurrentCycle)

        New-Item $ErrorDirectory -ItemType Container -ErrorAction SilentlyContinue | Out-Null

        #-------------------------------------------------------------------
        #  Display Message
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value  " Current cycle $CurrentCycle of $NumberOfCycles ($CurrentFail CYCLES FAILED)"     -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  -PassThru | Write-Host
        CoreLib_WriteLog -Value  " Log directory $ErrorDirectory" -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE    -PassThru | Write-Host

        #----------------------------------------------------------------------------------
        # If start of test just backup and clear event logs, else backup and check for 
        # event logs for errors and check the configuration too
        #----------------------------------------------------------- ----------------------
        If (0 -eq $CurrentCycle) 
        {
            If (0 -ne (Clear-WcsError))
            {
                $ErrorCount++
                CoreLib_WriteLog -Value(" Could not clear error logs. See results in {0}" -f $ErrorDirectory)  -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host 
            }
        }
        Else
        {
            $EventErrors = Check-WcsError -LogDirectory $ErrorDirectory -IncludeEventFile $IncludeEventFile -ExcludeEventFile $ExcludeEventFile -IncludeSelFile $IncludeSelFile -ExcludeSelFile $ExcludeSelFile 

            If (0 -ne $EventErrors)
            {
                $ErrorCount++
                CoreLib_WriteLog -Value (" Cycle {0} had errors in the event logs. See results in {1}" -f  $CurrentCycle, $ErrorDirectory)  -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host 
            }

            If (0 -ne (Clear-WcsError))
            {
                $ErrorCount++
                CoreLib_WriteLog -Value(" Could not clear error logs. See results in {0}" -f $ErrorDirectory)  -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host 
            }

 
            $Mismatches = Compare-WcsConfig -RefConfig $RefUpdateConfig -RefToResults ([ref] $ConfigResult) -Exact

            If  (0 -ne $Mismatches)
            {
                $ErrorCount++
                CoreLib_WriteLog -Value (" Cycle {0} had configuration mismatch. See results in {1}" -f  $CurrentCycle, $ErrorDirectory) -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host  
                Log-WcsConfig -Config $ConfigResult -File ConfigMisMatch -Path $ErrorDirectory
            }
        }
        #-----------------------------------------------------------
        # Update  
        #----------------------------------------------------------- 
        CoreLib_WriteLog -Value (" Starting update '$UpdateArgs' at {0}" -f  (Get-Date -Format G)) -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host  

        $ReturnCode = & "$UpdateArgs"

        CoreLib_WriteLog -Value ' ' -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host

        If (0 -ne $ReturnCode)
        {
            $ErrorCount++ 
            CoreLib_WriteLog -Value (" Update failed at {1}.  Returned code {2}" -f  $CurrentCycle,(Get-Date -Format G),$ReturnCode)  -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host  
        }
        Else
        {
            CoreLib_WriteLog -Value (" Update successful at {1}" -f  $CurrentCycle,(Get-Date -Format G))  -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host  
        }
        #-----------------------------------------------------------
        # If reached the number of cycles then stop
        #-----------------------------------------------------------
        If ($CurrentCycle -ge $NumberOfCycles)  
        {
            CoreLib_WriteLog -Value (" Stopping cycle testing at {0}" -f (Get-Date)) -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host    
            Remove-Item $STARTUP_BAT -Force -ErrorAction SilentlyContinue | Out-Null
            Return  $WCS_RETURN_CODE_SUCCESS 
        }
        #-----------------------------------------------------------
        # If have errors and stop on fail then stop
        #-----------------------------------------------------------
        ElseIf  (($ErrorCount -ne 0) -and ($StopOnFail))
        {
            CoreLib_WriteLog -Value  (" Aborting cycle testing because error found and StopOnFail true. Time: {0}" -f (Get-Date)) -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host 
            Remove-Item $STARTUP_BAT -Force -ErrorAction SilentlyContinue | Out-Null
            Return 1 
        }
        #-----------------------------------------------------------
        # Reboot
        #-----------------------------------------------------------
        else
        {
            CoreLib_WriteLog -Value ' ' -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host

            If  ($ErrorCount -eq 0) 
            { 
                $CurrentPass++
                CoreLib_WriteLog -Value (" Cycle {1} passed.    Rebooting at {0}" -f (Get-Date -Format G),$CurrentCycle)   -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
            }
            Else                    
            { 
                $CurrentFail++
                CoreLib_WriteLog -Value (" Cycle {1} FAILED.    Rebooting at {0}" -f (Get-Date -Format G),$CurrentCycle)    -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE   -PassThru | Write-Host
            }

            Set-Content -Value "$CurrentCycle $CurrentFail $CurrentPass" -Path $COUNT_FILE 

            Write-Host  "`n`r`n`r Hit <ENTER> to abort testing`r`n`r`n"

            For ($TimeOut=0;$TimeOut -lt 60;$TimeOut++)
            {
                Start-Sleep -Milliseconds 500
                if ([console]::KeyAvailable)
                {
                    [console]::ReadLine()
                    CoreLib_WriteLog -Value  (" User aborted testing. Time: {0}" -f (Get-Date))    -Function $FunctionInfo.Name -LogFile $SUMMARY_FILE  -PassThru | Write-Host
                    Remove-Item $STARTUP_BAT -Force -ErrorAction SilentlyContinue | Out-Null
                    Return $WCS_RETURN_CODE_INCOMPLETE 
                }
            }            
            shutdown.exe /r /t 1   | Out-Null  
        }

        Return  $WCS_RETURN_CODE_SUCCESS  
    }
    #------------------------------------------------------------
    # Default Catch block to handle all errors
    #------------------------------------------------------------
    Catch
    {
        $_.ErrorDetails  = CoreLib_FormatException $_  -FunctionInfo $FunctionInfo
        
        CoreLib_WriteLog -Value $_.ErrorDetails -Function $FunctionInfo.Name  -LogFile $SUMMARY_FILE  

        #----------------------------------------------
        # Take action (do nothing if SilentlyContinue)
        #---------------------------------------------- 
        If      ($ErrorActionPreference -eq 'Stop')             { Throw $_ }
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}
