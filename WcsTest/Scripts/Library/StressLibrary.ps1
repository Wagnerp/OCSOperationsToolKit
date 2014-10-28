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
# Run-IOmeter 
#-------------------------------------------------------------------------------------
Function Run-IOmeter() {

   <#
  .SYNOPSIS
   Runs an IO stress test using the IOmeter IO benchmark

  .DESCRIPTION
   Runs the IOmeter IO benchmark for the time specified.
   
   If -NoWait specified then does not wait for completion.  If do not wait then
   run Verify-Iometer after test completes to check the log files
   
   By default runs on all physical drives with 0 partitions and all
   logical drives except c:  To test the c: drive specify -full

  .EXAMPLE
   Run-IOmeter -TimeInMin 60

   Runs IOmeter for 60 minutes on all drives except c: and all physical
   disks without a partition

  .EXAMPLE
   Run-IOmeter -TimeInMin 60 -NoWait -Full

   Runs IOmeter for 60 minutes on all drives including c: and all physical
   disks without a partition.  Does not wait for test completion.

   Must run Verify-Iometer after 60 minutes to determine test results.

   Returns 0 if passes, non-zero if fails

  .PARAMETER TimeInMin
   Time to run the stress in minutes

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

   IF USING THE -NOWAIT OPTION THEN MUST USE THE SAME VALUE IN VERIFY-IOMETER

  .PARAMETER Full
   Includes C: drive in the testing

  .PARAMETER NoWait
   Does not wait for testing to complete.  Run Verify-IOmeter after testing
   completes to verify test passed

   .OUTPUTS
   Returns number of errors

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Stress

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]     [int]     $TimeInMin = 1,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]    [string]  $LogDirectory='',
                                                                   [switch]  $Full,
                                                                   [switch]  $NoWait,
                                                                   [switch]  $RunAsChild
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

        If (-NOT $RunAsChild)
        {
            Write-Host (" Running IO stress with {0}`r`n`r" -f $FunctionInfo.Name)
        }
        #------------------------------------------------
        # Verify application installed
        #------------------------------------------------
        If (-NOT (Test-Path $WCS_IOMETER_BINARY))
        {
            Throw "IOMeter application not installed"
        }

        #-------------------------------------------------------
        # Setup vars and log directory
        #-------------------------------------------------------
        $LogDirectory       = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)
        $ErrorCount         = 0
        $ScriptError        =  $False
        $ResultsFile        = "$LogDirectory\$WCS_IOMETER_RESULTS_FILE"
        $LocalLogFile       = "$LogDirectory\Run-Iometer.log"

        Remove-Item $ResultsFile        -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-Item $LocalLogFile       -Force -ErrorAction SilentlyContinue | Out-Null

        CoreLib_WriteLog -Value ("{0}`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile

        #-------------------------------------------------------------------
        #  Accept the license
        #-------------------------------------------------------------------
        If (-Not (Test-Path HKCU:\Software\iometer.org\Iometer\Settings))
        {
            New-Item HKCU:\Software\iometer.org\Iometer\Settings -Force | Out-Null
        }
        Set-ItemProperty -path HKCU:\Software\iometer.org\Iometer\Settings -name Version -value "2006.07.27" | Out-Null

        #-------------------------------------------------------------------
        #  Get the drives
        #-------------------------------------------------------------------
        $Targets = @()

        Get-WcsPhysicalDisk | Where-Object { $_ -ne $null } | ForEach-Object {

            $Disk     = $_.Replace("\\.\PHYSICALDRIVE","PHYSICALDRIVE:")
            $Targets += $Disk
            
            CoreLib_WriteLog -Value " Testing physical disk '$Disk'" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
        }
        $Drives = Get-WcsLogicalDrive -Full:$Full

        $Drives | Where-Object { $_ -ne $null } | ForEach-Object {

            $Drive = $_
             
            Copy-Item $WCS_IO_TEST_FILE  "$Drive\iobw.tst"  -Force -ErrorAction Stop
            
            if (-NOT (Test-Path "$Drive\iobw.tst"))
            {
                 CoreLib_WriteLog -Value "RUN-IOMETER FAILED: Could not create $Drive\iobw.tst"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host

                $ScriptError  = $true
                Break # ForEach-Object
            }

             CoreLib_WriteLog -Value " Testing logical drive '$Drive'" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose

            $Targets += $Drive
        }

        # Return scope only one level so can't return inside of foreach

        If ($ScriptError) 
        { 
            Return $WCS_RETURN_CODE_GENERIC_ERROR 
        }

        If ($Targets.Count -eq 0)
        {
            CoreLib_WriteLog -Value " RUN-IOMETER FAILED: no drives to test"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host -ForegroundColor Yellow
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }


        #-------------------------------------------------------------------
        #  Setup the config file
        #-------------------------------------------------------------------

    $ConfigFileData = @"
Version 2006.07.27 
'TEST SETUP ====================================================================
'Test Description
    
'Run Time
'	hours      minutes    seconds
    0          $TimeInMin      0
'Ramp Up Time (s)
    0
'Default Disk Workers to Spawn
    NUMBER_OF_CPUS
'Default Network Workers to Spawn
    0
'Record Results
    ALL
'Worker Cycling
'	start      step       step type
    1          1          LINEAR
'Disk Cycling
'	start      step       step type
    1          1          LINEAR
'Queue Depth Cycling
'	start      end        step       step type
    1          32         2          EXPONENTIAL
'Test Type
    NORMAL
'END test setup
'RESULTS DISPLAY ===============================================================
'Update Frequency,Update Type
    0,WHOLE_TEST
'Bar chart 1 statistic
    Total I/Os per Second
'Bar chart 2 statistic
    Total MBs per Second
'Bar chart 3 statistic
    Average I/O Response Time (ms)
'Bar chart 4 statistic
    Maximum I/O Response Time (ms)
'Bar chart 5 statistic
    % CPU Utilization (total)
'Bar chart 6 statistic
    Total Error Count
'END results display
'ACCESS SPECIFICATIONS =========================================================
'Access specification name,default assignment
    Stress-RW,NONE
'size,% of size,% reads,% random,delay,burst,align,reply
    8192,100,90,100,0,1,0,0
'Access specification name,default assignment
    Stress-RO,NONE
'size,% of size,% reads,% random,delay,burst,align,reply
    8192,100,100,100,0,1,0,0
'END access specifications
'MANAGER LIST ==================================================================
'Manager ID, manager name
    1,MARKSAN
'Manager network address
    10.120.116.223

"@

    for ($worker=0;$worker -lt $Targets.Count ;$worker++)
    {
      $target = $targets[$worker]

    $ConfigFileData += @"
'Worker
    Worker $worker
'Worker type
    DISK
'Default target settings for worker
'Number of outstanding IOs,test connection rate,transactions per connection
    1,DISABLED,1
'Disk maximum size,starting sector
    0,0
'End default target settings for worker
'Assigned access specs
    Stress-RW
'End assigned access specs
'Target assignments
'Target
    $Target
'Target type
    DISK
'End target
'End target assignments
'End worker

"@
    }

    $ConfigFileData += @"
'End manager
'END manager list
Version 2006.07.27 
"@

        Set-Content -Path  $WCS_IOMETER_CONFIG  -Value $ConfigFileData

        #-------------------------------------------------------------------
        #  Start IOmeter
        #-------------------------------------------------------------------
         CoreLib_WriteLog -Value "Starting '$WCS_IOMETER_BINARY /c $WCS_IOMETER_CONFIG  /r $ResultsFile'" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
   
        $Process,$ProccessOut,$ProcessErr = BaseLib_StartProcess $WCS_IOMETER_BINARY " /c $WCS_IOMETER_CONFIG  /r   $ResultsFile" "IOmeterFinishedEvent"

        If ($null -eq $Process)
        {
            CoreLib_WriteLog -Value "RUN-IOMETER FAILED: IOmeter did not start" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        #-------------------------------------------------------------------
        #  If nowait specified return without waiting for IOmeter to finish
        #-------------------------------------------------------------------
        if ($NoWait) 
        { 
            CoreLib_WriteLog -Value " IOmeter still running. Wait $TimeInMin minutes for IOmeter to finish then run Verify-Iometer to check results `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
            Return $WCS_RETURN_CODE_SUCCESS
        }

        #-------------------------------------------------------------------
        #  Wait the specified time then verify it completed fine
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value " Waiting $TimeInMin minutes for IOmeter to complete"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose

        Start-Sleep -Seconds (60*$TimeInMin)

        $ErrorCount = Verify-IOmeter -LogDirectory $LogDirectory -RunAsChild 

        If (0 -ne $ErrorCount)
        {
            CoreLib_WriteLog -Value "FAILED!!! `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile  
            Write-Host -ForegroundColor Red "`r`n RUN-IOMETER failed `r`n" 
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        Else 
        { 
            CoreLib_WriteLog -Value $WCS_TEST_PASS_SIGNATURE  -Function $FunctionInfo.Name  -Log $LocalLogFile 
            Write-Host  "`r`n RUN-IOMETER  $WCS_TEST_PASS_SIGNATURE  `r`n" 
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}
#-------------------------------------------------------------------------------------
# Verify-IOmeter 
#-------------------------------------------------------------------------------------
Function Verify-IOmeter() {
   <#
  .SYNOPSIS
   Verifies an IO stress test started with Run-IOmeter and -NoWait 

  .DESCRIPTION 
   Verifies an IO stress test started with Run-IOmeter and -NoWait 

   Waits up to -TimeOutInSec for all instances of IOmeter.exe 
   and Dynamo.exe to stop.  If don't stop before timeout then kills 
   them and returns and error.

   Verifies the log file exists and lists no errors

   Returns 0 if passes, non-zero if fails

  .EXAMPLE
   Run-IOmeter -Time 60 -LogDirectory Test -NoWait

   Verify-IOmeter  -LogDirectory Test

   Verifies the IOmeter run passed. Note LogDirectory must be the same for both
   Run-IOmeter and Verify-IOmeter

  .PARAMETER TimeOutInSec
   Number of seconds to wait for application to exit.  Default 120 

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

   USE THE SAME VALUE USED IN RUN-IOMETER -NOWAIT

  .OUTPUTS
   Returns number of errors

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Stress
   #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    ( 
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]    [string]  $LogDirectory      = '',
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]    [int]     $TimeOutInSec      = 120,
                                                                   [switch]  $RunAsChild
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
        # Setup vars 
        #-------------------------------------------------------
        $LogDirectory = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)

        $ErrorCount    = 0

        If (-NOT (Test-Path "$LogDirectory")) 
        { 
            Write-Host "VERIFY-IOMETER FAILED: Could not find log directory specified '$LogDirectory'"  
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        $ResultsFile        = "$LogDirectory\$WCS_IOMETER_RESULTS_FILE"  
        $LocalLogFile       = "$LogDirectory\Run-Iometer.log"
        
        CoreLib_WriteLog -Value ("{0}`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile

        #-------------------------------------------------------
        # Wait for the processes to exit
        #-------------------------------------------------------
        For ($Timeout=0;$Timeout -lt $TimeOutInSec; $Timeout++)
        {
            $DiskStressProcesses = [array] (Get-Process -Name "IOmeter*" -ErrorAction SilentlyContinue) + (Get-Process -Name "Dynamo*" -ErrorAction SilentlyContinue)
            If ($null -eq $DiskStressProcesses) 
            { 
                break # For statement
            }
            Start-Sleep 1
        }

        #-------------------------------------------------------
        # If did not exit log error and kill them
        #-------------------------------------------------------
        If ($null -ne $DiskStressProcesses) 
        {
            CoreLib_WriteLog -Value " RUN-IOMETER FAILED: IOmeter did not finish" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru |  Write-Host -ForegroundColor Red
            ForEach ($DiskStressProcess in $DiskStressProcesses) { $DiskStressProcess.Kill() }
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }

        #-------------------------------------------------------
        # Check the output file
        #-------------------------------------------------------
        If (-Not (Test-Path $ResultsFile ))
        {
            CoreLib_WriteLog -Value " RUN-IOMETER FAILED:  Could not find IOmeter log file '$ResultsFile'"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host -ForegroundColor Red  
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        Else
        {
            Get-Content $ResultsFile | Where-Object { $_ -ne $null } | ForEach-Object {
            
                $Fields = $_.split(',')

                If (($Fields[0] -eq 'ALL') -and ($Fields[24] -ne 0))
                {
                    CoreLib_WriteLog -Value " RUN-IOMETER FAILED: Log file '$ResultsFile' had errors"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru |  Write-Host -ForegroundColor Red
                    $ErrorCount++
                }
            }
        }
        If (-NOT $RunAsChild)
        {
            If (0 -ne $ErrorCount)
            {
                CoreLib_WriteLog -Value "FAILED!!! `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile  
                Write-Host -ForegroundColor Red "`r`n RUN-IOMETER failed `r`n" 
                Return $WCS_RETURN_CODE_GENERIC_ERROR
            }
            Else 
            { 
                CoreLib_WriteLog -Value $WCS_TEST_PASS_SIGNATURE  -Function $FunctionInfo.Name  -Log $LocalLogFile 
                Write-Host  "`r`n RUN-IOMETER  $WCS_TEST_PASS_SIGNATURE  `r`n" 
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-------------------------------------------------------------------
# Run-DiskSpeed
#-------------------------------------------------------------------
Function Run-DiskSpeed()
{
   <#
  .SYNOPSIS
   Starts an IO stress test using DiskSpd

  .DESCRIPTION 
   Starts an IO stress test using DiskSpd. Starts one instance of DiskSpd
   for each disk tested.
   
   If -NoWait specified then does not wait for completion.  If do not wait then
   run Verify-DiskSpeed after test completes to check the log files
   
   By default runs on all physical drives with 0 partitions and all
   logical drives except c:  To test the c: drive specify -Full

   Returns 0 if passes and non-zero if fails

  .EXAMPLE
   Start-DiskSpeed  -TimeInMin 60 -LogDirectory Test001

   Runs DiskSpd for 60 minutes and stores logs in \WcsTest\Results\Test001

  .PARAMETER TimeInMin
   Time to run the stress in minutes

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

   IF USING THE -NOWAIT OPTION THEN USE THE SAME VALUE IN VERIFY-DISKSPEED

  .PARAMETER Full
   Includes C: drive in the testing

  .PARAMETER NoWait
   Does not wait for testing to complete.  Run Verify-DiskSpeed after testing
   completes to verify test passed

  .OUTPUTS
   Returns number of errors

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Stress
   #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    ( 
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]   [int]     $TimeInMin = 1,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]  [string]  $LogDirectory='',
                                                                 [switch]  $Full,
                                                                 [switch]  $NoWait,
                                                                 [switch]  $RunAsChild
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        If (-NOT $RunAsChild)
        {
            Write-Host (" Running IO stress with {0}`r`n`r" -f $FunctionInfo.Name)
        }
        #------------------------------------------------
        # Verify application installed
        #------------------------------------------------
        If (-NOT (Test-Path $WCS_DISK_SPEED_BINARY))
        {
            Throw "DiskSpd application not installed"
        }

        #-------------------------------------------------------
        # Setup vars 
        #-------------------------------------------------------
        $LogDirectory       = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)
        $ErrorCount         = 0
        $ScriptError        =  $False
        $StressTimeInSec    = 60 * $TimeInMin
        $LocalLogFile       = "$LogDirectory\Run-DiskSpeed.log"

        Remove-Item "$LogDirectory\DiskSpd*" -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-Item  $LocalLogFile -Force -ErrorAction SilentlyContinue | Out-Null


        CoreLib_WriteLog -Value ("{0}`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile

        #-------------------------------------------------------
        # Start an instance for the physical disks 
        #-------------------------------------------------------
        $Disks = Get-WcsPhysicalDisk | Where-Object { $_ -ne $null } 
        
        $Disks | ForEach-Object {

            $Disk = $_

            $ProcessArgs = ("-d{0} -b8k -t1 #{1}" -f $StressTimeInSec,$Disk.Replace("\\.\PHYSICALDRIVE",""))
 
            $Process = Start-Process  $WCS_DISK_SPEED_BINARY  $ProcessArgs -PassThru -RedirectStandardOutput ("$LogDirectory\DiskSpd_{0}.log" -f $Disk.Replace("\\.\","")) -RedirectStandardError ("$LogDirectory\DiskSpd_{0}.Err" -f $Disk.Replace("\\.\",""))

            If ($null -eq $Process)
            {
                CoreLib_WriteLog -Value " RUN-DISKSPEED FAILED: $WCS_DISK_SPEED_BINARY $ProcessArgs did not start `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host 
                $ScriptError = $true
            }
            Else
            {
                CoreLib_WriteLog -Value "$WCS_DISK_SPEED_BINARY $ProcessArgs started"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
            }
        }
        If ($ScriptError) 
        {
            Return $WCS_RETURN_CODE_GENERIC_ERROR 
        }
        #-------------------------------------------------------
        # Start an instance for the  logical drives 
        #-------------------------------------------------------
        $Drives = Get-WcsLogicalDrive -Full:$Full
        
        $Drives | Where-Object { $_ -ne $null } | ForEach-Object {
        
            $Drive      = $_
            $TargetFile = "$Drive\testdata.dat"

            Copy-Item $WCS_IO_TEST_FILE  $TargetFile  -Force -ErrorAction Stop | Out-Null

            if (-NOT (Test-Path $TargetFile))
            {
                CoreLib_WriteLog -Value " RUN-DISKSPEED FAILED:: could not create $TargetFile `r`n " -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
                $ScriptError = $true
                Break # ForEach-Object
            }

            $ProcessArgs = ("-d{0}  -b8k -t1 {1}" -f $StressTimeInSec,$TargetFile )

            $Process = Start-Process $WCS_DISK_SPEED_BINARY $ProcessArgs  -PassThru -RedirectStandardOutput ("$LogDirectory\DiskSpd_{0}.log" -f $Drive.TrimEnd(":"))  -RedirectStandardError ("$LogDirectory\DiskSpd_{0}.Err" -f $Drive.TrimEnd(":"))

            If ($null -eq $Process)
            {
                CoreLib_WriteLog -Value " RUN-DISKSPEED FAILED: $WCS_DISK_SPEED_BINARY $ProcessArgs did not start`r`n "  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
                $ScriptError = $true
                Break # ForEach-Object
            }
            Else
            {
                CoreLib_WriteLog -Value "$WCS_DISK_SPEED_BINARY $ProcessArgs started"   -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
            }
        }
        If ($ScriptError) 
        {
            Return $WCS_RETURN_CODE_GENERIC_ERROR 
        }

        If (($Disks -eq $null) -and ($Drives -eq $null))
        {
            CoreLib_WriteLog -Value " RUN-DISKSPEED FAILED: No drives to test `r`n "  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
                
        #-------------------------------------------------------------------
        #  If nowait specified return without waiting to finish
        #-------------------------------------------------------------------
        if ($NoWait) 
        { 
            CoreLib_WriteLog -Value " Exit before complete. Wait $TimeInMin minutes for stress to finish then run Verify-DiskSpeed to check results `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
            Return $WCS_RETURN_CODE_SUCCESS
        }

        #-------------------------------------------------------------------
        #  Wait the specified time then verify it completed fine
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value " Waiting $TimeInMin minutes for DiskSpd to complete"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose

        Start-Sleep -Seconds (60*$TimeInMin)

        $ErrorCount = Verify-DiskSpeed -LogDirectory $LogDirectory -RunAsChild 

        If (0 -ne $ErrorCount)
        {
            CoreLib_WriteLog -Value "FAILED!!! `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile  
            Write-Host -ForegroundColor Red "`r`n RUN-DISKSPEED failed `r`n" 
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        Else 
        { 
            CoreLib_WriteLog -Value $WCS_TEST_PASS_SIGNATURE  -Function $FunctionInfo.Name  -Log $LocalLogFile 
            Write-Host  "`r`n RUN-DISKSPEED  $WCS_TEST_PASS_SIGNATURE  `r`n" 
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-------------------------------------------------------------------
# Verify-DiskSpeed 
#-------------------------------------------------------------------
Function Verify-DiskSpeed()
{
   <#
  .SYNOPSIS
   Verifies an IO stress test started with Run-DiskSpeed and -NoWait 

  .DESCRIPTION 
   Verifies an IO stress test started with Run-DiskSpeed and -NoWait 

   Waits up to -TimeOutInSec for all instances of DksSpd.exe to stop
   If don't stop before timeout then kills them and returns and error.

   Verifies the log file exists and lists no errors

   Returns 0 if passes, non-zero if fails

  .EXAMPLE
   Run-DiskSpeed -Time 60 -LogDirectory Test -NoWait

   Verify-DiskSpeed  -LogDirectory Test

   Verifies the DiskSpeed run passed. Note LogDirectory must be the same for both
   Run-DiskSpeed and Verify-DiskSpeed

  .PARAMETER TimeOutInSec
   Number of seconds to wait for application to exit.  Default 120 

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

   USE THE SAME VALUE USED IN RUN-DISKSPEED -NOWAIT

  .OUTPUTS
   Returns number of errors

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Stress

   #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    ( 
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]   [string]  $LogDirectory='',
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]   [int]     $TimeOutInSec=120,
                                                                  [switch]  $RunAsChild
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Setup vars 
        #-------------------------------------------------------
        $LogDirectory  = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)
        $ErrorCount    = 0


        If (-NOT (Test-Path $LogDirectory)) 
        { 
            Write-Host "VERIFY-DISKSPEED FAILED: Could not find log directory specified '$LogDirectory'" 
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
 
        $LocalLogFile = "$LogDirectory\Run-DiskSpeed.log"

        CoreLib_WriteLog -Value ("{0}`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile
        #------------------------------------------------------- 
        # Wait for the processes to exit
        #-------------------------------------------------------
        For ($Timeout=0;$Timeout -lt $TimeoutInSec; $Timeout++)
        {
            $DiskSpeedProcesses = [array] (Get-Process -Name "DiskSpd*" -ErrorAction SilentlyContinue)  
            If ($null -eq $DiskSpeedProcesses ) 
            { 
                break # For
            }
            Start-Sleep 1
        }
        #-------------------------------------------------------
        # If did not exit log error and kill them
        #-------------------------------------------------------
        If ($null -ne $DiskSpeedProcesses) 
        {
            CoreLib_WriteLog -Value  " RUN-DISKSPEED FAILED: diskspd.exe did not finish `r`n "  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host 
            ForEach ($DiskSpeedProcess in $DiskSpeedProcesses) { $DiskSpeedProcess.Kill() }
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        #-------------------------------------------------------
        # Check the logs created for errors
        #-------------------------------------------------------
        $LogCount = 0
        Get-Item "$LogDirectory\DiskSpd*.err" | Where-Object { $_ -ne $null } | ForEach-Object {
        
            $Log = $_
            $LogCount++

            If ((Get-Content -Path $Log) -ne $null)
            {
                $ErrorCount++
                CoreLib_WriteLog -Value (" RUN-DISKSPEED FAILED: Diskspd error message logged in file {0} `r`n" -f  $Log)  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
            }
        } 
        If (0 -eq $LogCount)
        {
            CoreLib_WriteLog -Value " RUN-DISKSPEED FAILED: no log files found `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        If (-NOT $RunAsChild)
        {
            If (0 -ne $ErrorCount)
            {
                CoreLib_WriteLog -Value "FAILED!!! `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile  
                Write-Host -ForegroundColor Red "`r`n RUN-DISKSPEED failed `r`n" 
                Return $WCS_RETURN_CODE_GENERIC_ERROR
            }
            Else 
            { 
                CoreLib_WriteLog -Value $WCS_TEST_PASS_SIGNATURE  -Function $FunctionInfo.Name  -Log $LocalLogFile 
                Write-Host  "`r`n RUN-DISKSPEED  $WCS_TEST_PASS_SIGNATURE  `r`n" 
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-------------------------------------------------------------------------------------
# Run-Prime95 
#-------------------------------------------------------------------------------------
Function Run-Prime95() {

   <#
  .SYNOPSIS
   Runs Prime95

  .DESCRIPTION
   Runs Prime95 for time specified.  At end of time kills Prime95 and checks the
   results file for errors

  .EXAMPLE
   Runs Prime95 -TimeInMin 60

   Runs prime95 for 60 minutes

  .PARAMETER TimeInMin
   Time to run the stress in minutes

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

   IF USING THE -NOWAIT OPTION THEN USE THE SAME VALUE IN VERIFY-PRIME95
  
  .PARAMETER LimitThread
   Limits the worker threads to specified value

  .PARAMETER NoWait
   Does not wait for testing to complete.  Run Verify-Prime95 after testing
   completes to verify test passed

  .OUTPUTS
   Returns number of errors

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Stress
   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]    [int]    $TimeInMin,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]   [string] $LogDirectory  = '',
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]   [int]    $LimitThread   = -1,
                                                                  [switch] $NoWait,
                                                                  [switch] $RunAsChild
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        If (-NOT $RunAsChild)
        {
            Write-Host (" Running stress with {0}`r`n`r" -f $FunctionInfo.Name)
        }

        #------------------------------------------------
        # Verify application installed
        #------------------------------------------------
        If (-NOT (Test-Path $WCS_PRIME95_BINARY))
        {
            Throw "Prime95 application not installed"
        }
        #-------------------------------------------------------
        # Setup vars 
        #-------------------------------------------------------
        $StressTimeInSec = 60 * $TimeInMin
        $LogDirectory    = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)
 

        Remove-Item "$LogDirectory\Prime95_results.txt" -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-Item $WCS_PRIME95_RESULTS_FILE -Force -ErrorAction SilentlyContinue | Out-Null
        
        $LocalLogFile = "$LogDirectory\Run-Prime95.log"

        CoreLib_WriteLog -Value ("{0}`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile
        #-------------------------------------------------------------------
        #  Start Prime 95
        #-------------------------------------------------------------------
        If (-1 -eq $LimitThread) { $LimitThread = $env:NUMBER_OF_PROCESSORS }

        $MB_Per_Thread = [int] (0.9 * ((Get-WmiObject win32_operatingsystem).FreePhysicalMemory /1024) / $LimitThread )

        CoreLib_WriteLog -Value ("Using $LimitThread threads and $MB_Per_Thread  MB/thread`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile -Passthru | Write-Verbose


$Prime95File = @"
UsePrimenet=0
V24OptionsConverted=1
StressTester=1
MinTortureFFT=4096
MaxTortureFFT=4096
TortureTime=1
TortureMem=$MB_per_thread
"@
        Set-Content -Path $WCS_PRIME95_CONFIG -Value $Prime95File | Out-Null

$PrimeLocalFile = @"
NumCPUs=$LimitThread
CpuNumHyperthreads=1
"@
        Set-Content -Path $WCS_PRIME95_LOCAL_CONFIG -Value $PrimeLocalFile | Out-Null
        Set-Content -Path $WCS_PRIME95_RESULTS_FILE -Value " "             | Out-Null   
            
        $Process = Start-Process $WCS_PRIME95_BINARY  -PassThru -ArgumentList -t 
        If ($null -eq $Process)
        {
            CoreLib_WriteLog -Value " RUN-PRIME95 FAILED: Did not start `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host 
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        #-------------------------------------------------------------------
        #  If nowait specified return without waiting for finish
        #-------------------------------------------------------------------
        if ($NoWait) 
        { 
            Return $WCS_RETURN_CODE_SUCCESS
        }
        #-------------------------------------------------------------------
        #  Wait the specified time then verify it completed fine
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value " Waiting $TimeInMin minutes for Prime95 to complete"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
        Start-Sleep -Seconds (60*$TimeInMin)

        $ErrorCount = Verify-Prime95 -LogDirectory $LogDirectory -RunAsChild 

        If (0 -ne $ErrorCount)
        {
            CoreLib_WriteLog -Value "FAILED!!! `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile  
            Write-Host -ForegroundColor Red "`r`n RUN-PRIME95 failed `r`n" 
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        Else 
        { 
            CoreLib_WriteLog -Value $WCS_TEST_PASS_SIGNATURE  -Function $FunctionInfo.Name  -Log $LocalLogFile 
            Write-Host  "`r`n RUN-PRIME95  $WCS_TEST_PASS_SIGNATURE  `r`n" 
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-------------------------------------------------------------------
# Verify-Prime95 
#-------------------------------------------------------------------
Function Verify-Prime95()
{
   <#
  .SYNOPSIS
   Verifies a Prime95 stress test started with Run-Prime95 and -Nowait

  .DESCRIPTION 
   Verifies a Prime95 stress test started with Run-Prime95 and -Nowait

   Waits up to -TimeOutInSec for Prime95 to stop.  If don't stop before 
   timeout then kills them and returns an error.

  .EXAMPLE
   Run-Prime95 -TimeInMin 30  -NoWait

   Verify-Prime95

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

   IF USING THE -NOWAIT OPTION THEN USE THE SAME VALUE IN RUN-PRIME95

  .OUTPUTS
   Returns number of errors

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Stress

   #>

    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]   [string]  $LogDirectory='',  
                                                                  [switch]  $RunAsChild
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Setup vars 
        #-------------------------------------------------------
        $LogDirectory = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)
 

        If (-NOT (Test-Path $LogDirectory)) 
        { 
            Write-Host "VERIFY-PRIME95 FAILED: Could not find log directory specified '$LogDirectory'" 
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
 
        $LocalLogFile = "$LogDirectory\Run-Prime95.log"
        CoreLib_WriteLog -Value ("{0}`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile

        #-------------------------------------------------------------------
        #  Close Prime95
        #-------------------------------------------------------------------
        $Prime95 = [array] (Get-Process -Name "Prime95*" -ErrorAction SilentlyContinue)  

        if ($null -eq $Prime95)
        {
            CoreLib_WriteLog -Value " RUN-PRIME95 FAILED: Prime95 exited early `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        else
        {
            CoreLib_WriteLog -Value "Stopping Prime95" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose

            For($Attempts = 0; $Attempts -lt 10; $Attempts++)
            {
                $Prime95.CloseMainWindow() | Out-Null

                Start-Sleep 3
                if ($Prime95.HasExited) 
                { 
                    break  #for
                }
            }
        
            if (-NOT ($Prime95.HasExited)) { 
                $Prime95.Kill() | Out-Null 
                Start-Sleep 20    
            }


            if (-NOT ($Prime95.HasExited)) 
            {
                CoreLib_WriteLog -Value " RUN-PRIME95 FAILED: Could not stop Prime95 `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
                $Prime95.Kill() | Out-Null
                Return $WCS_RETURN_CODE_GENERIC_ERROR
            }
        }
        #-------------------------------------------------------------------
        #  Check the Prime95 results file
        #-------------------------------------------------------------------
        If ( (Test-Path $WCS_PRIME95_RESULTS_FILE  ))
        {
            Copy-Item $WCS_PRIME95_RESULTS_FILE   "$LogDirectory\prime95_results.txt" -ErrorAction Stop | Out-Null

            $Prime95Results = Get-Content "$LogDirectory\prime95_results.txt"

            if ( ($Prime95Results.ToUpper().Contains("ERROR")) -or ($Prime95Results.ToUpper().Contains("FAIL")) )
            {
                CoreLib_WriteLog -Value " RUN-PRIME95 FAILED: Prime95 log had error `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
                Return $WCS_RETURN_CODE_GENERIC_ERROR
            }
        }
        Else
        {
                CoreLib_WriteLog -Value " RUN-PRIME95 FAILED: Prime95 log was not found `r`n"  -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host
                Return $WCS_RETURN_CODE_GENERIC_ERROR
        }

        If (-NOT $RunAsChild)
        {
            CoreLib_WriteLog -Value " RUN-PRIME95 $WCS_TEST_PASS_SIGNATURE `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host  
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-----------------------------------------------------------------------------
# Run-QuickStress 
#-----------------------------------------------------------------------------
Function Run-QuickStress()
{
   <#
  .SYNOPSIS
   Runs simple CPU, memory, and IO stress

  .DESCRIPTION 
   Runs Prime95 to generate CPU and memory stress.  
   
   For IO stress runs DiskSpd unless the IOmeter switch is specified

   Enter the time in minutes to run the stress.  

   See Run-QuickStress.log for details.

  .EXAMPLE
   Run-QuickStress -TimeInMin 60

   Runs CPU, memory, and IO stress for 60 minutes

  .PARAMETER TimeInMin
   Time to run the stress in minutes

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

   IF USING THE -NOWAIT OPTION THEN USE THE SAME VALUE IN VERIFY-QUICKSTRESS

  .PARAMETER IOmeter
   If set indicates to use IOmeter as the IO stress application

  .PARAMETER Full
   Includes C: drive in the testing

  .PARAMETER NoWait
   Does not wait for testing to complete.  Run Verify-QuickStress after testing
   completes to verify test passed

  .OUTPUTS
   Returns number of errors

  .COMPONENT
   WCS
  
  .FUNCTIONALITY
   Stress

   #>

    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]    [int]    $TimeInMin     = 1,  
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]   [string] $LogDirectory  = '',
                                                                  [switch] $Iometer,
                                                                  [switch] $Full,
                                                                  [switch] $NoWait  
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        Write-Host (" Running stress with {0}`r`n`r" -f $FunctionInfo.Name)
        #------------------------------------------------
        # Verify application installed
        #------------------------------------------------
        If ($Iometer -and (-NOT (Test-Path $WCS_IOMETER_BINARY)))
        {
            Throw "IOMeter application not installed"
        }
        If (-NOT $Iometer -and (-NOT (Test-Path $WCS_DISK_SPEED_BINARY)))
        {
            Throw "DiskSpd application not installed"
        }
        If (-NOT (Test-Path $WCS_PRIME95_BINARY))
        {
            Throw "Prime95 application not installed"
        }

        #-------------------------------------------------------
        # Setup vars 
        #-------------------------------------------------------
        $LogDirectory = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)
  
        $LocalLogFile = "$LogDirectory\Run-Quickstress.log"

        CoreLib_WriteLog -Value ("{0}`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile

        #--------------------------------------------------------------------------
        #  Start the IO stress test if there is drives
        #--------------------------------------------------------------------------
        $Disks  = Get-WcsPhysicalDisk  
        $Drives = Get-WcsLogicalDrive  -Full:$Full

        If (($Disks -eq $null) -and ($Drives -eq $null))  
        {
            $NoDisks = $true
            CoreLib_WriteLog -Value "No disks or drives found so not running IO stress"-Function  $FunctionInfo.Name -Log  $LocalLogFile -PassThru | Write-Host 
        }
        Else
        {
            $NoDisks  = $false

            If ($IOmeter)
            {
                CoreLib_WriteLog -Value " Starting Run-IOmeter -Time $TimeInMin -LogDirectory $LogDirectory -Full:$Full -NoWait " -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
                $IoStressResult  = Run-IOmeter -Time $TimeInMin -LogDirectory $LogDirectory -Full:$Full -NoWait -RunAsChild
            }
            Else
            { 
                CoreLib_WriteLog -Value " Starting Run-DiskSpeed -Time $TimeInMin -LogDirectory $LogDirectory -Full:$Full -NoWait" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
                $IoStressResult  = Run-DiskSpeed -Time $TimeInMin -LogDirectory $LogDirectory -Full:$Full -NoWait  -RunAsChild
            }
            If ($null -eq $IoStressResult)
            {
                CoreLib_WriteLog -Value " FAILED: Failed starting IO stress `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host 
                Return $WCS_RETURN_CODE_GENERIC_ERROR
            }
        }
        #-------------------------------------------------------------------
        #  Run Prime95 
        #-------------------------------------------------------------------
        CoreLib_WriteLog -Value " Starting Prime95 -Time $TimeInMin -LogDirectory $LogDirectory -NoWait " -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose 

        If ($NoWait)
        {
             Return  Run-Prime95 -Time $TimeInMin -LogDirectory $LogDirectory -NoWait  -RunAsChild
        }
        Else
        {
            $Prime95Errors  = Run-Prime95 -Time $TimeInMin -LogDirectory $LogDirectory  -NoWait  -RunAsChild
        }

        CoreLib_WriteLog -Value " Waiting $TimeInMin minutes for stress to complete"-Function  $FunctionInfo.Name -Log  $LocalLogFile -PassThru | Write-Verbose

        Start-Sleep (60*$TimeInMin + 30)
        
        $ErrorCount = Verify-QuickStress -LogDirectory $LogDirectory -NoDisks:$NoDisks -Iometer:$Iometer  -RunAsChild

        If (0 -ne $ErrorCount)
        {
            CoreLib_WriteLog -Value "FAILED!!! `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile  
            Write-Host -ForegroundColor Red "`r`n RUN-QUICKSTRESS failed `r`n" 
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        Else 
        { 
            CoreLib_WriteLog -Value $WCS_TEST_PASS_SIGNATURE  -Function $FunctionInfo.Name  -Log $LocalLogFile 
            Write-Host  "`r`n RUN-QUICKSTRESS  $WCS_TEST_PASS_SIGNATURE  `r`n" 
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}

#-----------------------------------------------------------------------------
# Verify-QuickStress
#-----------------------------------------------------------------------------
Function Verify-QuickStress()
{
   <#
  .SYNOPSIS
   Verifies a Run-QuickStress test run with -NoWait
 
   .DESCRIPTION 
   Verifies a Run-QuickStress test run with -NoWait

   Waits up to -TimeOutInSec for the applications to stop.  If don't stop before 
   timeout then kills them and returns an error.

  .EXAMPLE
   Run-QuickStress -TimeInMin 30  -NoWait

   Verify-QuickStress

  .PARAMETER LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

   IF USING THE -NOWAIT OPTION THEN USE THE SAME VALUE IN RUN-QUCKSTRESS

  .PARAMETER IOmeter
   If set indicates IOmeter was the IO stress application used

  .PARAMETER NoDisks
   If set will not verify IO stress results because there were no disks

  .OUTPUTS
   Returns number of errors

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Stress

   #>

    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]   [string] $LogDirectory  = '',
                                                                  [switch] $Iometer,
                                                                  [switch] $NoDisks,
                                                                  [switch] $RunAsChild
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Setup vars 
        #-------------------------------------------------------
        $ErrorCount   = 0
        $LogDirectory = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)


        If (-NOT (Test-Path "$LogDirectory")) 
        { 
            Write-Host "VERIFY-QUICKSTRESS FAILED: Could not find log directory specified '$LogDirectory'"  
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        $LocalLogFile  = "$LogDirectory\Run-Quickstress.log"

        CoreLib_WriteLog -Value ("{0}`r" -f $FunctionInfo.Details) -Function $FunctionInfo.Name   -Log $LocalLogFile

        #--------------------------------------------------------------------------
        #  Log the fact the test has started
        #--------------------------------------------------------------------------
        $Prime95Errors  = Verify-Prime95  -LogDirectory $LogDirectory  -RunAsChild
        
        If (0 -eq $Prime95Errors) 
        { 
            CoreLib_WriteLog -Value " Prime95 passed" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose         
        }
        Else                      
        { 
            CoreLib_WriteLog -Value " Prime95 failed" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host -ForegroundColor Red
        }

        #-------------------------------------------------------------------
        #  Verify IO stress stopped and no entries in error output
        #-------------------------------------------------------------------
        If (-NOT $NoDisks)
        {
            If ($IOmeter)
            {
                $IoStressErrors  = Verify-Iometer -LogDirectory $LogDirectory  -RunAsChild
                If     (0 -eq $IoStressErrors)     
                { 
                    CoreLib_WriteLog -Value " IOmeter passed" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
                }
                Else                               
                { 
                    CoreLib_WriteLog -Value " IOmeter failed" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host -ForegroundColor Red
                }
            }
            Else
            {
                $IoStressErrors  = Verify-DiskSpeed -LogDirectory $LogDirectory -RunAsChild
                If     (0 -eq $IoStressErrors)     
                { 
                    CoreLib_WriteLog -Value " IOmeter passed" -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Verbose
                }
                Else                               
                { 
                    CoreLib_WriteLog -Value " IOmeter failed " -Function $FunctionInfo.Name  -Log $LocalLogFile -PassThru | Write-Host -ForegroundColor Red
                }            
            }
        }
        Else
        {
            $IoStressErrors = 0
        }
        #-------------------------------------------------------------------
        # Log results
        #-------------------------------------------------------------------
        If ((0 -ne $Prime95Errors) -or (0 -ne $IoStressErrors)) 
        {
            $ErrorCount = 1
        }

        If (-Not $RunAsChild)
        {
            If ($ErrorCount -ne 0)
            {       
                CoreLib_WriteLog -Value "FAILED!!! `r`n" -Function $FunctionInfo.Name  -Log $LocalLogFile  
                Write-Host -ForegroundColor Red "`r`n RUN-QUICKSTRESS failed `r`n" 
                Return $WCS_RETURN_CODE_GENERIC_ERROR
            }
            Else
            {
                CoreLib_WriteLog -Value "$WCS_TEST_PASS_SIGNATURE" -Function $FunctionInfo.Name  -Log $LocalLogFile
                Write-Host  "`r`n RUN-QUICKSTRESS  $WCS_TEST_PASS_SIGNATURE  `r`n" 
                Return $WCS_RETURN_CODE_SUCCESS
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}
