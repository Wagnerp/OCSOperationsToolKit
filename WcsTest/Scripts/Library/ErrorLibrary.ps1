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


#----------------------------------------------------------------------------------------------
# Helper function that decodes the Microsoft config manager (device manager) error code into
# a readable string
#----------------------------------------------------------------------------------------------
Function DecodeConfigMgrCode([byte] $ErrorCode)
{

    Switch($ErrorCode)
    {
         0x0 {$ErrorString = 'Device is working properly.' ; break}
         0x1 {$ErrorString = 'Device is not configured correctly.' ; break}
         0x2 {$ErrorString = 'Windows cannot load the driver for this device.' ; break}
         0x3 {$ErrorString = 'Driver for this device might be corrupted, or the system may be low on memory or other resources.' ; break}
         0x4 {$ErrorString = 'Device is not working properly. One of its drivers or the registry might be corrupted.' ; break}
         0x5 {$ErrorString = 'Driver for the device requires a resource that Windows cannot manage.' ; break}
         0x6 {$ErrorString = 'Boot configuration for the device conflicts with other devices.' ; break}
         0x7 {$ErrorString = 'Cannot filter.' ; break}
         0x8 {$ErrorString = 'Driver loader for the device is missing.' ; break}
         0x9 {$ErrorString = 'Device is not working properly. The controlling firmware is incorrectly reporting the resources for the device.' ; break}
         0xA {$ErrorString = 'Device cannot start.' ; break}
         0xB {$ErrorString = 'Device failed.' ; break}
         0xC {$ErrorString = 'Device cannot find enough free resources to use.' ; break}
         0xD {$ErrorString = 'Windows cannot verify the devices resources.' ; break}
         0xE {$ErrorString = 'Device cannot work properly until the computer is restarted.' ; break}
         0xF {$ErrorString = 'Device is not working properly due to a possible re-enumeration problem.' ; break}
        0x10 {$ErrorString = 'Windows cannot identify all of the resources that the device uses.' ; break}
        0x11 {$ErrorString = 'Device is requesting an unknown resource type.' ; break}
        0x12 {$ErrorString = 'Device drivers must be reinstalled.' ; break}
        0x13 {$ErrorString = 'Failure using the VxD loader.' ; break} 
        0x14 {$ErrorString = 'Registry might be corrupted.' ; break}
        0x15 {$ErrorString = 'System failure. If changing the device driver is ineffective, see the hardware documentation. Windows is removing the device.' ; break}
        0x16 {$ErrorString = 'Device is disabled.' ; break} 
        0x17 {$ErrorString = 'System failure. If changing the device driver is ineffective, see the hardware documentation.' ; break} 
        0x18 {$ErrorString = 'Device is not present, not working properly, or does not have all of its drivers installed.' ; break} 
        0x19 {$ErrorString = 'Windows is still setting up the device.' ; break} 
        0x1A {$ErrorString = 'Windows is still setting up the device.' ; break}
        0x1B {$ErrorString = 'Device does not have valid log configuration.' ; break}
        0x1C {$ErrorString = 'Device drivers are not installed.' ; break} 
        0x1D {$ErrorString = 'Device is disabled. The device firmware did not provide the required resources.' ; break}
        0x1E {$ErrorString = 'Device is using an IRQ resource that another device is using.' ; break}
        0x1F {$ErrorString = 'Device is not working properly. Windows cannot load the required device drivers.' ; break}

        Default  {$ErrorString = '' }
    }

    Write-Output $ErrorString
}

#----------------------------------------------------------------------------------------------
# Get-WcsHealth 
#----------------------------------------------------------------------------------------------
Function Get-WcsHealth()
{
   <#
  .SYNOPSIS
   Gets the system health

  .DESCRIPTION
   Gets the system health that includes:

     1. Device manager errors (unless in WinPE or NoDeviceMgr specified)
     2. Hardware errors from the BMC SEL (unless NoHardware specified)
     3. Drive SMART errors  (unless NoHardware specified)
     4. FRU configuration errors on WCS systems (unless NoFru specified)

   See also View-WcsHealth and Log-WcsHealth

  .PARAMETER NoDeviceMgr
   If specified then device manager errors are not returned

  .PARAMETER NoHardware
   If specified then hardware errors are not returned

  .PARAMETER NoFru
   If specified then FRU errors are not returned

  .EXAMPLE
   $SystemHealth = Get-WcsHealth

   Stores the system health in $SystemHealth

  .EXAMPLE
   $SystemHealth = Get-WcsHealth -NoHardware -NoFru

   Stores the system health in $SystemHealth excluding hardware and FRU
   errors.  

   .OUTPUTS
   On success return a hash table with system health

   On failure returns $null
         
  .COMPONENT
   WCS

  .FUNCTIONALITY
   Error

   #>

    [CmdletBinding()]

    Param
    (
        [switch] $NoDeviceMgr,
        [switch] $NoHardware, 
        [switch] $NoFru 
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
        $SystemHealth = @{ErrorCount=0;Summary=@{};HardwareErrors=@();DeviceManagerErrors=@();FruErrors=@()}   
                     
        #-------------------------------------------------------
        # First search the SEL for hardware errors, ignore errors 
        # because some systems without a BMC
        #-------------------------------------------------------
        If (-NOT $NoHardware)
        {
            Try
            {
                #-------------------------------------------------------
                # First search the SEL for hardware errors
                #-------------------------------------------------------
                Get-WcsSel -HardwareError -ErrorAction Stop | ForEach-Object {

                    $Location     = $_.Location
                    $LastEntry    = ("{0} - {1}" -f $_.Event,$_.TimestampDecoded)

                    #-----------------------
                    # Add to summary list
                    #-----------------------
                    If (-NOT $SystemHealth.Summary.ContainsKey($Location))
                    {
                        $SystemHealth.Summary.Add($Location,@{ErrorCount=1;LastError=$LastEntry})
                    }
                    Else
                    {
                        $SystemHealth.Summary[$Location].ErrorCount++
                        $SystemHealth.Summary[$Location].LastError = $LastEntry
                    }
                    #-----------------------
                    # Add to hardware list
                    #-----------------------
                    $SystemHealth.HardwareErrors += ("BMC SEL: {0} " -f $_.Decode)
                }
            }
            Catch
            {
                Write-Verbose "Could not communicate with BMC so did not find BMC SEL errors`r"
            }
        }
        #-------------------------------------------------------
        # Read the current configuration
        #-------------------------------------------------------
        $Config = (Get-WcsConfig -SkipDriver)

        #-------------------------------------------------------
        # Check for blank or missing FRU fields
        #-------------------------------------------------------
        If (-NOT $NoFru -and ($Global:ThisSystem -ne $UNKNOWN_SYSTEM))
        {
            $Config.WcsConfig.Fru.ChildNodes | ForEach-Object { 

                #-------------------------------------------------------------------------
                # Note: Product custom field #2 is not defined so don't check that field
                #-------------------------------------------------------------------------
                If (($_.Value -eq '') -or ($_.Value -eq $WCS_NOT_AVAILABLE) -and ($_.Name -ne 'ProductCustom2'))
                {
                    $Location     = 'FRU'
                    $LastEntry    = ("{0} missing" -f $_.Name)
                    #-----------------------
                    # Add to summary list
                    #-----------------------
                    If (-NOT $SystemHealth.Summary.ContainsKey('FRU'))
                    {
                        $SystemHealth.Summary.Add($Location,@{ErrorCount=1;LastError=$LastEntry})
                    }
                    Else
                    {
                        $SystemHealth.Summary[$Location].ErrorCount++
                        $SystemHealth.Summary[$Location].LastError = $LastEntry
                    }
                    #-----------------------
                    # Add to FRU list
                    #-----------------------
                    $SystemHealth.FruErrors += ("FRU: Field '{0}' missing a value" -f $_.Name)
                }
            }
        }
        #-------------------------------------------------------
        # Check the disks for errors
        #-------------------------------------------------------
        If (-NOT $NoHardware)
        {
            $Config.WcsConfig.ChildNodes | Where-Object {"Disk" -eq $_.Name } | ForEach-Object {

                If ($_.Status.Value -ne 'OK')
                {
                    $Location  = $_.LabelLocation.Value
                    $LastEntry = ("DISK: {0} {1}" -f $_.LabelLocation.Value,$_.Status.Value)

                    #-----------------------
                    # Add to summary list
                    #-----------------------
                    If (-NOT $SystemHealth.Summary.ContainsKey($Location))
                    { 
                        $SystemHealth.Summary.Add($Location,@{ErrorCount='1+';LastError=$LastEntry})
                    }
                    Else
                    {
                        $SystemHealth.Summary[$Location].LastError = $_.Status.Value
                        $SystemHealth.Summary[$Location].ErrorCount++
                    } 
                    #-----------------------
                    # Add to hardware list
                    #-----------------------
                    $SystemHealth.HardwareErrors += $LastEntry                                 
                }
            }
        }
        #-------------------------------------------------------
        # If not PNP get device manager errors
        #-------------------------------------------------------
        If (-NOT (CoreLib_IsWinPE) -and -NOT $NoDeviceMgr)
        {
            Get-WmiObject Win32_PnpEntity | ForEach-Object {

                If ($_.ConfigManagerErrorCode -ne 0)
                {
                    $Location  = 'DEVICE MANAGER'
                    $LastEntry = ("{0} (0x{1:X2}) {2}" -f (DecodeConfigMgrCode $_.ConfigManagerErrorCode), $_.ConfigManagerErrorCode,$_.Description)
                    #-----------------------
                    # Add to summary list
                    #-----------------------
                    If (-NOT $SystemHealth.Summary.ContainsKey($Location))
                    { 
                        $SystemHealth.Summary.Add($Location,@{ErrorCount=1;LastError=$LastEntry})
                    }
                    Else
                    {
                        $SystemHealth.Summary[$Location].LastError = $LastEntry
                        $SystemHealth.Summary[$Location].ErrorCount++
                    } 
                    #-----------------------
                    # Add to hardware list
                    #-----------------------
                    $SystemHealth.DeviceManagerErrors += ("DEV MGR: {0}" -f $LastEntry)
                }  
            }
        }
        #-------------------------------------------------------
        # Return the health
        #-------------------------------------------------------
        $SystemHealth.ErrorCount = $SystemHealth.DeviceManagerErrors.Count + $SystemHealth.HardwareErrors.Count +  $SystemHealth.FruErrors.Count
        Write-Output $SystemHealth 

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
    }
}
#----------------------------------------------------------------------------------------------
# View-WcsHealth 
#----------------------------------------------------------------------------------------------
Function View-WcsHealth()
{
   <#
  .SYNOPSIS
   Displays a summary of the system health

  .DESCRIPTION
   Displays the system health that includes:

     1. Device manager errors (unless in WinPE or NoDeviceMgr specified)
     2. Hardware errors from the BMC SEL (unless NoHardware specified)
     3. Drive SMART errors  (unless NoHardware specified)
     4. FRU configuration errors on WCS systems (unless NoFru specified)

   See also Get-WcsHealth and Log-WcsHealth

  .PARAMETER NoDeviceMgr
   If specified then device manager errors are not returned

  .PARAMETER NoHardware
   If specified then hardware errors are not returned

  .PARAMETER NoFru
   If specified then FRU errors are not returned

  .EXAMPLE
   View-WcsHealth

   Displays the system health

  .EXAMPLE
   View-WcsHealth -NoHardware -NoFru

   Displays the system health excluding hardware and FRU errors.  

   .OUTPUTS
   None
  
  .COMPONENT
   WCS

  .FUNCTIONALITY
   Error

   #>

    [CmdletBinding()]

    Param
    (
        [switch] $NoDeviceMgr,
        [switch] $NoHardware, 
        [switch] $NoFru ,
        [switch] $Full
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Get the health and display it
        #-------------------------------------------------------
        $SystemHealth = @{ErrorCount=0;Summary=@{};HardwareErrors=@();DeviceManagerErrors=@();FruErrors=@()}
 
        $SystemHealth = Get-WcsHealth -ErrorAction Stop -NoDeviceMgr:$NoDeviceMgr -NoHardware:$NoHardware -NoFru:$NoFru
      
        #-------------------------------------------------------
        # If no errors then system is healthy
        #-------------------------------------------------------            
        If ($SystemHealth.ErrorCount -eq 0)
        {
            Write-Host ("`r`n SYSTEM HEALTH OK - NO ERRORS FOUND!! `r`n `r") 
            Return
        }
        #-------------------------------------------------------
        #  Found errors so display summary of errors
        #-------------------------------------------------------   
        Write-Host ("`r`n SYSTEM HEALTH DEGRADED - FOUND ERRORS... `r`n `r`n$WCS_HEADER_LINE`r`n {0,-14} {1,9}   {2}`r`n$WCS_HEADER_LINE`r" -f 'Location','# Errors','Last Error') 

        $SystemHealth.Summary.GetEnumerator() | ForEach-Object {

            Write-Host (" {0,-14} {1,9}   {2}`r" -f $_.Name,$_.Value.ErrorCount,$_.Value.LastError)
        }
        #-------------------------------------------------------
        # If -full specified display all errors
        #-------------------------------------------------------
        If ($Full)
        {              
            If (-NOT $NoDeviceMgr)
            {
                Write-Host ("`r`n$WCS_HEADER_LINE`r`n Device Manager Errors`r`n$WCS_HEADER_LINE`r") 
                $SystemHealth.DeviceManagerErrors | ForEach-Object { Write-Host "$_`r" }
            }
            If (-NOT $NoFru)
            {
                Write-Host ("`r`n$WCS_HEADER_LINE`r`n FRU Errors`r`n$WCS_HEADER_LINE`r") 
                $SystemHealth.FruErrors           | ForEach-Object { Write-Host "$_`r" }
            }
            If (-NOT $NoHardware)
            {
                Write-Host ("`r`n$WCS_HEADER_LINE`r`n Hardware Errors`r`n$WCS_HEADER_LINE`r") 
                $SystemHealth.HardwareErrors      | ForEach-Object { Write-Host "$_`r" }            
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
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
    }
}

#----------------------------------------------------------------------------------------------
# Log-WcsHealth 
#----------------------------------------------------------------------------------------------
Function Log-WcsHealth()
{
   <#
  .SYNOPSIS
   Logs the system health to a file

  .DESCRIPTION
   Gets the current system health and saves the results to a file.  The system health includes:

     1. Device manager errors (unless in WinPE or NoDeviceMgr specified)
     2. Hardware errors from the BMC SEL (unless NoHardware specified)
     3. Drive SMART errors  (unless NoHardware specified)
     4. FRU configuration errors on WCS systems (unless NoFru specified)

  .PARAMETER SystemHealth
   System health object returned by Get-WcsHealth.  If not specified will log the current
   system health.

  .PARAMETER File
   Name of file to log to.  Default is Health-<date-time>.log

  .PARAMETER LogDirectory
   Name of directory to log to. Default is <InstallDir>\Results\Log-WcsHealth

  .PARAMETER NoDeviceMgr
   If specified then device manager errors are not returned

  .PARAMETER NoHardware
   If specified then hardware errors are not returned

  .PARAMETER NoFru
   If specified then FRU errors are not returned

  .EXAMPLE
   Log-WcsHealth -File MyHealthySystem

   Logs the system health into <InstallDir>\Results\Log-WcsHealth

  .EXAMPLE
   Log-WcsHealth -NoHardware -NoFru

   Logs the system health excluding hardware and FRU errors to

   <InstallDir>\Results\Log-WcsHealth\Health-<date-time>.log

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error
  
  .COMPONENT
   WCS

  .FUNCTIONALITY
   Error
   
   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$false,Position=0)][ValidateNotNullOrEmpty()] [String] $File = ("Health-{0}" -f (BaseLib_SimpleDate)),
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]                     $SystemHealth = $null,
        [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]            [String] $LogDirectory = "$WCS_RESULTS_DIRECTORY\Log-WcsHealth",
                                                                           [switch] $NoDeviceMgr,
                                                                           [switch] $NoHardware, 
                                                                           [switch] $NoFru
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Create directory if doesn't exist
        #-------------------------------------------------------
        if (-NOT (Test-Path $LogDirectory -PathType Container)) { New-Item  $LogDirectory -ItemType Container | Out-Null }

        #-------------------------------------------------------
        # Create the full file name
        #-------------------------------------------------------
        $File = $File.ToLower()

        if ($File.EndsWith(".log"))    { $File =  $File.Remove($File.Length - ".log".Length)     }
        if ($File.EndsWith(".sel"))    { $File =  $File.Remove($File.Length - ".sel".Length)  }

        $FilePath      = Join-Path $LogDirectory ($File + ".health.log")  
        
        Remove-Item $FilePath      -ErrorAction SilentlyContinue -Force | Out-Null

        #-------------------------------------------------------
        # Get the system health
        #-------------------------------------------------------    
        If ($null -eq $SystemHealth)
        {       
            $SystemHealth = Get-WcsHealth -ErrorAction Stop -NoDeviceMgr:$NoDeviceMgr -NoHardware:$NoHardware -NoFru:$NoFru
        }
        #-------------------------------------------------------
        # Log the system health
        #-------------------------------------------------------                
        If ($SystemHealth.ErrorCount -eq 0)
        {
            Add-Content -Path $FilePath -Value ("`r`n SYSTEM HEALTH OK - NO ERRORS FOUND!! `r`n `r") 
            Return $WCS_RETURN_CODE_SUCCESS  
        }

        Add-Content -Path $FilePath -Value  ("`r`n  SYSTEM HEALTH DEGRADED - FOUND ERRORS... `r`n `r`n$WCS_HEADER_LINE`r`n {0,-14} {1,9}   {2}`r`n$WCS_HEADER_LINE" -f 'Location','# Errors','Last Error') 

        $SystemHealth.Summary.GetEnumerator() | ForEach-Object {

            Add-Content -Path $FilePath -Value  (" {0,-14} {1,9}   {2}" -f $_.Name,$_.Value.ErrorCount,$_.Value.LastError)
        }
        
        If (-NOT $NoDeviceMgr)
        {
            Add-Content -Path $FilePath -Value  ("`r`n$WCS_HEADER_LINE`r`n Device Manager Errors`r`n$WCS_HEADER_LINE") 
            $SystemHealth.DeviceManagerErrors | ForEach-Object { Add-Content -Path $FilePath -Value  "$_" }
        }
        If (-NOT $NoFru)
        {
            Add-Content -Path $FilePath -Value  ("`r`n$WCS_HEADER_LINE`r`n FRU Errors`r`n$WCS_HEADER_LINE") 
            $SystemHealth.FruErrors           | ForEach-Object { Add-Content -Path $FilePath -Value  "$_"}
        }
        If (-NOT $NoHardware)
        {
            Add-Content -Path $FilePath -Value  ("`r`n$WCS_HEADER_LINE`r`n Hardware Errors`r`n$WCS_HEADER_LINE") 
            $SystemHealth.HardwareErrors      | ForEach-Object { Add-Content -Path $FilePath -Value  "$_" }    
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
#----------------------------------------------------------------------------------------------
# Check-WcsError 
#----------------------------------------------------------------------------------------------
Function Check-WcsError()
{
   <#
  .SYNOPSIS
   Checks Windows System Event Log and BMC SEL for errors

  .DESCRIPTION
   This function returns the number of suspect errors found in the BMC SEL and the Windows 
   System Event Log.
   
   By default the function considers the following errors suspect:
     1) hardware errors in the BMC SEL
     2) WHEA, bugchecks, and critical entries in Windows System Event Log
   
   Optional files can be specified to include and/or exclude BMC SEL entries and Windows
   System Events.  The precedence for the optional files is:

        1. Get default suspect errors
        2. Remove suspect errors in exclude file
        3. Add suspect errors in the include file 

   See <InstallDir>\Scripts\References\DataFiles for example files
   
   This function backs up the Windows Event Logs and BMC SEL.

   Windows event logs are backed up in their native .evt format
   BMC SEL is backed up in text files.  One has decoded SEL entries and the other is not decoded.

   This function does not clear the logs.  Use Clear-WcsError to clear logs.

  .EXAMPLE
   Check-WcsError

  .PARAMETER LogDirectory
   Logs results in this directory. If not specified logs results in:
   
    <InstallDir\Results\<FunctionName>\<DateTime>

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
   Returns number of errors found

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Error

   #>
    
    [CmdletBinding(PositionalBinding=$false)]
    Param
    ( 
        [Parameter(Mandatory=$false)]      [string]  $LogDirectory      =  '',
        [Parameter(Mandatory=$false)]      [string]  $IncludeSelFile    =  '',
        [Parameter(Mandatory=$false)]      [string]  $ExcludeSelFile    =  '',
        [Parameter(Mandatory=$false)]      [string]  $IncludeEventFile  =  '',
        [Parameter(Mandatory=$false)]      [string]  $ExcludeEventFile  =  ''
    )
 
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        Write-Host (" Checking errors with {0}`r`n`r" -f  $FunctionInfo.Name)
        #-------------------------------------------------------
        # Setup vars and constants
        #-------------------------------------------------------  
        $IncludeEvents         = $null     
        $ExcludeEvents         = $null     

        $IncludeSelEntries     = $null     
        $ExcludeSelEntries     = $null     

        $SuspectSystemEvents   = @()
        $SuspectSelEntries     = @()
        #-------------------------------------------------------
        # Setup files and directories
        #-------------------------------------------------------    
        $LogDirectory = (BaseLib_GetLogDirectory $LogDirectory  $FunctionInfo.Name)

        $SummaryFile             = "$LogDirectory\Check-WcsError-Summary.log"                
        $SuspectSystemEventsFile = "$LogDirectory\Suspect-Windows-System-Events.log"
  
        Remove-Item -Path $SuspectSystemEventsFile -ErrorAction SilentlyContinue | Out-Null
        #-------------------------------------------------------
        # Read input files, copy to log directory for reference
        #------------------------------------------------------- 
        If ($IncludeSelFile -ne '')
        {  
            $IncludeSelEntries = [xml] (Get-Content $IncludeSelFile -ErrorAction Stop)
            Copy-Item $IncludeSelFile $LogDirectory 
        }
        If ($ExcludeSelFile -ne '')
        {  
            $ExcludeSelEntries = [xml] (Get-Content $ExcludeSelFile -ErrorAction Stop)
            Copy-Item $ExcludeSelFile $LogDirectory 
        }

        If ($IncludeEventFile -ne '')
        {  
            $IncludeEvents = [xml] (Get-Content $IncludeEventFile -ErrorAction Stop)
            Copy-Item $IncludeEventFile $LogDirectory 
        }

         If ($ExcludeEventFile -ne '')
        {  
            $ExcludeEvents = [xml] (Get-Content $ExcludeEventFile -ErrorAction Stop)
            Copy-Item $ExcludeEventFile $LogDirectory 
        }

        CoreLib_WriteLog -Value $FunctionInfo.Details -Function $FunctionInfo.Name -LogFile $SummaryFile 

        #----------------------------------------------- 
        # WinPE does not have Event Logs so skip
        #----------------------------------------------- 
        If (-Not (CoreLib_IsWinPE))
        {
            #----------------------------------------------- 
            # Backup each event log
            #----------------------------------------------- 
            Get-WmiObject Win32_NTEventLogFile | ForEach-Object { 

                $BackupFileName    =  ("{0}\{1}.evt" -f  ($LogDirectory,$_.LogFileName))

                Remove-Item $BackupFileName -ErrorAction SilentlyContinue | Out-Null

                $BackupReturnValue =  $_.BackupEventLog($BackupFileName).ReturnValue 

                if (0 -ne $BackupReturnValue)
                {
                    Throw ("Failed to backup Windows Event Log: {0} returned error code: {1}`r" -f $BackupFileName,$BackupReturnValue)
                }
                Else
                {
                   CoreLib_WriteLog -Value ("`tBacked up Windows Event Log: {0} `r" -f $BackupFileName) -Function $FunctionInfo.Name -LogFile $SummaryFile -PassThru | Write-Verbose 
                }
            }
            #------------------------------------------------
            # Get the suspect errors from System Event Log
            #------------------------------------------------
            Get-EventLog -LogName System | Where-Object {$_ -ne $null} | ForEach-Object {
            
                $SystemEvent = $_
                $AddEvent    = $false

                #---------------------------------------------------------------
                # Get the default critical, hardware and bugcheck entries
                #---------------------------------------------------------------
                if ( (0 -eq [int] $SystemEvent.EntryType)                       -or  # These are the critical events
                     ($SystemEvent.Source -eq 'Microsoft-Windows-WHEA-Logger')  -or  # WHEA are hardware errors
                     ($SystemEvent.EventId -eq 1001)                            -or  # Bugcheck ID
                     ($SystemEvent.Source  -eq ("bugcheck")))                        # Bugcheck 
                {
                    $AddEvent = $true
                }
                #-------------------------------------------------------------------------------------
                # Get the additional errors for the specific system (Don't bother if already added)
                #-------------------------------------------------------------------------------------
                if ((-NOT $AddEvent) -and ($SystemDefined_EventErrors -ne $null))
                {
                    $SystemDefined_EventErrors.Events.ChildNodes | Where-Object {$_ -ne $null} | ForEach-Object {

                        if ( ($SystemEvent.EventId -like $_.EventId) -and ($SystemEvent.Message -like $_.Message) -and ($SystemEvent.Source -like $_.Source) )
                        {
                            $AddEvent = $true                            
                        }
                    }
                }
                #---------------------------------------------------------------
                # Remove the exclude events (don't bother if not added)
                #---------------------------------------------------------------
                If ($AddEvent -and ($ExcludeEvents -ne $null))
                {
                    $ExcludeEvents.Events.ChildNodes | Where-Object {$_ -ne $null} | ForEach-Object {

                        if ( ($SystemEvent.EventId -like $_.EventId) -and ($SystemEvent.Message -like $_.Message) -and ($SystemEvent.Source -like $_.Source) )
                        {
                            $AddEvent = $false
                        }
                    }
                }
                #---------------------------------------------------------------
                # Add the included events (don't bother if already added)
                #---------------------------------------------------------------
                If ((-NOT $AddEvent) -and ($IncludeEvents -ne $null))
                {
                    $IncludeEvents.Events.ChildNodes | Where-Object {$_ -ne $null} | ForEach-Object {

                        if ( ($SystemEvent.EventId -like $_.EventId) -and ($SystemEvent.Message -like $_.Message) -and ($SystemEvent.Source -like $_.Source) )
                        {
                            $AddEvent = $true
                        }
                    }
                }
                #---------------------------------------------------------------
                # Add the event if a suspect event
                #---------------------------------------------------------------
                If ($AddEvent)
                {
                    $SuspectSystemEvents += $SystemEvent
                }
            }
            #--------------------------------------------------------------
            # Log suspected errors (if any)
            #--------------------------------------------------------------  
            If ($SuspectSystemEvents.Count -gt 0)
            {
                $SuspectSystemEvents | Format-List | Out-File $SuspectSystemEventsFile -Append  
                CoreLib_WriteLog -Value ("`tFound {0} suspect error(s) in the Windows System Event Log. `r" -f $SuspectSystemEvents.Count) -Function $FunctionInfo.Name -LogFile $SummaryFile -PassThru | Write-Host -ForegroundColor Yellow                                    
            }
            Else
            {
                CoreLib_WriteLog -Value ("`tFound NO suspect errors in the Windows System Event Log. `r" -f $SuspectSystemEvents.Count) -Function $FunctionInfo.Name -LogFile $SummaryFile -PassThru | Write-Host                                   
            }

        }
        #--------------------------------------------------------
        # Check BMC SEL for errors (if there is a BMC)
        #--------------------------------------------------------
        IpmiLib_GetIpmiInstance  -ErrorAction SilentlyContinue
            
        if ($null -ne $Global:IpmiInstance)
        {
            #--------------------------------------------------------------
            # Log BMC SEL entries  
            #--------------------------------------------------------------
            Log-WcsSel -LogDirectory $LogDirectory -File Bmc-Sel-Entries -ErrorAction Stop | Out-Null
            #------------------------------------------------
            # Get the suspect errors from BMC SEL
            #------------------------------------------------
            Get-WcsSel | Where-Object {$_ -ne $null} | ForEach-Object {
            
                $SelEntry    = $_
                $AddEntry    = $SelEntry.HardwareError

                #---------------------------------------------------------------
                # Remove the exclude events  
                #---------------------------------------------------------------
                If  ($ExcludeSelEntries -ne $null)
                {
                    $ExcludeSelEntries.Entries.ChildNodes | Where-Object {$_ -ne $null} | ForEach-Object {

                        If ( (("{0:X2}" -f $SelEntry.RecordType)       -like $_.RecordType)         -and 
                             (("{0:X2}" -f $SelEntry.SensorType)       -like $_.SensorType)         -and 
                             (("{0:X2}" -f $SelEntry.Sensor)           -like $_.Sensor)             -and 
                             (("{0:X2}" -f $SelEntry.EventDirType)     -like $_.EventDirType)       -and
                             ($SelEntry.OemTimestampRecord             -like $_.OemTimestampRecord) -and
                             ($SelEntry.OemNonTimestampRecord          -like $_.OemNonTimestampRecord))
                        {
                            $AddEntry = $false
                        }
                    }
                }
                #---------------------------------------------------------------
                # Add the included events (don't bother if already added)
                #---------------------------------------------------------------
                If ((-NOT $AddEntry) -and ($IncludeSelEntries -ne $null))
                {
                    $IncludeSelEntries.Entries.ChildNodes | Where-Object {$_ -ne $null} | ForEach-Object {

                        If ( (("{0:X2}" -f $SelEntry.RecordType)       -like $_.RecordType)         -and 
                             (("{0:X2}" -f $SelEntry.SensorType)       -like $_.SensorType)         -and 
                             (("{0:X2}" -f $SelEntry.Sensor)           -like $_.Sensor)             -and 
                             (("{0:X2}" -f $SelEntry.EventDirType)     -like $_.EventDirType)       -and
                             ($SelEntry.OemTimestampRecord             -like $_.OemTimestampRecord) -and
                             ($SelEntry.OemNonTimestampRecord          -like $_.OemNonTimestampRecord))
                        {
                            $AddEntry = $true
                        }
                    }
                }
                #---------------------------------------------------------------
                # Add the event if a suspect event
                #---------------------------------------------------------------
                If ($AddEntry)
                {
                    $SuspectSelEntries += $SelEntry
                }
            }
            #--------------------------------------------------------------
            # Log suspected errors (if any)
            #--------------------------------------------------------------  
            If ($SuspectSelEntries.Count -gt 0)
            {
                Log-WcsSel  -SelEntries $SuspectSelEntries  -LogDirectory $LogDirectory -File SuspectSelEntries.log  -ErrorAction Stop | Out-Null
                CoreLib_WriteLog -Value  ("`tFound {0} suspect error(s) in the BMC SEL`r" -f $SuspectSelEntries.Count )  -Function $FunctionInfo.Name -LogFile $SummaryFile -PassThru | Write-Host -ForegroundColor Yellow
            }
            Else
            {
                CoreLib_WriteLog -Value  "`tFound NO suspect error(s) in the BMC SEL`r"    -Function $FunctionInfo.Name -LogFile $SummaryFile -PassThru | Write-Host  
            }

        }
        Write-Host "`r"
        #--------------------------------------------------------------
        # Return result
        #--------------------------------------------------------------
        Return ($SuspectSelEntries.Count + $SuspectSystemEvents.Count)
    }
    #------------------------------------------------------------
    # Default Catch block to handle all errors
    #------------------------------------------------------------
    Catch
    {
        $_.ErrorDetails  = CoreLib_FormatException $_  -FunctionInfo $FunctionInfo

        CoreLib_WriteLog -Value  $_.ErrorDetails -Function $FunctionInfo.Name -LogFile $SummaryFile

        #----------------------------------------------
        # Take action (do nothing if SilentlyContinue)
        #---------------------------------------------- 
        If      ($ErrorActionPreference -eq 'Stop')             { Throw $_ }
        ElseIf  ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Red -NoNewline $_.ErrorDetails }
        
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
 }

 
#----------------------------------------------------------------------------------------------
# Clear-WcsError 
#----------------------------------------------------------------------------------------------
Function Clear-WcsError()
{
   <#
  .SYNOPSIS
   Clears Windows event logs and BMC SEL 

  .DESCRIPTION
   Clears Windows event logs and BMC SEL 

  .EXAMPLE
   Clear-WcsError

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Error

#>
    [CmdletBinding()]

    Param() 

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        
        Write-Host (" Clearing errors with {0}`r`n`r" -f $FunctionInfo.Name)

        #----------------------------------------------- 
        #Clear the event logs if not WinPE
        #----------------------------------------------- 
        If (-Not (CoreLib_IsWinPE))
        {
            #----------------------------------------------- 
            # Clear each event log
            #----------------------------------------------- 
            Get-WmiObject Win32_NTEventLogFile | ForEach-Object { 

                #--------------------------------------------------------
                # Clear the event logs  
                #--------------------------------------------------------
                $ClearReturnValue  =  $_.ClearEventLog().ReturnValue

                if (0 -ne $ClearReturnValue)
                {
                    Throw (" Failed to clear Windows Event Log: {0} returned error code: {1}`r" -f $_.LogFileName,$ClearReturnValue)
                }
                Else
                {
                     Write-Verbose ("`tCleared Windows Event Log: {0} `r" -f  $_.LogFileName) 
                }
            }
        }
        #--------------------------------------------------------
        # Clear Sel if there is one
        #--------------------------------------------------------
        IpmiLib_GetIpmiInstance  -ErrorAction SilentlyContinue
            
        if ($null -ne $Global:IpmiInstance)
        {
            Clear-WcsSel -ErrorAction Stop 
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
