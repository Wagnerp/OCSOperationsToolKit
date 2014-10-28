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

#-----------------------------------------------------------------------------------
# Set alias
#-----------------------------------------------------------------------------------
Set-Alias -Name vcfg  -Value View-WcsConfig
Set-Alias -Name gcfg  -Value Get-WcsConfig
Set-Alias -Name lcfg  -Value Log-WcsConfig
Set-Alias -Name ccfg  -Value Compare-WcsConfig
Set-Alias -Name ucfg  -Value Update-WcsConfig

#-------------------------------------------------------------------------------------------------
# Gets the Chassis Manager Service Info
#-------------------------------------------------------------------------------------------------
Function Get-CmServiceInfo()
{
   $CmServices = @{"CM"=$WCS_NOT_AVAILABLE;"WCSCLI"=$WCS_NOT_AVAILABLE; "WCSCLICOM5"=$WCS_NOT_AVAILABLE; "WCSCLICOM6"=$WCS_NOT_AVAILABLE;}

   Try
   {
       $CmServices["WCSCLI"]     = (Get-ItemProperty "\WcsCli\wcscli.exe").VersionInfo.FileVersion
       $CmServices["WCSCLICOM5"] = (Get-ItemProperty "\WcsCliCom5\wcscli.exe").VersionInfo.FileVersion
       $CmServices["WCSCLICOM6"] = (Get-ItemProperty "\WcsCliCom6\wcscli.exe").VersionInfo.FileVersion
       $CmServices["CM"]         = (Get-ItemProperty "\ChassisManager\Microsoft.GFS.WCS.ChassisManager.exe").VersionInfo.FileVersion
    }
    Catch
    {
        Write-Verbose ("Failed to read CM services versions`r")
    }

    $CmServices
}

#-------------------------------------------------------------------------------------------------
# Gets the Chassis Manager CPLD Info
#-------------------------------------------------------------------------------------------------
Function Get-CmCpldInfo()
{
    $CmCplds = @{"CPLD0"=$WCS_NOT_AVAILABLE;"CPLD1"=$WCS_NOT_AVAILABLE; "CPLD2"=$WCS_NOT_AVAILABLE; }
    
    $UPDATE_CHILD_DIRECTORY      = "$WCS_BINARY_DIRECTORY\Quanta"

    $EXE_FILE                    = "$UPDATE_CHILD_DIRECTORY\q_jam.exe"
    $OUTPUT_FILE                 = "$UPDATE_CHILD_DIRECTORY\output.txt"
    $ERROR_FILE                  = "$UPDATE_CHILD_DIRECTORY\error.txt"
              
    #----------------------------------------------------------------------
    # Run the Quanta utility for CPLD0 
    #----------------------------------------------------------------------
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        
        If (-NOT (Test-Path $EXE_FILE ))
        {
            Throw
        }

        $CpldUpdate = Start-Process -WindowStyle Hidden -WorkingDirectory $UPDATE_CHILD_DIRECTORY  -PassThru -Wait -RedirectStandardOutput $OUTPUT_FILE -RedirectStandardError $ERROR_FILE -FilePath $EXE_FILE -Argumentlist "-n0 -aread_usercode cpld0_01000006.jam"

        If (0 -ne $CpldUpdate.ExitCode)
        {
            Throw
        }

        #---------------------------------------------------------------------------
        # Parse the output to find the version, refer to the ref doc for details
        #---------------------------------------------------------------------------
        $ProcessOutput   = Get-Content $OUTPUT_FILE
        $Words           =  $ProcessOutput -split '\s+'
        $CurrentVersion  = ""

        For ($Word=0; $Word -lt $Words.Count; $Word++)
        {
            If ("USERCODE" -eq $Words[$Word]) { $CmCplds["CPLD0"] = $Words[($Word+3)] }
        }
    }
    Catch
    {
        Write-Verbose ("Error: CPLD update utility '{0}' failed for cpld0`r" -f $EXE_FILE )
    }
    #----------------------------------------------------------------------
    # Run the Quanta utility for CPLD1
    #----------------------------------------------------------------------
    Try
    {
        If (-NOT (Test-Path $EXE_FILE ))
        {
            Throw
        }

        $CpldUpdate = Start-Process -WindowStyle Hidden  -WorkingDirectory $UPDATE_CHILD_DIRECTORY  -PassThru -Wait -RedirectStandardOutput $OUTPUT_FILE -RedirectStandardError $ERROR_FILE -FilePath $EXE_FILE -Argumentlist "-n1 -aread_usercode cpld0_01000006.jam"

        If (0 -ne $CpldUpdate.ExitCode)
        {
            Throw
        }

        #---------------------------------------------------------------------------
        # Parse the output to find the version, refer to the ref doc for details
        #---------------------------------------------------------------------------
        $ProcessOutput   = Get-Content $OUTPUT_FILE
        $Words           =  $ProcessOutput -split '\s+'
        $CurrentVersion  = ""

        For ($Word=0; $Word -lt $Words.Count; $Word++)
        {
            If ("USERCODE" -eq $Words[$Word]) { $CmCplds["CPLD1"] = $Words[($Word+3)] }
        }
    }
    Catch
    {
        Write-Verbose ("Error: CPLD update utility '{0}' failed for cpld1`r" -f $EXE_FILE )
    }
    #----------------------------------------------------------------------
    # Run the Quanta utility for CPLD2
    #----------------------------------------------------------------------
    Try
    {
        If (-NOT (Test-Path $EXE_FILE ))
        {
            Throw
        }
        $CpldUpdate = Start-Process -WindowStyle Hidden -WorkingDirectory $UPDATE_CHILD_DIRECTORY  -PassThru -Wait -RedirectStandardOutput $OUTPUT_FILE -RedirectStandardError $ERROR_FILE -FilePath $EXE_FILE -Argumentlist "-n2 -aread_usercode cpld0_01000006.jam"

        If (0 -ne $CpldUpdate.ExitCode)
        {
            Throw
        }

        #---------------------------------------------------------------------------
        # Parse the output to find the version, refer to the ref doc for details
        #---------------------------------------------------------------------------
        $ProcessOutput   = Get-Content $OUTPUT_FILE
        $Words           =  $ProcessOutput -split '\s+'
        $CurrentVersion  = ""

        For ($Word=0; $Word -lt $Words.Count; $Word++)
        {
            If ("USERCODE" -eq $Words[$Word]) { $CmCplds["CPLD2"] = $Words[($Word+3)] }
        }
    }
    #------------------------------------------------------------
    # Default Catch block to handle all errors
    #------------------------------------------------------------
    Catch
    {
        Write-Verbose ("Error: CPLD update utility '{0}' failed for cpld2`r" -f $EXE_FILE )
    }
    $CmCplds 
}

#-------------------------------------------------------------------------------------------------
# Gets the driver info from OS
#-------------------------------------------------------------------------------------------------
Function Get-OsDriverInfo()
{
    $OsDrivers = @{"IntelSystemOem"=$WCS_NOT_AVAILABLE;"IntelProcessor"=$WCS_NOT_AVAILABLE;"IntelSystemMachine"=$WCS_NOT_AVAILABLE;"Mellanox"=$WCS_NOT_AVAILABLE;"LSI"=$WCS_NOT_AVAILABLE}

    Get-WmiObject Win32_PnpSignedDriver -ErrorAction SilentlyContinue | Where-Object { $_ -ne $null }  | ForEach-Object {

        $ThisDriver = $_

        Switch ($ThisDriver.Manufacturer) 
        {
            "Intel" 
            { 
                If ($ThisDriver.DeviceClass -eq "SYSTEM") 
                {
                    If ($ThisDriver.InfName -eq "machine.inf")
                    {
                        If     ($OsDrivers["IntelSystemMachine"] -eq $WCS_NOT_AVAILABLE)              { $OsDrivers["IntelSystemMachine"] = $ThisDriver.DriverVersion }
                        ElseIf ($OsDrivers["IntelSystemMachine"] -ne  $ThisDriver.DriverVersion ) { $OsDrivers["IntelSystemMachine"] = "MISMATCH" }
                    }
                    Else
                    {
                        If     ($OsDrivers["IntelSystemOem"] -eq $WCS_NOT_AVAILABLE)              { $OsDrivers["IntelSystemOem"] = $ThisDriver.DriverVersion }
                        ElseIf ($OsDrivers["IntelSystemOem"] -ne  $ThisDriver.DriverVersion ) { $OsDrivers["IntelSystemOem"] = "MISMATCH" }
                    }
                }      
                ElseIf ( ($ThisDriver.DeviceClass -eq "PROCESSOR"))
                {
                    If     ($OsDrivers["IntelProcessor"] -eq $WCS_NOT_AVAILABLE)              { $OsDrivers["IntelProcessor"] = $ThisDriver.DriverVersion }
                    ElseIf ($OsDrivers["IntelProcessor"] -ne  $ThisDriver.DriverVersion ) { $OsDrivers["IntelProcessor"] = "MISMATCH" }
                }      
          
            }
            "Mellanox Technologies Ltd." 
            {
                If     ($OsDrivers["Mellanox"] -eq $WCS_NOT_AVAILABLE)              { $OsDrivers["Mellanox"] = $ThisDriver.DriverVersion }
                ElseIf ($OsDrivers["Mellanox"] -ne  $ThisDriver.DriverVersion ) { $OsDrivers["Mellanox"] = "MISMATCH" } 
            }
            "LSI Corporation" 
            {
                If     ($OsDrivers["LSI"] -eq $WCS_NOT_AVAILABLE)              { $OsDrivers["LSI"] = $ThisDriver.DriverVersion }
                ElseIf ($OsDrivers["LSI"] -ne  $ThisDriver.DriverVersion ) { $OsDrivers["LSI"] = "MISMATCH" } 
            }
            Default {break}
 
        }
 
    }
 
    $OsDrivers 
}

#-------------------------------------------------------------------------------------------------
# Gets the OS settings for a chassis manager 
#-------------------------------------------------------------------------------------------------
Function GetChassisManagerOsConfig()
{
    #-------------------------------------------------------------------------------------------------
    # Setup the hash table with keys and values
    #-------------------------------------------------------------------------------------------------
    $OsPolicy = @{

        Firewall                         = $WCS_NOT_AVAILABLE;

        AutomaticPaging                  = $WCS_NOT_AVAILABLE;
        PageFile                         = $WCS_NOT_AVAILABLE;

        PowerPlan                        = $WCS_NOT_AVAILABLE;

        Hibernate                        = $WCS_NOT_AVAILABLE;
        Sleep                            = $WCS_NOT_AVAILABLE;

        TerminalService                  = $WCS_NOT_AVAILABLE;

        WcsAdmin                         = "MISSING";
        WcsCMAdmin                       = "MISSING";

        MemoryDumpSize                   = $WCS_NOT_AVAILABLE;
    
        AuthenticodeEnabled              = $WCS_NOT_AVAILABLE;
    
        FilterAdministratorToken         = $WCS_NOT_AVAILABLE;
        EnableUIADesktopToggle           = $WCS_NOT_AVAILABLE;
        ConsentPromptBehaviorAdmin       = $WCS_NOT_AVAILABLE;
        ConsentPromptBehaviorUser        = $WCS_NOT_AVAILABLE;
        EnableInstallerDetection         = $WCS_NOT_AVAILABLE;
    
        ValidateAdminCodeSignatures      = $WCS_NOT_AVAILABLE;
        EnableSecureUIAPaths             = $WCS_NOT_AVAILABLE;
        EnableLUA                        = $WCS_NOT_AVAILABLE;
        PromptOnSecureDesktop            = $WCS_NOT_AVAILABLE;
        EnableVirtualization             = $WCS_NOT_AVAILABLE;

        BootEms                          = $WCS_NOT_AVAILABLE;
        BootStatusPolicy                 = $WCS_NOT_AVAILABLE;

        COM1                             = $WCS_NOT_AVAILABLE;
        COM2                             = $WCS_NOT_AVAILABLE;
        COM3                             = $WCS_NOT_AVAILABLE;
        COM4                             = $WCS_NOT_AVAILABLE;
        COM5                             = $WCS_NOT_AVAILABLE;
        COM6                             = $WCS_NOT_AVAILABLE;

        WindowsUpdate                    = $WCS_NOT_AVAILABLE;
        Drivers                          = $WCS_NOT_AVAILABLE;
    }

    

    #-------------------------------------------------------------------------------------------------
    # Get the firewall setting.  Get active profile then get setting for that profile
    #-------------------------------------------------------------------------------------------------
    $FirewallSetting = $WCS_NOT_AVAILABLE
    $Firewall        = New-object –comObject HNetCfg.FwPolicy2 -ErrorAction SilentlyContinue

    If ($null -ne $Firewall)
    {
        Switch ( $Firewall.CurrentProfileTypes)
        {
            1 
            { 
                If ($Firewall.FirewallEnabled(1)) { $FirewallSetting = "Domain: On"  }
                Else                              { $FirewallSetting = "Domain: Off" }
                Break
            }
    
            2 
            { 
    
                If ($Firewall.FirewallEnabled(2)) { $FirewallSetting = "Private: On"  }
                Else                              { $FirewallSetting = "Private: Off" }
                Break
            }

            4 
            { 
                If ($Firewall.FirewallEnabled(4)) { $FirewallSetting = "Public: On"  }
                Else                              { $FirewallSetting = "Public: Off" }
                Break
            }
    
            Default 
            { 
                Break
            }
        }
    }
    $OsPolicy.Firewall = $FirewallSetting
    #-------------------------------------------------------------------------------------------------
    # Get the power plan settings.  Get active poower plan then get settings for that plan
    #-------------------------------------------------------------------------------------------------
    Try
    {
        $PowerSettings      =  Get-WmiObject Win32_PowerSetting          -Namespace root\cimv2\Power -ErrorAction Stop
        $PowerSettingValues =  Get-WmiObject Win32_PowerSettingDataIndex -Namespace root\cimv2\Power -ErrorAction Stop
        $ActivePowerPlan    = (Get-WmiObject Win32_PowerPlan             -Namespace root\cimv2\Power -filter "IsActive=true" -ErrorAction Stop)

        $ActivePowerPlanId  =  $ActivePowerPlan.InstanceID.Replace("Microsoft:PowerPlan\","")

        $SleepAfterID       = ($PowerSettings | Where-Object { $_.ElementName -eq 'Sleep after' } ).InstanceId.Replace("Microsoft:PowerSetting\","")
        $HibernateAfterID   = ($PowerSettings | Where-Object { $_.ElementName -eq 'Hibernate after' } ).InstanceID.Replace("Microsoft:PowerSetting\","")

        $AcSleepAfterID     = "$ActivePowerPlanId\AC\$SleepAfterID"
        $DcSleepAfterID     = "$ActivePowerPlanId\DC\$SleepAfterID"

        $AcHibernateAfterID = "$ActivePowerPlanId\AC\$HibernateAfterID"
        $DcHibernateAfterID = "$ActivePowerPlanId\DC\$HibernateAfterID"

        $SleepACDelay       = ($PowerSettingValues | Where-Object { $_.InstanceId.Replace("Microsoft:PowerSettingDataIndex\","") -eq $AcSleepAfterID } ).SettingIndexValue 
        $SleepDCDelay       = ($PowerSettingValues | Where-Object { $_.InstanceId.Replace("Microsoft:PowerSettingDataIndex\","") -eq $DcSleepAfterID } ).SettingIndexValue

        $HibernateACDelay   = ($PowerSettingValues | Where-Object { $_.InstanceId.Replace("Microsoft:PowerSettingDataIndex\","") -eq $AcHibernateAfterID } ).SettingIndexValue 
        $HibernateDCDelay   = ($PowerSettingValues | Where-Object { $_.InstanceId.Replace("Microsoft:PowerSettingDataIndex\","") -eq $DcHibernateAfterID } ).SettingIndexValue
        #----------------------------------------------------------------------------------------------
        # If the delay 0 seconds then the sleep feature is disasbled
        #----------------------------------------------------------------------------------------------
        If (($SleepACDelay -eq 0) -and ($SleepDCDelay -eq 0))         { $OsPolicy.Sleep     = "Disabled" } Else { $OsPolicy.Sleep     = "Enabled" }
        If (($HibernateACDelay -eq 0) -and ($HibernateDCDelay -eq 0)) { $OsPolicy.Hibernate = "Disabled" } Else { $OsPolicy.Hibernate = "Enabled" }

        $OsPolicy.PowerPlan =  $ActivePowerPlan.ElementName
    }
    Catch
    {
        $OsPolicy.PowerPlan = $WCS_NOT_AVAILABLE
        $OsPolicy.Sleep     = $WCS_NOT_AVAILABLE
        $OsPolicy.Hibernate = $WCS_NOT_AVAILABLE
    }
    #-------------------------------------------------------------------------------------------------
    # Get the User account info
    #-------------------------------------------------------------------------------------------------
    $computer =[ADSI] ("WinNT://{0},computer" -f (Get-WmiObject Win32_ComputerSystem).Name)

    $computer.psbase.Children | Where-Object { $_.psbase.schemaclassname -eq 'Group' } | ForEach-Object {

        If ($_.Path.EndsWith('/WcsCmAdmin'))    { $OsPolicy.WcsCmAdmin = "Present" }
     }
    $computer.psbase.Children | Where-Object { $_.psbase.schemaclassname -eq 'User' } | ForEach-Object {

        If ($_.Path.EndsWith('/WcsAdmin'))      { $OsPolicy.WcsAdmin   = "Present" }
     }
    #-------------------------------------------------------------------------------------------------
    # Get the memory dump info
    #-------------------------------------------------------------------------------------------------
    Switch ( (Get-WmiObject Win32_OsRecoveryConfiguration).DebugInfoType) 
    {
        0       { $OsPolicy.MemoryDumpSize = "None"         ; break }
        1       { $OsPolicy.MemoryDumpSize = "Complete"     ; break }
        2       { $OsPolicy.MemoryDumpSize = "Kernel"       ; break }
        3       { $OsPolicy.MemoryDumpSize = "Small"        ; break }
        Default { $OsPolicy.MemoryDumpSize = $WCS_NOT_AVAILABLE ; break }
    }
    #-------------------------------------------------------------------------------------------------
    # Get the paging info
    #-------------------------------------------------------------------------------------------------
    $OsPolicy.AutomaticPaging    =  (Get-WmiObject Win32_ComputerSystem).AutomaticManagedPageFile 
    $PageFileUsage                =  (Get-WmiObject Win32_PageFileUsage)

    If ($null -ne  $PageFileUsage) { $OsPolicy.PageFile  =  $PageFileUsage.Name }
    Else                           { $OsPolicy.PageFile  =  "" }
    #-------------------------------------------------------------------------------------------------
    # Get the boot setting
    #-------------------------------------------------------------------------------------------------
     Invoke-Expression "BcdEdit /enum ALL" | ForEach-Object {

        If ((($_ -split  '\s+')[0] -eq "bootems") -and (($_ -split  '\s+')[1] -eq "Yes"))             { $OsPolicy.BootEMS = "Enabled" }
        If ((($_ -split  '\s+')[0] -eq "bootstatuspolicy") -and (($_ -split  '\s+')[1] -eq "ignoreallfailures")) { $OsPolicy.BootStatusPolicy = "IgnoreAllFailures" }
    }
    #-------------------------------------------------------------------------------------------------
    # Get other settings
    #-------------------------------------------------------------------------------------------------
    Get-WmiObject Win32_SerialPort | ForEach-Object {

        $OsPolicy[$_.DeviceID] = "Enabled"
    }

    $OsPolicy.TerminalService    =  (Get-WmiObject Win32_TerminalService).State;

    $RegItem = Get-ItemProperty HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoUpdate -ErrorAction SilentlyContinue

    If     (($null -ne $RegItem) -and (0 -eq $RegItem.NoAutoUpdate))  { $OsPolicy.WindowsUpdate = "Enabled" }
    ElseIf  ($null -ne $RegItem)                                      { $OsPolicy.WindowsUpdate = "Disabled" }
    #-------------------------------------------------------------------------------------------------  
    # System settings: Use Certificate Rules on Windows Executables for Software Restriction Policies
    #-------------------------------------------------------------------------------------------------
    $RegItem = (Get-ItemProperty HKLM:\Software\Policies\Microsoft\Windows\Safer\CodeIdentifiers -name AuthenticodeEnabled)

    If     (($null -ne $RegItem) -and (0 -eq $RegItem.AuthenticodeEnabled)) { $OsPolicy.AuthenticodeEnabled = "Disabled" }
    ElseIf  ($null -ne $RegItem)                                            { $OsPolicy.AuthenticodeEnabled = "Enabled"  }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Admin Approval Mode for the Built-in Administrator account
    #-------------------------------------------------------------------------------------------------

    If (0 -eq (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name FilterAdministratorToken).FilterAdministratorToken)  
    { 
        $OsPolicy.FilterAdministratorToken = "Disabled" 
    }
    Else                                                                                                                                                  
    { 
        $OsPolicy.FilterAdministratorToken = "Enabled" 
    }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Allow UIAccess applications to prompt for elevation without using the secure desktop.
    #-------------------------------------------------------------------------------------------------
    If (0 -eq  (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name EnableUIADesktopToggle).EnableUIADesktopToggle)     
    { 
        $OsPolicy.EnableUIADesktopToggle = "Disabled" 
    }
    Else                                                                                                                                                  
    { 
        $OsPolicy.EnableUIADesktopToggle = "Enabled" 
    }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Behavior of the elevation prompt for administrators in Admin Approval Mode
    #-------------------------------------------------------------------------------------------------
    If (0 -eq (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name ConsentPromptBehaviorAdmin).ConsentPromptBehaviorAdmin) 
    { 
        $OsPolicy.ConsentPromptBehaviorAdmin = "Elevate without prompting" 
    }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Behavior of the elevation prompt for standard users
    #-------------------------------------------------------------------------------------------------
    If (3 -eq (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name ConsentPromptBehaviorUser).ConsentPromptBehaviorUser) 
    { 
        $OsPolicy.ConsentPromptBehaviorUser = "Prompt for credentials" 
    }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Detect application installations and prompt for elevation
    #-------------------------------------------------------------------------------------------------
    If (0 -eq  (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name EnableInstallerDetection).EnableInstallerDetection)  
    { 
        $OsPolicy.EnableInstallerDetection = "Disabled" 
    }
    Else                                                                                                                                                   
    { 
        $OsPolicy.EnableInstallerDetection = "Enabled" 
    }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Only elevate executables that are signed and validated
    #-------------------------------------------------------------------------------------------------
    If (0 -eq  (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name ValidateAdminCodeSignatures).ValidateAdminCodeSignatures)  
    { 
        $OsPolicy.ValidateAdminCodeSignatures = "Disabled" 
    }
    Else                                                                                                                                                         
    { 
        $OsPolicy.ValidateAdminCodeSignatures = "Enabled" 
    }

    #-------------------------------------------------------------------------------------------------
    # User Account Control: Only elevate UIAccess applications that are installed in secure locations
    #-------------------------------------------------------------------------------------------------
    If (0 -eq  (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name EnableSecureUIAPaths).EnableSecureUIAPaths)  
    { 
        $OsPolicy.EnableSecureUIAPaths = "Disabled" 
    }
    Else                                                                                                                                           
    { 
        $OsPolicy.EnableSecureUIAPaths = "Enabled" 
    }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Run all administrators in Admin Approval Mode
    #-------------------------------------------------------------------------------------------------
    If (0 -eq  (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name EnableLUA).EnableLUA)  
    { 
        $OsPolicy.EnableLUA = "Disabled" 
    }
    Else                                                                                                                     
    { 
        $OsPolicy.EnableLUA = "Enabled" 
    }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Switch to the secure desktop when prompting for elevation
    #-------------------------------------------------------------------------------------------------
    If (0 -eq  (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name PromptOnSecureDesktop).PromptOnSecureDesktop)  
    { 
        $OsPolicy.PromptOnSecureDesktop = "Disabled" 
    }
    Else                                                                                                                                             
    { 
        $OsPolicy.PromptOnSecureDesktop = "Enabled" 
    }
    #-------------------------------------------------------------------------------------------------
    # User Account Control: Virtualize file and registry write failures to per-user locations
    #-------------------------------------------------------------------------------------------------
    If (0 -eq  (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -name EnableVirtualization).EnableVirtualization)   
    { 
        $OsPolicy.EnableVirtualization = "Disabled" 
    }
    Else                                                                                                                                            
    { 
        $OsPolicy.EnableVirtualization = "Enabled" 
    }


    Return $OSPolicy 

}

#-------------------------------------------------------------------------------------
# Checks if a valid configuration
#-------------------------------------------------------------------------------------
Function IsValidConfig($ConfigToTest)
{
    Switch ($ConfigToTest.WcsConfig.Type)
    {
        $WCS_TYPE_BLADE      { $LegalType = $true; break }
        $WCS_TYPE_CHASSIS    { $LegalType = $true; break }
        Default              { $LegalType = $false }
    }
    Return $LegalType 
}
#-------------------------------------------------------------------------------------
# Gets the devices in the config
#-------------------------------------------------------------------------------------
Function GetConfigDevices($Config,$All,$Full)
{
    $KEY_LENGTH = -30

    $ConfigDevices = "$WCS_HEADER_LINE `r`nAll Device Info `r`n$WCS_HEADER_LINE `r`n"
 
    #-------------------------------------------------------------------------------------
    # Add all config information before any comments
    #-------------------------------------------------------------------------------------
    $Config.WcsConfig.ChildNodes | ForEach-Object {

        If (($_.Name -ne '#comment') -and (($WCS_CFG_DISPLAY.TRUE -eq $_.Display) -or ($All)))
        {

            if ($Full) { $ConfigDevices +=  ("`r`n`t{0}    [CompareResult]  {1} `r`n" -f $_.Name,$_.CompareResult) }
            else       { $ConfigDevices +=  ("`r`n`t{0} `r`n" -f $_.Name) }

            $_.ChildNodes | ForEach-Object {

                if (($WCS_CFG_DISPLAY.TRUE -eq $_.Display) -or ($All))
                {
                    if ($Full) { $ConfigDevices +=  ("`t`t`t{0,-30} : {1,-70} [CompareType]  {2}   [CompareResult]  {3} `r`n" -f $_.Name,$_.Value,$_.CompareType,$_.CompareResult)   }
                    else       { $ConfigDevices +=  ("`t`t`t{0,-30} : {1} `r`n" -f $_.Name,$_.Value)   }
                }

            }
        }

    } #Foreach

    $ConfigDevices += "$WCS_HEADER_LINE `r`nEnd config `r`n$WCS_HEADER_LINE `r`n"
    #-------------------------------------------------------------------------------------
    # Add comments
    #-------------------------------------------------------------------------------------
    $Config.WcsConfig.ChildNodes | ForEach-Object {

        If (($_.Name -eq '#comment') -and $All)
        {
            $ConfigDevices += $_.InnerText
        }
     }

    Return $ConfigDevices
}

#-------------------------------------------------------------------------------------
# Gets a summary of the configuration 
#-------------------------------------------------------------------------------------
Function GetBladeConfigSummary($Config)
{
    $KEY_LENGTH = -30

        $ConfigSummary = ""
        #------------------------------------------------
        # Get the system information
        #------------------------------------------------
        $ConfigSummary +=   "$WCS_HEADER_LINE `r`nSystem Info `r`n$WCS_HEADER_LINE `r`n"
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Computer",$Config.WcsConfig.System.ComputerName.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "TotalMemmory",$Config.WcsConfig.System.TotalPhysicalMemory.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "TotalProcessors",$Config.WcsConfig.System.TotalLogicalProcessors.Value) 
        #------------------------------------------------
        # Get the software information
        #------------------------------------------------
        $ConfigSummary +=   "$WCS_HEADER_LINE `r`nSoftware Info `r`n$WCS_HEADER_LINE `r`n"

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "BIOS Version",$Config.WcsConfig.BIOS.SMBIOSVersion.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "BMC Version",$Config.WcsConfig.BMC.Version.Value)        
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} (Version {2}) `r`n" -f  "OS Name",$Config.WcsConfig.OS.Caption.Value,$Config.WcsConfig.OS.Version.Value)
        #------------------------------------------------
        # Get the FRU information
        #------------------------------------------------
        $ConfigSummary +=   "$WCS_HEADER_LINE `r`nFRU Info `r`n$WCS_HEADER_LINE `r`n"
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Chassis Part Number",$Config.WcsConfig.FRU.ChassisPartNumber.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Chassis Serial Number",$Config.WcsConfig.FRU.ChassisSerial.Value)        

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Board Manufacturer",$Config.WcsConfig.FRU.BoardManufacturer.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Board Name",$Config.WcsConfig.FRU.BoardName.Value)        
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Board Part Number",$Config.WcsConfig.FRU.BoardPartNumber.Value)        
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Board Serial Number",$Config.WcsConfig.FRU.BoardSerial.Value)        
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Board FRU",$Config.WcsConfig.FRU.Version.Value)        

        #------------------------------------------------
        # Get the processor info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nProcessor Info `r`n$WCS_HEADER_LINE `r`n"

        $Config.WcsConfig.ChildNodes | Where-Object {"Processor" -eq $_.Name } | ForEach-Object {
        
            $ConfigSummary +=  ("   {0,$KEY_LENGTH}{1} (Cores: {2} LogicalCores: {3} L3: {4} MiB) `r`n"  -f $_.Location.Value,$_.Description.Value,$_.NumberOfCores.Value,$_.NumberOfLogicalCores.Value,($_.L3CacheSize.Value/1024))
        }

        #------------------------------------------------
        # Get the memory info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nDIMM Info `r`n$WCS_HEADER_LINE `r`n"

        $Config.WcsConfig.ChildNodes | Where-Object {"DIMM" -eq $_.Name } | ForEach-Object {
         
             $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} {2} Speed: {3}   Size: {4}   SN: {5} `r`n" -f  $_.LabelLocation.Value,$_.Manufacturer.Value,$_.Model.Value,$_.Speed.Value,$_.SizeString.Value,$_.SerialNumber.Value)
        }
        #------------------------------------------------
        # Get the disk info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nDisk Info `r`n$WCS_HEADER_LINE `r`n"
        $Config.WcsConfig.ChildNodes | Where-Object {"Disk" -eq $_.Name } | ForEach-Object {

           $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} FW: {2}   Size: {3}   SN: {4} `r`n" -f $_.LabelLocation.Value, $_.Model.Value, $_.Firmware.Value,$_.SizeString.Value,$_.SerialNumber.Value)        
        }
        #------------------------------------------------
        # Get the network adapter info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nNIC Info `r`n$WCS_HEADER_LINE `r`n"
        $Config.WcsConfig.ChildNodes | Where-Object {"NIC" -eq $_.Name } | ForEach-Object {

           $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} FW: {2}  Connection: {3} ({4} gbit/s)   MAC: {5} `r`n" -f "NIC",$_.Description.Value, $_.Firmware.Value,$_.Status.Value, ($_.Speed.Value/1000000000),$_.MAC.Value)
         }
        #------------------------------------------------
        # Get the mellanox adapter info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nMellanox Firmware Info `r`n$WCS_HEADER_LINE `r`n"
        $Config.WcsConfig.ChildNodes | Where-Object {"Mellanox" -eq $_.Name } | ForEach-Object {

           $ConfigSummary +=   ("   {0,$KEY_LENGTH}DeviceID: {1}   FW: {2}  PXE: {3}  UEFI: {4} `r`n" -f "Mellanox",$_.Device.Value, $_.Firmware.Value,$_.Pxe.Value,$_.Uefi.Value  )    
        }
        #------------------------------------------------
        # Get the LSI adapter info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nLSI Info `r`n$WCS_HEADER_LINE `r`n"
        $Config.WcsConfig.ChildNodes | Where-Object {"LSI" -eq $_.Name } | ForEach-Object {

           $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1}   FW: {2}  Package: {3}  Serial: {4} `r`n" -f "LSI",$_.Product.Value, $_.Firmware.Value ,$_.Package.Value, $_.SerialNumber.Value )   
        }
<#
        #------------------------------------------------
        # Get the driver info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nDriver Info `r`n$WCS_HEADER_LINE `r`n"

        $Config.WcsConfig.ChildNodes | Where-Object {"Driver" -eq $_.Name } | ForEach-Object {
        
            $ConfigSummary +=  ("   {0,$KEY_LENGTH}{1} `r`n"  -f "LSI",$_.LSI.Value )
            $ConfigSummary +=  ("   {0,$KEY_LENGTH}{1} `r`n"  -f "Mellanox",$_.Mellanox.Value )
            $ConfigSummary +=  ("   {0,$KEY_LENGTH}{1} `r`n"  -f "IntelProcessor",$_.IntelProcessor.Value )
            $ConfigSummary +=  ("   {0,$KEY_LENGTH}{1} `r`n"  -f "IntelSystemOem",$_.IntelSystemOem.Value )
            $ConfigSummary +=  ("   {0,$KEY_LENGTH}{1} `r`n"  -f "IntelSystemMachine",$_.IntelSystemMachine.Value )
        }
#>
     Return $ConfigSummary
}
#-------------------------------------------------------------------------------------
# Gets a summary of the configuration 
#-------------------------------------------------------------------------------------
Function GetChassisConfigSummary($Config)
{
    $KEY_LENGTH = -30

        $ConfigSummary = ""
        #------------------------------------------------
        # Get the system information
        #------------------------------------------------
        $ConfigSummary +=   "$WCS_HEADER_LINE `r`nSystem Info `r`n$WCS_HEADER_LINE `r`n"
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Computer",$Config.WcsConfig.System.ComputerName.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "TotalMemmory",$Config.WcsConfig.System.TotalPhysicalMemory.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "TotalProcessors",$Config.WcsConfig.System.TotalLogicalProcessors.Value) 
        #------------------------------------------------
        # Get the software information
        #------------------------------------------------
        $ConfigSummary +=   "$WCS_HEADER_LINE `r`nSoftware Info `r`n$WCS_HEADER_LINE `r`n"

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "BIOS Version",$Config.WcsConfig.BIOS.SMBIOSVersion.Value)      
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} (Version {2}) `r`n" -f  "OS Name",$Config.WcsConfig.OS.Caption.Value,$Config.WcsConfig.OS.Version.Value)
        #------------------------------------------------
        # Get the CM setting information
        #------------------------------------------------
        $ConfigSummary +=   "$WCS_HEADER_LINE `r`nCM Settings Info `r`n$WCS_HEADER_LINE `r`n"

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n`r`n" -f "CMService",$Config.WcsConfig.CmSettings.ChassisMgrService.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "CPLD0",$Config.WcsConfig.CmSettings.Cpld0.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "CPLD1",$Config.WcsConfig.CmSettings.Cpld1.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n`r`n" -f "CPLD2",$Config.WcsConfig.CmSettings.Cpld2.Value) 

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n`r`n" -f "Firewall",$Config.WcsConfig.CmSettings.Firewall.Value) 

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "COM1",$Config.WcsConfig.CmSettings.COM1.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "COM2",$Config.WcsConfig.CmSettings.COM2.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "COM3",$Config.WcsConfig.CmSettings.COM3.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "COM4",$Config.WcsConfig.CmSettings.COM4.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "COM5",$Config.WcsConfig.CmSettings.COM5.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n`r`n" -f "COM6",$Config.WcsConfig.CmSettings.COM6.Value) 

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "PowerPlan",$Config.WcsConfig.CmSettings.PowerPlan.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "Hibernate",$Config.WcsConfig.CmSettings.Hibernate.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n`r`n" -f "Sleep",$Config.WcsConfig.CmSettings.Sleep.Value) 

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "WindowsUpdate",$Config.WcsConfig.CmSettings.WindowsUpdate.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "MemoryDumpSize",$Config.WcsConfig.CmSettings.MemoryDumpSize.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "TerminalService",$Config.WcsConfig.CmSettings.TerminalService.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "AutomaticPaging",$Config.WcsConfig.CmSettings.AutomaticPaging.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n`r`n" -f "PageFile",$Config.WcsConfig.CmSettings.PageFile.Value) 

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "BootEms",$Config.WcsConfig.CmSettings.BootEms.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "BootStatusPolicy",$Config.WcsConfig.CmSettings.BootStatusPolicy.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "WcsAdmin",$Config.WcsConfig.CmSettings.WcsAdmin.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n`r`n" -f "WcsCMAdmin",$Config.WcsConfig.CmSettings.WcsCMAdmin.Value) 

        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "AuthenticodeEnabled",$Config.WcsConfig.CmSettings.AuthenticodeEnabled.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "FilterAdministratorToken",$Config.WcsConfig.CmSettings.FilterAdministratorToken.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "EnableUIADesktopToggle",$Config.WcsConfig.CmSettings.EnableUIADesktopToggle.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "ConsentPromptBehaviorAdmin",$Config.WcsConfig.CmSettings.ConsentPromptBehaviorAdmin.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "ConsentPromptBehaviorUser",$Config.WcsConfig.CmSettings.ConsentPromptBehaviorUser.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "EnableInstallerDetection",$Config.WcsConfig.CmSettings.EnableInstallerDetection.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "ValidateAdminCodeSignatures",$Config.WcsConfig.CmSettings.ValidateAdminCodeSignatures.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "EnableSecureUIAPaths",$Config.WcsConfig.CmSettings.EnableSecureUIAPaths.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "EnableLUA",$Config.WcsConfig.CmSettings.EnableLUA.Value) 
        $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} `r`n" -f "PromptOnSecureDesktop",$Config.WcsConfig.CmSettings.PromptOnSecureDesktop.Value) 


        #------------------------------------------------
        # Get the processor info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nProcessor Info `r`n$WCS_HEADER_LINE `r`n"

        $Config.WcsConfig.ChildNodes | Where-Object {"Processor" -eq $_.Name } | ForEach-Object {
        
            $ConfigSummary +=  ("   {0,$KEY_LENGTH}{1} (Cores: {2} LogicalCores: {3} L3: {4} MiB) `r`n"  -f $_.Location.Value,$_.Description.Value,$_.NumberOfCores.Value,$_.NumberOfLogicalCores.Value,($_.L3CacheSize.Value/1024))
        }
        #------------------------------------------------
        # Get the disk info
        #------------------------------------------------
        $ConfigSummary += "$WCS_HEADER_LINE `r`nDisk Info `r`n$WCS_HEADER_LINE `r`n"
        $Config.WcsConfig.ChildNodes | Where-Object {"Disk" -eq $_.Name } | ForEach-Object {

           $ConfigSummary +=   ("   {0,$KEY_LENGTH}{1} {2} FW: {3}   Size: {4}   SN: {5} `r`n" -f $_.Location.Value,$_.Manufacturer.Value,$_.Model.Value, $_.Firmware.Value,$_.Size.Value,$_.SerialNumber.Value)
         
         }
    
    Return $ConfigSummary
}

#-------------------------------------------------------------------------------------------------
# Helper function for adding attribute to XML document
#-------------------------------------------------------------------------------------------------
Function AddNewProp($WcsConfig,$Device,$Name,$Value="NULL",$WCS_CFG_COMPAREType=$WCS_CFG_COMPARE.ALWAYS,$WCS_CFG_DISPLAY=$WCS_CFG_DISPLAY.FALSE,$WCS_CFG_RESULT=$WCS_CFG_RESULT.NONE)
{
    Try
    {
        $newProperty     = $WcsConfig.CreateElement($Name)

        $device.AppendChild($newProperty) | Out-Null
 
        # Creation of an attribute in the principal node
        $WCS_CFG_XMLAtt          = $WcsConfig.CreateAttribute("Value")
        $WCS_CFG_XMLAtt.Value    = $Value 
        $newProperty.Attributes.Append($WCS_CFG_XMLAtt) | Out-Null
 
        $WCS_CFG_XMLAtt          = $WcsConfig.CreateAttribute("CompareType")
        $WCS_CFG_XMLAtt.Value    = $WCS_CFG_COMPAREType
        $newProperty.Attributes.Append($WCS_CFG_XMLAtt) | Out-Null

        $WCS_CFG_XMLAtt          = $WcsConfig.CreateAttribute("CompareResult")
        $WCS_CFG_XMLAtt.Value    = $WCS_CFG_RESULT
        $newProperty.Attributes.Append($WCS_CFG_XMLAtt) | Out-Null

        $WCS_CFG_XMLAtt          = $WcsConfig.CreateAttribute("Display")
        $WCS_CFG_XMLAtt.Value    = $WCS_CFG_DISPLAY
        $newProperty.Attributes.Append($WCS_CFG_XMLAtt) | Out-Null  

    }
    Catch
    { 
        Write-Host -ForegroundColor Red  "AddNewProp could not add property '$Name' to device '$Device'`r"
        Return $null
    }
}
#-------------------------------------------------------------------------------------------------
# Helper function for GenerateWcsConfig that adds parameters to the current XML device
#-------------------------------------------------------------------------------------------------
Function AddDeviceParameter($xmlWriter,[string]$ParameterName,[string]$ParameterValue='NULL',$CompareType=$WCS_CFG_COMPARE.ALWAYS,$DisplayType=$WCS_CFG_DISPLAY.FALSE,$CompareResult=$WCS_CFG_RESULT.NONE)
{

        $xmlwriter.WriteStartElement($ParameterName)
        $xmlwriter.WriteAttributeString('Value',$ParameterValue)  
        $xmlwriter.WriteAttributeString('CompareType',$CompareType)  
        $xmlwriter.WriteAttributeString('CompareResult',$CompareResult )  
        $xmlwriter.WriteAttributeString('Display',$DisplayType)
        $xmlwriter.WriteEndElement()
}
#-------------------------------------------------------------------------------------------------
# Helper function for GenerateWcsConfig that ends a device XML element
#-------------------------------------------------------------------------------------------------
Function EndConfigDevice($xmlWriter)
{
        $xmlwriter.WriteEndElement()
}
 #-------------------------------------------------------------------------------------------------
# Helper function for GenerateWcsConfig that starts a device XML element
#-------------------------------------------------------------------------------------------------
Function StartConfigDevice($xmlWriter, [string]$Element,$DisplayType)
{
        $xmlwriter.WriteStartElement($Element)
        $xmlwriter.WriteAttributeString('CompareResult',$WCS_CFG_RESULT.NONE)  
        $xmlwriter.WriteAttributeString('Display',$DisplayType)
}
#-------------------------------------------------------------------------------------
# Helper function for adding device to XML document object
#-------------------------------------------------------------------------------------
Function AddNewDevice($WcsConfig,$DeviceName,$WCS_CFG_DISPLAYAll)
{
    Try
    {
        #-----------------------------------------------------------
        # Must create a new element then add it to the xml document
        #-----------------------------------------------------------
        $NewDevice = $WcsConfig.CreateElement($DeviceName)
        $WcsConfig.LastChild.AppendChild($NewDevice) | Out-Null

        #-----------------------------------------------------------
        # Every device and parameter must have a CompareResult 
        # attribute to store the results of a comparison
        #-----------------------------------------------------------
        $WCS_CFG_XMLAtt          = $WcsConfig.CreateAttribute("CompareResult")
        $WCS_CFG_XMLAtt.Value    = $WCS_CFG_RESULT.NONE
        $NewDevice.Attributes.Append($WCS_CFG_XMLAtt) | Out-Null

        #-----------------------------------------------------------
        # Every device and parameter must have a CompareResult 
        # attribute to store the results of a comparison
        #-----------------------------------------------------------
        $WCS_CFG_XMLAtt          = $WcsConfig.CreateAttribute("Display")
        $WCS_CFG_XMLAtt.Value    = $WCS_CFG_DISPLAYAll
        $NewDevice.Attributes.Append($WCS_CFG_XMLAtt) | Out-Null

        #-----------------------------------------------------------
        # Return the new device
        #-----------------------------------------------------------
        Return $NewDevice
    }
    Catch
    {
        Write-Host -ForegroundColor Red  "AddNewDevice could not add device '$DeviceName'`r"
        Return $null
    }
}
 
#-------------------------------------------------------------------------------------
# Generates a WCS server configuration 
#-------------------------------------------------------------------------------------
Function GenerateWcsConfig()
{
    
    [CmdletBinding()]
    Param ([switch] $Chassis, [switch] $SkipDriver )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------------------------------------
        # Get the IPMI information
        #-------------------------------------------------------------------------------------
        $BiosInfo         = Get-WmiObject Win32_BIOS      
        $BmcInfo          = @{}  
        $BmcInfo.Version  = IpmiLib_GetBmcVersion   -ErrorAction SilentlyContinue 
        $FruInfo          = IpmiLib_GetBmcFru       -ErrorAction SilentlyContinue 
        $CpldVersion      = IpmiLib_getCpldVersion  -ErrorAction SilentlyContinue      

        #-------------------------------------------------------------------------------------
        # Determine if CM or something else based on BIOS ID
        #-------------------------------------------------------------------------------------
        $SystemType = Lookup-WcsSystem $BiosInfo $FruInfo

        #-------------------------------------------------------------------------------------
        # Start the XML document using a stringbuilder for speed
        #-------------------------------------------------------------------------------------
        $myBuilder = New-Object System.Text.StringBuilder(350000)
        $xmlwriter = [system.xml.xmlwriter]::Create($myBuilder)

        $xmlwriter.WriteStartElement('WcsConfig')
        $xmlwriter.WriteAttributeString('Version','2.0')
        $xmlwriter.WriteAttributeString('CompareErrors','0')

        If ($SystemType -eq $WCS_SYSTEM_QUANTA_CM1) {  $xmlwriter.WriteAttributeString('Type',"$WCS_TYPE_CHASSIS") }
        Else                                        {  $xmlwriter.WriteAttributeString('Type',"$WCS_TYPE_BLADE") }
        #-------------------------------------------------------------------------------------
        # Add the System information
        #-------------------------------------------------------------------------------------
        $ComputerSystem = Get-WmiObject Win32_ComputerSystem 

        StartConfigDevice $xmlWriter "System"   $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "Location"            "System"                             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE 
        AddDeviceParameter $xmlWriter "ComputerName"        $ComputerSystem.Name                 $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Model"               $ComputerSystem.Model                $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Manufacturer"        $ComputerSystem.Manufacturer         $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "TotalPhysicalMemory" ("{0} ({1:N1} GiB)" -f $ComputerSystem.TotalPhysicalMemory,($ComputerSystem.TotalPhysicalMemory/$WCS_BYTES_IN_GIB))  $WCS_CFG_COMPARE.PERCENT     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "TotalLogicalProcessors"                    $ComputerSystem.NumberOfLogicalProcessors         $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Status"               $ComputerSystem.Status         $WCS_CFG_COMPARE.ALWAYS          $WCS_CFG_DISPLAY.FALSE

        EndConfigDevice $xmlWriter
        #-------------------------------------------------------------------------------------
        # Add the BIOS information
        #-------------------------------------------------------------------------------------
        StartConfigDevice $xmlWriter "BIOS"   $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "Location"            "System"                             $WCS_CFG_COMPARE.ALWAYS      $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "Version"             $BiosInfo.Version                    $WCS_CFG_COMPARE.ALWAYS      $WCS_CFG_DISPLAY.TRUE    
        AddDeviceParameter $xmlWriter "BuildNumber"         $BiosInfo.BuildNumber                $WCS_CFG_COMPARE.ALWAYS      $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "Description"         $BiosInfo.Description                $WCS_CFG_COMPARE.ALWAYS      $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "Manufacturer"        $BiosInfo.Manufacturer               $WCS_CFG_COMPARE.ALWAYS      $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "SerialNumber"        $BiosInfo.SerialNumber               $WCS_CFG_COMPARE.ON_EXACT    $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "SMBIOSVersion"       $BiosInfo.SMBIOSBIOSVersion          $WCS_CFG_COMPARE.ALWAYS      $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "SMBIOSMajorVersion"  $BiosInfo.SMBIOSMajorVersion         $WCS_CFG_COMPARE.ALWAYS      $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "SMBIOSMinorVersion"  $BiosInfo.SMBIOSMinorVersion         $WCS_CFG_COMPARE.ALWAYS      $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "BIOSCharacteristics" $BiosInfo.BIOSCharacteristics        $WCS_CFG_COMPARE.ON_EXACT    $WCS_CFG_DISPLAY.FALSE

        EndConfigDevice $xmlWriter
        #-------------------------------------------------------------------------------------
        # Add the BMC information
        #-------------------------------------------------------------------------------------   
        StartConfigDevice $xmlWriter "BMC"   $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "Location"            "System"                             $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "Version"             $BmcInfo.Version                     $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE

        EndConfigDevice $xmlWriter
        #-------------------------------------------------------------------------------------
        # Add the CPLD information
        #-------------------------------------------------------------------------------------   
        StartConfigDevice $xmlWriter "CPLD"   $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "Location"            "System"                             $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "Version"             $CpldVersion                         $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE

        EndConfigDevice $xmlWriter

        #-------------------------------------------------------------------------------------
        # Add the FRU information
        #-------------------------------------------------------------------------------------
        StartConfigDevice $xmlWriter "FRU"   $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "Location"            "System"                             $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "Version"             $FruInfo.BoardFruFileId              $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "ChassisPartNumber"   $FruInfo.ChassisPartNumber           $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "ChassisSerial"       $FruInfo.ChassisSerial               $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "ChassisCustom1"      $FruInfo.ChassisCustom1              $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "ChassisCustom2"      $FruInfo.ChassisCustom2              $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "ManufactureDate"     $FruInfo.BoardMfgDate                $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "BoardManufacturer"   $FruInfo.BoardManufacturer           $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "BoardName"           $FruInfo.BoardName                   $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "BoardPartNumber"     $FruInfo.BoardPartNumber             $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "BoardSerial"         $FruInfo.BoardSerial                 $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE    

        AddDeviceParameter $xmlWriter "ProductManufacturer" $FruInfo.ProductManufacturer         $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "ProductName"         $FruInfo.ProductName                 $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "ProductModel"        $FruInfo.ProductModel                $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "ProductVersion"      $FruInfo.ProductVersion              $WCS_CFG_COMPARE.ALWAYS       $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "ProductSerial"       $FruInfo.ProductSerial               $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE    
        AddDeviceParameter $xmlWriter "ProductAsset"        $FruInfo.ProductAsset                $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "ProductFruFileId"    $FruInfo.ProductFruFileId            $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "ProductCustom1"      $FruInfo.ProductCustom1              $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE    
        AddDeviceParameter $xmlWriter "ProductCustom2"      $FruInfo.ProductCustom2              $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE    
        AddDeviceParameter $xmlWriter "ProductCustom3"      $FruInfo.ProductCustom3              $WCS_CFG_COMPARE.ON_EXACT     $WCS_CFG_DISPLAY.TRUE    

        EndConfigDevice $xmlWriter
        #-------------------------------------------------------------------------------------
        # Add the OS information
        #-------------------------------------------------------------------------------------
        $OsInfo = Get-WmiObject Win32_OperatingSystem 

        StartConfigDevice $xmlWriter "OS"   $WCS_CFG_DISPLAY.TRUE

        AddDeviceParameter $xmlWriter "Location"           "System"                             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE
        AddDeviceParameter $xmlWriter "Caption"            $OsInfo.Caption                      $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Version"            $OsInfo.Version                      $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "OSArchitecture"     $OsInfo.OSArchitecture               $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "SerialNumber"       $OsInfo.SerialNumber                 $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE

        EndConfigDevice $xmlWriter
        #-------------------------------------------------------------------------------------
        # Add the OS settings if chassis manager
        #-------------------------------------------------------------------------------------
        If ($SystemType -eq $WCS_SYSTEM_QUANTA_CM1)
        {
            StartConfigDevice $xmlWriter "CmSettings"   $WCS_CFG_DISPLAY.TRUE

            $CmSettings = GetChassisManagerOsConfig
        
            AddDeviceParameter $xmlWriter "Location"           "System"                             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE

            AddDeviceParameter $xmlWriter "Firewall"                       $CmSettings.Firewall                             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "AutomaticPaging"                $CmSettings.AutomaticPaging                      $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "PageFile"                       $CmSettings.PageFile                             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "PowerPlan"                      $CmSettings.PowerPlan                            $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Hibernate"                      $CmSettings.Hibernate                            $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Sleep"                          $CmSettings.Sleep                                $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "TerminalService"                $CmSettings.TerminalService                      $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "WcsAdmin"                       $CmSettings.WcsAdmin                             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "WcsCMAdmin"                     $CmSettings.WcsCMAdmin                           $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "MemoryDumpSize"                 $CmSettings.MemoryDumpSize                       $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "AuthenticodeEnabled"            $CmSettings.AuthenticodeEnabled                  $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "FilterAdministratorToken"       $CmSettings.FilterAdministratorToken             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "EnableUIADesktopToggle"         $CmSettings.EnableUIADesktopToggle               $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "ConsentPromptBehaviorAdmin"     $CmSettings.ConsentPromptBehaviorAdmin           $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "ConsentPromptBehaviorUser"      $CmSettings.ConsentPromptBehaviorUser            $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "EnableInstallerDetection"       $CmSettings.EnableInstallerDetection             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "ValidateAdminCodeSignatures"    $CmSettings.ValidateAdminCodeSignatures          $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "EnableSecureUIAPaths"           $CmSettings.EnableSecureUIAPaths                 $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "EnableLUA"                      $CmSettings.EnableLUA                            $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "PromptOnSecureDesktop"          $CmSettings.PromptOnSecureDesktop                $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "BootEms"                        $CmSettings.BootEms                              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "BootStatusPolicy"               $CmSettings.BootStatusPolicy                     $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "COM1"                           $CmSettings.COM1                                 $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "COM2"                           $CmSettings.COM2                                 $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "COM3"                           $CmSettings.COM3                                 $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "COM4"                           $CmSettings.COM4                                 $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "COM5"                           $CmSettings.COM5                                 $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "COM6"                           $CmSettings.COM6                                 $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
           
            AddDeviceParameter $xmlWriter "WindowsUpdate"                  $CmSettings.WindowsUpdate                        $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Drivers"                        $CmSettings.Drivers                              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            $CmServices = Get-CmServiceInfo

            AddDeviceParameter $xmlWriter "ChassisMgrService"              $CmServices.CM                                   $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "WcsCli"                         $CmServices.Wcscli                               $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "WcsCliCom5"                     $CmServices.WcscliCom5                           $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "WcsCliCom6"                     $CmServices.WcscliCom6                           $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            $CmCpld = Get-CmCpldInfo

            AddDeviceParameter $xmlWriter "CPLD0"                          $CmCpld.CPLD0                                    $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "CPLD1"                          $CmCpld.CPLD1                                    $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "CPLD2"                          $CmCpld.CPLD2                                    $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
      
            EndConfigDevice $xmlWriter
        }
        #-------------------------------------------------------------------------------------
        # Get the processor information
        #-------------------------------------------------------------------------------------
        $ProcessorNumber = 0

        Get-WmiObject Win32_Processor -Property SocketDesignation,Caption,Name,Manufacturer,ProcessorId,NumberOfCores,NumberOfLogicalProcessors,L3CacheSize,Status,ConfigManagerErrorCode  | ForEach-Object {

            If ($_.Caption -ne $null)      { $_.Caption = $_.Caption.Trim() }
            If ($_.Name -ne $null)         { $_.Name   = $_.Name.Trim() }
            If ($_.Manufacturer -ne $null) { $_.Manufacturer = $_.Manufacturer.Trim() }

            StartConfigDevice $xmlWriter "Processor"    $WCS_CFG_DISPLAY.TRUE     

            AddDeviceParameter $xmlWriter "Location"              $_.SocketDesignation               $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Caption"               $_.Caption                         $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Description"           $_.Name                            $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Manufacturer"          $_.Manufacturer                    $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "ProcessorID"           $_.ProcessorId                     $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "NumberOfCores"         $_.NumberOfCores                   $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "NumberOfLogicalCores"  $_.NumberOfLogicalProcessors       $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "L3CacheSize"           $_.L3CacheSize                     $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "Status"                $_.Status                          $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "ConfigMgrError"        $_.ConfigManagerErrorCode          $WCS_CFG_COMPARE.NEVER      $WCS_CFG_DISPLAY.TRUE

            $MicroCode = Get-ItemProperty -Path "hklm:\HARDWARE\DESCRIPTION\System\CentralProcessor\$ProcessorNumber" -Name 'Update Revision' | Select-Object -ExpandProperty 'Update Revision'

            $FormatUcode = ""

            $MicroCode | ForEach-Object { $FormatUcode += ("{0:x2} " -f $_ )} 

            AddDeviceParameter $xmlWriter "Microcode"            $FormatUcode.Trim()                $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE

            $ProcessorNumber += $_.NumberOfLogicalProcessors 

            EndConfigDevice $xmlWriter
        }
        #-------------------------------------------------------------------------------------
        # Get the DIMM information
        #-------------------------------------------------------------------------------------
        Get-WmiObject Win32_PhysicalMemory | ForEach-Object {

            If ($_.Manufacturer -ne $null) { $_.Manufacturer = $_.Manufacturer.Trim() }
            If ($_.PartNumber -ne $null)   { $_.PartNumber   = $_.PartNumber.Trim()   }
            If ($_.SerialNumber -ne $null) { $_.SerialNumber = $_.SerialNumber.Trim() }

            If ($_.Status -eq $null)       { $_.Status = 'OK' }

            StartConfigDevice $xmlWriter  "DIMM"   $WCS_CFG_DISPLAY.TRUE
        
            AddDeviceParameter $xmlWriter "Location"              $_.DeviceLocator                      $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "Manufacturer"          $_.Manufacturer                       $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Model"                 $_.PartNumber                         $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Speed"                 $_.Speed                              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "Size"                  $_.Capacity                             $WCS_CFG_COMPARE.PERCENT     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "SizeString"            (BaseLib_GetSizeStringXIB $_.Capacity)  $WCS_CFG_COMPARE.NEVER       $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "SerialNumber"          $_.SerialNumber                         $WCS_CFG_COMPARE.ON_EXACT    $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "LabelLocation"   (DefinedSystem_GetDimmLocation $_.DeviceLocator )  $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "Status"                $_.Status                             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            EndConfigDevice $xmlWriter
        }
    
        #-------------------------------------------------------------------------------------
        # Get the LSI information
        #-------------------------------------------------------------------------------------
        $LsiInfo        = Get-LsiInfo

        StartConfigDevice $xmlWriter  "LSI"   $WCS_CFG_DISPLAY.TRUE
        
        AddDeviceParameter $xmlWriter "Location"              "System"                             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Product"               $LsiInfo.ProductName                 $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "SerialNumber"          $LsiInfo.SerialNumber                $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Package"               $LsiInfo.PackageVersion              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Firmware"              $LsiInfo.FirmwareVersion             $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

        EndConfigDevice $xmlWriter
        
        #-------------------------------------------------------------------------------------
        # Get the disk information
        #-------------------------------------------------------------------------------------
        $LsiDiskInfo      = Get-LsiDiskInfo

        If ($LsiInfo.ProductName -eq 'LSI MegaRAID SAS 9270CV-8i') 
        { 
            $DiskInfo         = $LsiDiskInfo.Disks
            $UseLsiInfo       = $true
        }
        Else                                                       
        { 
            $DiskInfo         = Get-WmiObject Win32_DiskDrive 
            $UseLsiInfo       = $false
        }
        
        $DiskInfo | ForEach-Object {

            If ($_.Model -ne $null)          { $_.Model         = $_.Model.Trim() }
            If ($_.MediaType -ne $null)      { $_.MediaType     = $_.MediaType.Trim() }
            If ($_.SerialNumber -ne $null)   { $_.SerialNumber  = $_.SerialNumber.Trim() }

            StartConfigDevice $xmlWriter  "Disk"   $WCS_CFG_DISPLAY.TRUE
        
            AddDeviceParameter $xmlWriter "Location"              $_.DeviceId                           $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Manufacturer"          $_.Model                              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Model"                 $_.Model                              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "MediaType"             $_.MediaType                          $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "Size"                  $_.Size                               $WCS_CFG_COMPARE.PERCENT     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "SizeString"            (BaseLib_GetSizeStringXB $_.Size)     $WCS_CFG_COMPARE.NEVER       $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "Firmware"              $_.FirmwareRevision                   $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "SerialNumber"          $_.SerialNumber                       $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE
  
            If ($UseLsiInfo)
            {
                AddDeviceParameter $xmlWriter "Enclosure"             $_.EnclosureId                  $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
                AddDeviceParameter $xmlWriter "Slot"                  $_.SlotId                       $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
                AddDeviceParameter $xmlWriter "SMART"                 $_.SmartAlert                   $WCS_CFG_COMPARE.NEVER      $WCS_CFG_DISPLAY.TRUE
                AddDeviceParameter $xmlWriter "Status"                $_.Status                       $WCS_CFG_COMPARE.NEVER      $WCS_CFG_DISPLAY.TRUE

                $LabelLocation  = DefinedSystem_GetDiskLocation $_   $_.EnclosureId  $_.SlotId   
            }
            Else
            {
                AddDeviceParameter $xmlWriter "Enclosure"             $WCS_NOT_AVAILABLE              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
                AddDeviceParameter $xmlWriter "Slot"                  $WCS_NOT_AVAILABLE              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
                AddDeviceParameter $xmlWriter "SMART"                 $WCS_NOT_AVAILABLE              $WCS_CFG_COMPARE.NEVER      $WCS_CFG_DISPLAY.TRUE
                AddDeviceParameter $xmlWriter "Status"                $_.Status.Trim()                $WCS_CFG_COMPARE.NEVER      $WCS_CFG_DISPLAY.TRUE

                $LabelLocation  = DefinedSystem_GetDiskLocation $_  $WCS_NOT_AVAILABLE   $WCS_NOT_AVAILABLE   

            }

            AddDeviceParameter $xmlWriter "LabelLocation"         $LabelLocation                $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE


            EndConfigDevice $xmlWriter
        }

        #-------------------------------------------------------------------------------------
        # Get the NIC information
        #-------------------------------------------------------------------------------------
        Get-WmiObject Win32_NetworkAdapter -Filter "MacAddress!=NULL" | ForEach-Object {

            If ($_.Manufacturer -ne $null)  { $_.Manufacturer = $_.Manufacturer.Trim() }
            If ($_.Description -ne $null)   { $_.Description  = $_.Description.Trim() }
 
            StartConfigDevice $xmlWriter  "NIC"   $WCS_CFG_DISPLAY.TRUE
        
            AddDeviceParameter $xmlWriter "Location"              $_.PNPDeviceId                        $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Description"           $_.Description                        $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Manufacturer"          $_.Manufacturer                       $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "MAC"                   $_.MacAddress                         $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Speed"                 $_.Speed                              $WCS_CFG_COMPARE.ON_EXACT   $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Firmware"              $WCS_NOT_AVAILABLE                    $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Status"                $_.NetConnectionStatus                $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            EndConfigDevice $xmlWriter
        }
        #-------------------------------------------------------------------------------------
        # Get the Mellanox information
        #-------------------------------------------------------------------------------------
        $MellanoxInfo   = Get-MellanoxInfo

        StartConfigDevice $xmlWriter  "Mellanox"   $WCS_CFG_DISPLAY.TRUE
        
        AddDeviceParameter $xmlWriter "Location"              "System"                                   $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Device"                $MellanoxInfo.Device                       $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "PXE"                   $MellanoxInfo.PxeVersion                   $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "UEFI"                  $MellanoxInfo.UefiVersion                  $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
        AddDeviceParameter $xmlWriter "Firmware"              $MellanoxInfo.FirmwareVersion              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

        EndConfigDevice $xmlWriter

        #-------------------------------------------------------------------------------------
        # Get the OS Driver information
        #-------------------------------------------------------------------------------------
        If (-NOT $SkipDriver)
        {
            $OsDriverInfo   = Get-OsDriverInfo

            StartConfigDevice $xmlWriter "Driver"   $WCS_CFG_DISPLAY.TRUE

            AddDeviceParameter $xmlWriter "Location"           "System"                              $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE
            AddDeviceParameter $xmlWriter "LSI"                $OsDriverInfo.LSI                     $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "Mellanox"           $OsDriverInfo.Mellanox                $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "IntelProcessor"     $OsDriverInfo.IntelProcessor          $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "IntelSystemOem"     $OsDriverInfo.IntelSystemOem          $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
            AddDeviceParameter $xmlWriter "IntelSystemMachine" $OsDriverInfo.IntelSystemMachine      $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE

            EndConfigDevice $xmlWriter
        }
 
        #-------------------------------------------------------------------------------------
        # Get the PCI devices
        #------------------------------------------------------------------------------------- 
        $PnpInfo        = Get-WmiObject Win32_PnpEntity  -Property DeviceId,Manufacturer,Description,Status,ConfigManagerErrorCode  -Filter "DeviceId Like 'USB%' Or DeviceId LIKE 'PCI%'"

        $PnpInfo | ForEach-Object {

            if ($_.DeviceId.StartsWith("PCI"))
            {
                StartConfigDevice $xmlWriter  "PCI"   $WCS_CFG_DISPLAY.FALSE
       
                AddDeviceParameter $xmlWriter "Location"              $_.DeviceId                      $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE
                AddDeviceParameter $xmlWriter "Manufacturer"          $_.Manufacturer                  $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE
                AddDeviceParameter $xmlWriter "Description"           $_.Description                   $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE
                AddDeviceParameter $xmlWriter "Status"                $_.Status                        $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
                AddDeviceParameter $xmlWriter "ConfigMgrError"        $_.ConfigManagerErrorCode        $WCS_CFG_COMPARE.NEVER      $WCS_CFG_DISPLAY.TRUE

                EndConfigDevice $xmlWriter
            }
        }
        #-------------------------------------------------------------------------------------
        # Get the USB devices
        #-------------------------------------------------------------------------------------
        $PnpInfo | ForEach-Object {

            if ($_.DeviceId.StartsWith("USB"))
            {
                StartConfigDevice $xmlWriter  "USB"   $WCS_CFG_DISPLAY.FALSE
       
                AddDeviceParameter $xmlWriter "Location"              $_.DeviceId                       $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE
                AddDeviceParameter $xmlWriter "Manufacturer"          $_.Manufacturer                   $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE
                AddDeviceParameter $xmlWriter "Description"           $_.Description                    $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.FALSE
                AddDeviceParameter $xmlWriter "Status"                $_.Status                         $WCS_CFG_COMPARE.ALWAYS     $WCS_CFG_DISPLAY.TRUE
                AddDeviceParameter $xmlWriter "ConfigMgrError"        $_.ConfigManagerErrorCode         $WCS_CFG_COMPARE.NEVER      $WCS_CFG_DISPLAY.TRUE

                EndConfigDevice $xmlWriter
            }
        }
        #-------------------------------------------------------------------------------------
        # Add comments with the screen output of the utilities
        #-------------------------------------------------------------------------------------
        $xmlwriter.WriteComment( $LsiInfo.Output )
        $xmlwriter.WriteComment( $LsiDiskInfo.Output )
        $xmlwriter.WriteComment( $MellanoxInfo.Output )


        $xmlwriter.WriteEndElement()
        $xmlwriter.Close()
        $WcsConfig = New-Object system.Xml.xmldocument
        $WcsConfig.LoadXml( $myBuilder.ToString() )

        Return $WcsConfig
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
# Get-WcsConfig
#-------------------------------------------------------------------------------------
Function Get-WcsConfig() {

   <#
  .SYNOPSIS
   Gets a server configuration 

  .DESCRIPTION
   Returns a server configuration in the form of an xml object which can be used
   with the other WcsConfig commands. 
   
   If File is not specified returns the current configuration.

   If Path specified searches for file in Path else uses default directory.

  .EXAMPLE
   $MyConfig = Get-WcsConfig

   Reads the current server configuration and stores in the $MyConfig variable

  .EXAMPLE
   $MyConfig = Get-WcsConfig  DefaultConfig

   Reads the  server configuration from the file DefaultConfig into $MyConfig variable

  .PARAMETER File
   Name of the file to read without the filename extension.

  .PARAMETER Path
   Path to the file.  If not specified the default configuration directory is used.

  .OUTPUTS
   Returns xml object on success, $null on error

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config
   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$false,Position=0)]   [String] $File       =  '',
        [Parameter(Mandatory=$false)]              [String] $Path       =  $WCS_CONFIGURATION_DIRECTORY,
                                                   [switch] $SkipDriver
    )
    
    Try
    {
        $ConfigArray = @()
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # If no file give then return the current configuration
        #-------------------------------------------------------
        if ("" -eq $File)
        {
            Write-Verbose "No file specified so returning current configuration`r"
            If ($SkipDriver) { Return  (GenerateWcsConfig -SkipDriver)  }
            Else             { Return  (GenerateWcsConfig )  }

        }
        #-------------------------------------------------------
        # Read the specified file
        #-------------------------------------------------------
        else
        {
            $File = $File.ToLower()
           
            if ($File.EndsWith(".xml"))    { $File =  $File.Remove($File.Length - ".xml".Length)     }
            if ($File.EndsWith(".log"))    { $File =  $File.Remove($File.Length - ".log".Length)     }
            if ($File.EndsWith(".config")) { $File =  $File.Remove($File.Length - ".config".Length)  }

            $File += ".config.xml"
           
            $FilePath = Join-Path $Path $File 

            if (Test-Path $FilePath)
            {
                Write-Verbose "Reading file '$FilePath'`r"

                $ConfigFromFile = [xml] (Get-Content $FilePath)

                #-------------------------------------------------------
                # Verify a valid configuration
                #-------------------------------------------------------
                if (-NOT (IsValidConfig $ConfigFromFile))
                {
                    Write-Host -ForegroundColor Red  "File '$FilePath' does not contain a valid configuration`r"
                    Return $null
                }
                Return $ConfigFromFile
            }
            else
            {
                Write-Host -ForegroundColor Red  "Could not open configuration file '$FilePath'`r"
                Return $null
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
 
        Return $null
    }
}
#-------------------------------------------------------------------------------------
# Log-WcsConfig
#-------------------------------------------------------------------------------------
Function Log-WcsConfig() {

   <#
  .SYNOPSIS
   Logs a server configuration to a file

  .DESCRIPTION
   Saves a server configuration to log file specified   

   Do not add the filename extension as it will be added automatically

   If Path is specified saves file to directory in Path.  Path must exist because
   the script will not create it.

   If Path not specified uses default directory.

   Creates $file.config.xml file with xml config data
   Creates $file.config.log file with readable config data

  .EXAMPLE
   Log-WcsConfig -Config $MyConfig -File RefConfig

   Saves the configuration in the $MyConfig variable in the file RefConfig

  .EXAMPLE
   Log-WcsConfig  RefConfig -Config (Get-WcsConfig)  

   Saves the current server configuration into the file RefConfig

  .PARAMETER Config
   Configuration xml object to save to the file.  If not specified logs the current
   configuration.

  .PARAMETER File
   Name of the file to read without the filename extension.

  .PARAMETER Path
   Path to the file.  If not specified the default configuration directory is used.

  .OUTPUTS
   Returns xml object on success, $null on error

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config 

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$true,Position=0)]  [String] $File,
        [Parameter(Mandatory=$false)]            [xml]    $Config = $null,
        [Parameter(Mandatory=$false)]            [String] $Path = $WCS_CONFIGURATION_DIRECTORY
    )
    
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        Write-Host " Logging system configuration with Log-WcsConfig`r`n`r"
        #-------------------------------------------------------
        # Get current config if not specified
        #-------------------------------------------------------
        If ($null -eq $Config)
        {
            $Config = Get-WcsConfig
        }
        #-------------------------------------------------------
        # Verify a valid configuration
        #-------------------------------------------------------
        if (-NOT (IsValidConfig $Config))
        {
            Write-Host -ForegroundColor Red  "Config specified is not valid`r"
            Return $WCS_RETURN_CODE_GENERIC_ERROR
        }
        #-------------------------------------------------------
        # Check the file path is directory that exists
        #-------------------------------------------------------
        if (Test-Path $Path -PathType Container)
        {
            $Path = (Resolve-Path $Path).Path   #Convert to full path for XML save

            $File = $File.ToLower()

            if ($File.EndsWith(".xml"))    { $File =  $File.Remove($File.Length - ".xml".Length)     }
            if ($File.EndsWith(".log"))    { $File =  $File.Remove($File.Length - ".log".Length)     }
            if ($File.EndsWith(".config")) { $File =  $File.Remove($File.Length - ".config".Length)  }

            $FilePath = Join-Path $Path ($File + ".config.xml")  
            
            Write-Verbose "Saving configuration in xml format to'$FilePath'`r"
    
            #-------------------------------------------------------
            # Save the configuration
            #-------------------------------------------------------
            $Config.Save($FilePath)

            $FilePath = Join-Path $Path ($File + ".config.log")

            Write-Verbose "Saving configuration in text format to'$FilePath'`r"

            Set-Content -Path  $FilePath -Value (GetBladeConfigSummary $Config)
            Add-Content -Path  $FilePath -Value (GetConfigDevices $Config $true $true )

            Return $WCS_RETURN_CODE_SUCCESS

        }
        else
        {
            Write-Host -ForegroundColor Red  "Path provided does not exist '$Path'`r"
            Return $WCS_RETURN_CODE_GENERIC_ERROR
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
 
        Return $WCS_RETURN_CODE_UNKNOWN_ERROR
    }
}
#-------------------------------------------------------------------------------------
# View-WcsConfig
#-------------------------------------------------------------------------------------
Function View-WcsConfig() {

   <#
  .SYNOPSIS
   Displays a configuration

  .DESCRIPTION
   Displays a configuration.  If config is not specified then displays the current config

   If -Full specified then displays all devices with compare results from Compare-WcsConfig

  .EXAMPLE
   View-WcsConfig

   Displays a summary of the current server configuration 

  .EXAMPLE
   View-WcsConfig -Full

   Displays a full view of the current configuration which includes all devices with any 
   comparison results (if any)

  .EXAMPLE
   View-WcsConfig $OldConfig -Full

   Displays a full view of the configuration in the $OldConfig variable
    
   .PARAMETER Config
   A configuration xml object

  .PARAMETER  Full
   Display all devices with any comparison results

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>

    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$false,Position=0)] [xml]     $Config  = $null,            
                                                 [switch]  $Full 
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #---------------------------------------------------------
        # If no config give then return the current configuration
        #---------------------------------------------------------
        if ($null -eq $Config)
        {
            Write-Verbose "No configuration specified so viewing current configuration`r"
            $Config = (Get-WcsConfig -SkipDriver)
        }
        #---------------------------------------------------------
        # Display summary or devices depending on options
        #---------------------------------------------------------
        $Config | Where-Object { $_ -ne $null} | ForEach-Object {

            Switch ($Config.WcsConfig.Type)
            {
                $WCS_TYPE_BLADE   { Write-Host ("{0}`r" -f (GetBladeConfigSummary   $Config))  ; break }
                $WCS_TYPE_CHASSIS { Write-Host ("{0}`r" -f (GetChassisConfigSummary $Config))   ; break }
                Default             { break }
            }
            if ($Full)  { Write-Host ("{0}`r" -f (GetConfigDevices $Config $Full $Full)) }
       }

    } #try

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
# Compare-WcsConfig
#-------------------------------------------------------------------------------------
Function Compare-WcsConfig() {

   <#
  .SYNOPSIS
   Compares two server configurations

  .DESCRIPTION
   Compares two server configurations and returns the number of mismatches.  If the
   configs are the same returns 0.

   Can also return the entire results as a config xml object using the RefToResults
   parameter

  .EXAMPLE
   Compare-WcsConfig $ReferenceConfig 

   Compares current configuration against $ReferenceConfig and displays results

  .EXAMPLE
   $Mismatches = Compare-WcsConfig $ReferenceConfig -Results ([ref] $WCS_CFG_RESULTConfig)

   Compares current configuration against $ReferenceConfig, displays mismatches and
   returns configuration in $WCS_CFG_RESULTConfig

  .EXAMPLE
   $Mismatches = Compare-WcsConfig $BiosVersion -OnlyRefDevices

   Compares devices in $BiosVersion against the same devices in the current configuration
   ignoring additional devices in the source config. 

  .PARAMETER RefConfig
   Reference config xml object to compare against

  .PARAMETER SourceConfig
   Source config xml object that is compared against the reference.  If not specified
   then the current configuration is used

  .PARAMETER RefToResults
   PowerShell [ref] pointing to variable to store the results

  .PARAMETER Exact
   If specified then compares exact configurations.  Exact configurations include unique
   values such as serial numbers, GUID, MAC addresses

  .PARAMETER OnlyRefDevices
   If specified then compares only the devices in RefConfig against the SourceConfig and
   ignores additional devices in the SourceConfig

  .PARAMETER Quiet
   Supresses output.  Typically used when called from within another script.


  .OUTPUTS
   Returns number of mismatches.  Returns 0 if configs match

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$true,Position=0)]   [xml] $RefConfig,
        [Parameter(Mandatory=$false)]             [xml] $SourceConfig = $null,
        [Parameter(Mandatory=$false)]             [ref] $RefToResults,
        [Switch]                                  $Exact,
        [Switch]                                  $OnlyRefDevices,
        [Switch]                                  $Quiet
    )
   

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        If (-Not $Quiet) { Write-Host (" Comparing configurations with {0}`r`n`r" -f $FunctionInfo.Name) }

        #------------------------------------------
        # These count number of device mismatches
        #------------------------------------------
        $MismatchDeviceCount   = 0        
        $MissingDeviceCount    = 0
        $UnexpectedDeviceCount = 0  

        #-------------------------------------------------------
        # Verify a valid configuration
        #-------------------------------------------------------
        if ($null -eq $SourceConfig)
        {
            Write-Verbose "Source configuration not provided so reading current configuration`r"
            $SourceConfig = Get-WcsConfig
        }
 
        $WCS_CFG_RESULTsConfig = $SourceConfig.Clone()
        #-------------------------------------------------------
        # Check config type
        #-------------------------------------------------------
        If ($SourceConfig.WcsConfig.Type -ne $RefConfig.WcsConfig.Type)
        {
            Throw ("Reference {0} and source {1} configuration types cannot be different" -f  $RefConfig.WcsConfig.Type,$SourceConfig.WcsConfig.Type)
        }
        #-------------------------------------------------------
        # Clear any old results
        #-------------------------------------------------------
        $WCS_CFG_RESULTsConfig.WcsConfig.ChildNodes | ForEach-Object {

            If ($_.Name -ne '#comment')
            {
                $_.CompareResult = $WCS_CFG_RESULT.NONE
                $_.ChildNodes | ForEach-Object {   $_.CompareResult = $WCS_CFG_RESULT.NONE }
            }
        }
 
        if (-NOT (IsValidConfig $RefConfig))
        {
            Throw "Reference configuration provided is not a valid configuration"
        }
        if (-NOT (IsValidConfig $WCS_CFG_RESULTsConfig))
        {
            Throw "Source configuration provided is not a valid configuration"
        }
        #------------------------------------------------------------
        # Verify devices in reference configuration match the target
        #------------------------------------------------------------
        $RefConfig.WcsConfig.ChildNodes | ForEach-Object { 

            If ($_.Name -ne '#comment')
            {

            if (-NOT $Quiet) { Write-Verbose ("Checking reference device '{0}' at location '{1}'`r" -f $_.Name, $_.Location.Value) }

            $RefDevice      = $_.Name
            $RefLocation    = $_.Location.Value
            #------------------------------------------------------------               
            # Find the matching source device.
            # Location must match and must not have been used already
            #------------------------------------------------------------     
            $SourceDevice = $null
                                             
            $WCS_CFG_RESULTsConfig.SelectNodes("WcsConfig/$RefDevice") | ForEach-Object {

                if (-NOT $Quiet) { Write-Verbose ("Checking source device '{0}' at location '{1}' and '{2}'`r" -f $_.Name,$_.Location.Value,$_.CompareResult) }

                if (($_.Location.Value -eq $RefLocation) -and ($_.CompareResult -eq $WCS_CFG_RESULT.NONE))
                {
                    $SourceDevice    = $_
                    
                    $_.CompareResult = $WCS_CFG_RESULT.FOUND
                }
            }
            if ($null -eq $SourceDevice)
            {
                $Comment = $WCS_CFG_RESULT.Missing + " DEVICE: '$RefDevice'  at location '$RefLocation' not found in Source "
                if (-NOT $Quiet) { Write-Host "`t$Comment`r" -f Yellow }

                $MissingDeviceCount++

                $MissingDevice = AddNewDevice $WCS_CFG_RESULTsConfig $RefDevice
                $MissingDevice.CompareResult = $Comment  
            }
 
            #------------------------------------------------------------               
            # Compare each parameter in the device
            #------------------------------------------------------------    
            $DeviceMismatch = $false

                $_.ChildNodes  | ForEach-Object {

                    $ParameterName  = $_.Name
                    $RefValue       = $_.Value

                    if (-NOT $Quiet) { Write-Verbose ("Compare ref parameter '$ParameterName' =  '$RefValue' `r") }

                    #------------------------------------------------------------               
                    # If did not find source device log comment
                    #------------------------------------------------------------  
                    if ($null -eq $SourceDevice)
                    {
                        $Comment = $WCS_CFG_RESULT.MISSING + " PARAMETER: '$RefDevice.$ParameterName' not found in Source. Value '$RefValue'"

                        if (-NOT $Quiet) { Write-Host -ForegroundColor Yellow  "`t$Comment`r" }
                        AddNewProp   $WCS_CFG_RESULTsConfig  $MissingDevice  $ParameterName  $RefValue  $_.CompareType $_.Display  $Comment
                    }
                    #------------------------------------------------------------               
                    # Found source device
                    #------------------------------------------------------------ 
                    else
                    {
                        $SourceParameter =  $SourceDevice.SelectSingleNode("$ParameterName")
                                  
                        #------------------------------------------------------------               
                        # If did not find device parameter add comment
                        #------------------------------------------------------------ 
                        if ($null -eq $SourceParameter)
                        {
                            $DeviceMismatch             = $true
                            $Comment = $WCS_CFG_RESULT.MISSING + " PARAMETER: '$RefDevice.$ParameterName' not found in Source. Value '$RefValue'"
                        
                            $SourceDevice.CompareResult = $WCS_CFG_RESULT.MISMATCH

                            if (-NOT $Quiet) { Write-Host -ForegroundColor Yellow  "`t$Comment`r" }
                            AddNewProp   $WCS_CFG_RESULTsConfig  $SourceDevice  $ParameterName  $RefValue  $_.CompareType $_.Display  $Comment
                        }
                        else
                        {
                            $SourceValue       =  $SourceParameter.Value 

                            if (-NOT $Quiet) { Write-Verbose ("Comparing source parameter '{0}' = '{1}' with '{2}'`r" -f $SourceParameter.Name, $SourceValue,$SourceParameter.CompareResult) }

                            #------------------------------------------------------------
                            # Check verify type to determine if need to compare
                            #------------------------------------------------------------
                            switch($_.CompareType)
                            {
                                #------------------------------------------------------------
                                # Don't compare but add comment with reference value
                                #------------------------------------------------------------
                                $WCS_CFG_COMPARE.NEVER 
                                {

                                    $Comment = $WCS_CFG_RESULT.SKIPPED + " PARAMETER: '$RefDevice.$ParameterName' not compared.  Reference value '$RefValue'"
                        
                                    $SourceParameter.CompareResult = $Comment  
                                    
                                    if (-NOT $Quiet) { Write-Verbose "`t$Comment`r" }

                                    Break
                                }
                                #------------------------------------------------------------
                                # Compare only if -Exact switch true
                                #------------------------------------------------------------
                                $WCS_CFG_COMPARE.ON_EXACT 
                                {
                                    if(-NOT $Exact)
                                    {
                                        $Comment = $WCS_CFG_RESULT.SKIPPED + " PARAMETER: '$RefDevice.$ParameterName' not compared.  Reference value '$RefValue'"
                        
                                        $SourceParameter.CompareResult = $Comment 
                        
                                        if (-NOT $Quiet) { Write-Verbose "`t$Comment`r" }
                                    }
                                    elseif ($SourceValue -ne $RefValue)
                                    {
                                        $DeviceMismatch             = $true
                                        $SourceDevice.CompareResult = $WCS_CFG_RESULT.MISMATCH
 
                                        $Comment = $WCS_CFG_RESULT.MISMATCH + " PARAMETER: '$RefDevice.$ParameterName' value '$RefValue' and Source value '$SourceValue'"
                        
                                        $SourceParameter.CompareResult =     $Comment  
                                        if (-NOT $Quiet) { Write-Host "`t$Comment`r" -f Yellow }
                                    }
                                    else
                                    {
                                        $SourceParameter.CompareResult = $WCS_CFG_RESULT.MATCH
                                    }
                                    Break
                                }
                                #------------------------------------------------------------
                                # Compare 
                                #------------------------------------------------------------
                                $WCS_CFG_COMPARE.ALWAYS
                                {
                                    if ($SourceValue -ne $RefValue)
                                    {
                                        $DeviceMismatch              = $true
                                        $SourceDevice.CompareResult  = $WCS_CFG_RESULT.MISMATCH
                                        $Comment = $WCS_CFG_RESULT.MISMATCH + " PARAMETER: '$RefDevice.$ParameterName' value '$RefValue' and Source value '$SourceValue'"
                         
                                        $SourceParameter.CompareResult = $Comment 

                                        if (-NOT $Quiet) { Write-Host "`t$Comment`r" -f Yellow }
                                    }
                                    else
                                    {
                                        $SourceParameter.CompareResult = $WCS_CFG_RESULT.MATCH
                                    }
                                    Break
                                }
                                #------------------------------------------------------------
                                # Compare 
                                #------------------------------------------------------------
                                $WCS_CFG_COMPARE.PERCENT
                                {
                                    $DblRefValue     = [double] ($RefValue.split()[0])
                                    $DblSourceValue  = [double] ($SourceValue.split()[0])

                                    if (  ($DblSourceValue -gt (1.01 * $DblRefValue)) -or ($DblSourceValue -lt  (0.99* $DblRefValue) ) )
                                    {
                                        $DeviceMismatch             = $true
                                        $SourceDevice.CompareResult = $WCS_CFG_RESULT.MISMATCH
                                        $Comment = $WCS_CFG_RESULT.MISMATCH + " PARAMETER: '$RefDevice.$ParameterName' value '$RefValue' and Source value '$SourceValue'"
                         
                                        $SourceParameter.CompareResult = $Comment 
                                        if (-NOT $Quiet) { Write-Host "`t$Comment`r" -f Yellow }

                                    }
                                    else
                                    {
                                        $SourceParameter.CompareResult = ("{0}: Reference value '$RefValue'" -f $WCS_CFG_RESULT.MATCH )
                                    }
                                    Break
                                }
                                #------------------------------------------------------------
                                # Throw error on unknown type 
                                #------------------------------------------------------------
                                default
                                {
                                    Throw ("Illegal CompareType atrribute found '" + $_.CompareType + "' on reference device '$RefDevice' parameter '$ParameterName'")
                                }
                            } # end switch

                        } # end else
                    } # end else
                } # end foreach child 
          
                if ((-NOT $OnlyRefDevices) -and ($null -ne $SourceDevice))
                {
 
                    $SourceDevice.ChildNodes  | ForEach-Object {

                        #------------------------------------
                        # Ignore any comments added above
                        #------------------------------------
                        if (('#comment' -ne $_.Name) -and ($WCS_CFG_RESULT.NONE -eq $_.CompareResult))
                        {
                            $DeviceMismatch = $true
                            $Comment         = $WCS_CFG_RESULT.UNEXPECTED + " PARAMETER: Source parameter '" + $SourceDevice.Name + "." + $_.Name + "' not found in Reference.  Value '"+$_.Value + "'"

                            $_.CompareResult = $Comment

                             if (-NOT $Quiet) { Write-Host "`t$Comment`r" -f Yellow }
                        
                        }
                    }
                }

                if ($DeviceMismatch) { $MismatchDeviceCount++ }
            }
        } 
          
        #------------------------------------------------------------
        # Check for source devices that were not found
        #------------------------------------------------------------
        if (-NOT $OnlyRefDevices)
        {
            $WCS_CFG_RESULTsConfig.WcsConfig.ChildNodes | ForEach-Object { 
                #------------------------------------
                # Ignore any comments added above
                #------------------------------------
                if (('#comment' -ne $_.Name) -and ($WCS_CFG_RESULT.NONE -eq $_.CompareResult))
                {
                    $UnexpectedDeviceCount++
                    $Comment = $WCS_CFG_RESULT.UNEXPECTED + " DEVICE:  Source device '" + $_.Name + "' (Location '" + $_.Location.Value + "') not found in Reference"
                    $_.CompareResult = $Comment

                     if (-NOT $Quiet) { Write-Host "`t$Comment`r" -f Yellow }
                }
            }
        }

        #------------------------------------------------------------
        # Update with error count
        #------------------------------------------------------------
        $WCS_CFG_RESULTsConfig.WcsConfig.CompareErrors = ("{0}" -f ($UnexpectedDeviceCount + $MismatchDeviceCount+ $MissingDeviceCount))

        #------------------------------------------------------------
        # Display summary
        #------------------------------------------------------------
        if (-NOT $Quiet)
        {
            if (0 -eq $MissingDeviceCount)    { Write-Host ("`tMissing devices:    {0}`r" -f $MissingDeviceCount) }
            else                              { Write-Host ("`tMissing devices:    {0}`r" -f $MissingDeviceCount) -ForegroundColor Yellow }
            if (0 -eq $UnexpectedDeviceCount) { Write-Host ("`tUnexpected devices: {0}`r" -f $UnexpectedDeviceCount) }
            else                              { Write-Host ("`tUnexpected devices: {0}`r" -f $UnexpectedDeviceCount)-ForegroundColor Yellow }
            if (0 -eq $MismatchDeviceCount)   { Write-Host ("`tMismatched devices: {0}`r" -f $MismatchDeviceCount) }
            else                              { Write-Host ("`tMismatched devices: {0}`r" -f $MismatchDeviceCount) -ForegroundColor Yellow }
            Write-Host "`r"
        }
        #------------------------------------------------------------
        # Return the results if requested
        #------------------------------------------------------------
        if ($null -ne $RefToResults)
        {
            $RefToResults.Value = $WCS_CFG_RESULTsConfig.Clone()
        }
 

        Return  ($UnexpectedDeviceCount + $MismatchDeviceCount+ $MissingDeviceCount)
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
# Get-WcsLogicalDrive
#-------------------------------------------------------------------------------------
Function Get-WcsLogicalDrive() {

   <#
  .SYNOPSIS
   Returns logical drives to be tested

  .DESCRIPTION
   Returns an array of logical drives (for example C:, D:) to be used for testing
   Only returns Local Disks. Does not return Removeable, network, CD, and RAM disks.

   By default C: is not returned because it is typically the OS drive.

   If -Full specified then returns all logical drives including C:

   This function uses the WMI class Win32_LogicalDisk

  .EXAMPLE
   $OsDrivesToTest = Get-WcsLogicalDrive

   Stores all drives except C: into variable $OsDrivesToTest
  .EXAMPLE
   $AllDrivesToTest = Get-WcsLogicalDrive -Full

   Stores all drives seen by Windows into variable $AllDrivesToTest
    
  .PARAMETER  Full
   Returns all logical drive

  .OUTPUTS
   Returns array with drive info

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [switch] $Full 
    )
    
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation


        $LogicalDrives = @()

        $Drives = Get-WmiObject Win32_LogicalDisk 

        ForEach ($Drive in $Drives)
        {
            If (($Drive.DriveType -eq 3) -and ($Drive.FreeSpace -gt 100000000) -and ($Full -or ($Drive.Name -ne "C:")) )
            {
                $LogicalDrives += $Drive.Name
            }
        }
        Return $LogicalDrives
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
 
        Return @()
    }
}
#-------------------------------------------------------------------------------------
# Get-WcsPhysicalDisk
#-------------------------------------------------------------------------------------
Function Get-WcsPhysicalDisk() {

   <#
  .SYNOPSIS
   Returns physical disks to be tested

  .DESCRIPTION
   Returns an array of physical disks (for example \\.\\PHYSICALDDRIVE5) to be used 
   for testing

   By default disks with partitions are not returned because they typically
   are tested as logical drives

   If -Full specified then returns all disks

   Function uses the WMI class Win32_DiskDrive

  .EXAMPLE
   $DiskToTest =  Get-WcsPhysicalDisk

   Stores all disks without partitions into variable $DiskToTest
  .EXAMPLE
   $AllDisks = Get-WcsPhysicalDisk

   Stores all disks seen into $AllDisks
    
  .PARAMETER  Full
   Return all disks 

  .OUTPUTS
   Returns array with disk info
   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [switch] $Full 
    )
    
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        $PhysicalDisks = @()

        $Disks = Get-WmiObject Win32_DiskDrive 

        ForEach ($Disk in $Disks) 
        {
            If ($Full -or ($Disk.Partitions -eq 0))
            {
                $PhysicalDisks += $Disk.Name
            }
        }
        Return $PhysicalDisks
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
 
        Return @()
    }
}
#----------------------------------------------------------------------------------------------
#  Log-MsInfo32
#----------------------------------------------------------------------------------------------
Function Log-Msinfo32()
{
   <#
  .SYNOPSIS
   Runs msinfo32 and log results to a file

  .DESCRIPTION
   Runs msinfo32 and log results to a file.  msinfo32 collects a weatlh of 
   system information which is useful for configuration tracking.
    
  .PARAMETER  LogDirectory
   Logs results in this directory.  
   If not specified defaults to <InstallDir\Results\<FunctionName>\<DateTime>

  .EXAMPLE
   Log-Msinfo32 \WcsTest\Results\MySystemInfo

   Stores msinfo32 output to \WcsTest\Results\MySystemInfo

  .EXAMPLE
   Log-Msinfo32 

   Stores msinfo32 output to <InstallDir\Results\Log-MsInfo32\<DateTime>

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
   
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [string] $LogDirectory=''
    )
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        Write-Host " Logging system info with Log-Msinfo32`r`n`r"

        #------------------------------------------------
        # Verify not running in WinPE
        #------------------------------------------------
        If (CoreLib_IsWinPE)
        {
            Throw "This function does not run in the WinPE OS"
        }
        #------------------------------------------------
        # Create a directory to store results 
        #------------------------------------------------
        $WCS_CFG_RESULTsDirectory = BaseLib_GetLogDirectory $LogDirectory $FunctionInfo.Name
  
        #------------------------------------------------
        # Run msinfo32 to log the system info  
        #------------------------------------------------
        BaseLib_RunProcessAndWait "msinfo32.exe"  ("/report {0}\msinfo32.log" -f $WCS_CFG_RESULTsDirectory)    | Out-Null

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
# Update-WcsConfig
#-------------------------------------------------------------------------------------
Function Update-WcsConfig()
{
<#
  .SYNOPSIS
   Updates all programmables on a WCS system

  .DESCRIPTION
   Updates all programmables on a WCS system which includes BIOS, BMC, adapter firmware,
   BIOS settings, CPLD, and others.

   The default update is to the default (Exchange) configuration.   To update to something
   other than defaults specify the path.  Valid configuration paths are:
   
      <InstallDirectory>\Updates\Azure            Updates to Azure configuration
      <InstallDirectory>\Updates\Bing             Updates to Bing configuration    

   To view available updates use the View-WcsUpdates command

   Reads the system BIOS and FRU information to determine the correct updates to run

  .EXAMPLE
   Update-WcsConfig Exchange

   Updates the local WCS system to the latest Exchange recipe.  

  .EXAMPLE
   Update-WcsConfig Azure

   Updates the local WCS system to the latest Azure recipe.  

  .PARAMETER Recipe
   Recipe to use. This is the child folder in \<InstallDirectory>\Updates\ 
   that contains the updates.  For example, the Azure recipe can be found in
   \<InstallDirectory>\Updates\Azure

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateSet('Azure','Exchange')] 
        [string] $Recipe = ''
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation


        #-------------------------------------------------------
        # Get system information 
        #-------------------------------------------------------
        $SystemType = Lookup-WcsSystem

        If ('' -eq $Recipe)
        {
            Switch ((Get-WmiObject win32_ComputerSystem).Model)
            {
                'C1000'  { $Recipe = 'exchange'; break }
                'C1020'  { $Recipe = 'azure'; break }
                'C1030Q' { $Recipe = 'azure'; break }
                Default  
                { 
                    If ($SystemType -eq $WCS_SYSTEM_QUANTA_CM1)
                    {
                        Try
                        {
                            $ChassisManagerConfig = [xml] (Get-Content  "\ChassisManager\Microsoft.GFS.WCS.ChassisManager.exe.config")

                            $SslEncryption   =  ( $ChassisManagerConfig.Configuration.appSettings.SelectNodes("add") | Where-Object { $_.Key –eq "EnableSslEncryption" } ).Value

                            If ($SslEncryption -eq "1")
                            {
                                $Recipe = 'azure' ;break
                            }
                            Else
                            {
                                $Recipe = 'exchange' ;break
                            }
                        }
                        Catch
                        {
                        }
                    }
                    Throw "Cannot update because not a WCS system or system FRU is corrupted"
               }                              
            }
        }
        #-------------------------------------------------------
        # Setup vars and constants
        #-------------------------------------------------------                
        If ($SystemType -ne $WCS_NOT_AVAILABLE)
        {

            If (-NOT (Test-Path "$WCS_UPDATE_DIRECTORY\$Recipe\$SystemType"))
            {
                Throw ("Recipe '{0}' does not exist for system type '{1}'`r" -f $Recipe,$SystemType )   
            }

            $returnCode = & "$WCS_UPDATE_DIRECTORY\$Recipe\$SystemType\$WCS_UPDATE_SCRIPTFILE"
        }
        Else
        {
            Throw ("Unknown system type '{0}'`r" -f   $SystemType )   
        }
        Return $returnCode
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
# View-WcsDisk
#-------------------------------------------------------------------------------------
Function View-WcsDisk() {

   <#
  .SYNOPSIS
   Displays basic information at status of disks in WCS blade

  .DESCRIPTION
   Displays basic information at status of disks in WCS blade that is
   useful for troubleshooting and maintenance

   Does not list removable disks

  .EXAMPLE
   View-WcsDisk

   Displays the disk in the system

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
         [xml]    $Config     = $null
    )
     
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #---------------------------------------------------------
        # If no config give then return the current configuration
        #---------------------------------------------------------
        if ($null -eq $Config)
        {
            Write-Verbose "No configuration specified so viewing current configuration`r"
            $Config = (Get-WcsConfig -SkipDriver)
        }
        #------------------------------------------------
        # Display the disk info
        #------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-19} {1,-10} {2,-20} {3,-12} {4}`r" -f "Location","Status","Serial","Firmware","Size")
        Write-Host  "$WCS_HEADER_LINE`r"

        $ArrayOfDrives = @()

        $Config.WcsConfig.ChildNodes | Where-Object {"Disk" -eq $_.Name } | ForEach-Object {

            If (-NOT $_.MediaType.Value.Contains("Removable"))
            {
                $ArrayOfDrives +=  (" {0,-19} {1,-10} {2,-20} {3,-12} {4}" -f $_.LabelLocation.Value,$_.Status.Value,$_.SerialNumber.Value, $_.Firmware.Value,$_.SizeString.Value)   
            }
        }
        $ArrayOfDrives | Sort-Object | ForEach-Object { Write-Host "$_`r" }
        
        Write-Host  ("`r`n Found {0} disks in the system`r`n`r" -f $ArrayOfDrives.Count) 

    } #try
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
# View-WcsDimm
#-------------------------------------------------------------------------------------
Function View-WcsDimm() {

   <#
  .SYNOPSIS
   Displays basic information of DIMMs in WCS blade

  .DESCRIPTION
   Displays basic information about DIMMs in WCS blade that is
   useful for troubleshooting and maintenance

  .EXAMPLE
   View-WcsDimm

   Displays the DIMMS in the system

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    ( 
        [xml]    $Config     = $null
    )
     
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #---------------------------------------------------------
        # If no config give then return the current configuration
        #---------------------------------------------------------
        if ($null -eq $Config)
        {
            Write-Verbose "No configuration specified so viewing current configuration`r"
            $Config = (Get-WcsConfig -SkipDriver)
        }
         
        $Entries =  Get-WcsSel -ErrorAction SilentlyContinue # some systems don't have BMC 

        #------------------------------------------------
        # Display the disk info
        #------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-10} {1,-10} {2,-15} {3,-22} {4}`r" -f "Location","Status","Serial","Model","Size")
        Write-Host  "$WCS_HEADER_LINE`r"

        $DimmCount = 0

        $Config.WcsConfig.ChildNodes | Where-Object {"DIMM" -eq $_.Name } | ForEach-Object {

            $DIMM_STATUS   =   'OK'
            $DIMM_LOCATION = $_.LabelLocation.Value
            $DimmCount++

            $Entries | Where-Object {$_ -ne $null} | ForEach-Object { 
            
                If ($_.Location -eq $DIMM_LOCATION) 
                { 
                    $DIMM_STATUS = 'ERROR' 
                }
            }
        
           Write-Host  (" {0,-10} {1,-10} {2,-15} {3,-22} {4}`r" -f $_.LabelLocation.Value,$DIMM_STATUS,$_.SerialNumber.Value.Trim(),$_.Model.Value.Trim() , $_.SizeString.Value)        
        }

        Write-Host  ("`r`n Found {0} DIMMs in the system`r`n`r" -f $DimmCount) 

    } #try
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
# View-WcsNic
#-------------------------------------------------------------------------------------
Function View-WcsNic() {

   <#
  .SYNOPSIS
   Displays basic information on NICs in WCS blade

  .DESCRIPTION
   Displays basic information about the NICs in WCS blade that is
   useful for troubleshooting and maintenance

  .EXAMPLE
   View-WcsNic

   Displays the NIC info in WCS blade

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [xml]    $Config     = $null
    )
     
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #---------------------------------------------------------
        # If no config give then return the current configuration
        #---------------------------------------------------------
        if ($null -eq $Config)
        {
            Write-Verbose "No configuration specified so viewing current configuration`r"
            $Config = (Get-WcsConfig -SkipDriver)
        }
        #------------------------------------------------
        # Display the disk info
        #------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-50} {1}`r" -f "NIC","Mac")
        Write-Host  "$WCS_HEADER_LINE`r"
        $Config.WcsConfig.ChildNodes | Where-Object {"NIC" -eq $_.Name } | ForEach-Object {

           Write-Host  (" {0,-50} {1}`r`n " -f $_.Description.Value,$_.Mac.Value)        
        }
        Write-Host "`r`n "
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-20} {1,-15} {2,-15} {3,-15}`r" -f "Mellanox ID","Firwmare","PXE","UEFI")
        Write-Host  "$WCS_HEADER_LINE`r"
        $Config.WcsConfig.ChildNodes | Where-Object {"Mellanox" -eq $_.Name } | ForEach-Object {

           Write-Host  (" {0,-20} {1,-15} {2,-15} {3,-15}`r" -f $_.Device.Value,$_.Firmware.Value,$_.Pxe.Value,$_.Uefi.Value)        
        }

        Write-Host " `r"

    } #try
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
# View-WcsHba
#-------------------------------------------------------------------------------------
Function View-WcsHba() {

   <#
  .SYNOPSIS
   Displays basic information of HBA in WCS blade

  .DESCRIPTION
   Displays basic information about HBA in WCS blade that is
   useful for troubleshooting and maintenance

  .EXAMPLE
   View-WcsHba

   Displays the HBA info in WCS blade

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [xml]    $Config     = $null
    )
     
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #---------------------------------------------------------
        # If no config give then return the current configuration
        #---------------------------------------------------------
        if ($null -eq $Config)
        {
            Write-Verbose "No configuration specified so viewing current configuration`r"
            $Config = (Get-WcsConfig -SkipDriver)
        }
        #------------------------------------------------
        # Display the disk info
        #------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-26} {1,-15} {2,-15} {3,-15}`r" -f "HBA","Serial","Firwmare","FW Package")
        Write-Host  "$WCS_HEADER_LINE`r"
        $Config.WcsConfig.ChildNodes | Where-Object {"LSI" -eq $_.Name } | ForEach-Object {

           Write-Host  (" {0,-26} {1,-15} {2,-15} {3,-15}`r" -f $_.Product.Value,$_.SerialNumber.Value,$_.Firmware.Value,$_.Package.Value)        
        }

        Write-Host "`r`n "

    } #try
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
# View-WcsProcessor
#-------------------------------------------------------------------------------------
Function View-WcsProcessor() {

   <#
  .SYNOPSIS
   Displays basic information of processors in WCS blade

  .DESCRIPTION
   Displays basic information about processors in WCS blade that is
   useful for troubleshooting and maintenance

  .EXAMPLE
   View-WcsProcessor

   Displays the processor info for a WCS blade

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param( 
            [xml]    $Config     = $null
         )
     
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #---------------------------------------------------------
        # If no config give then return the current configuration
        #---------------------------------------------------------
        if ($null -eq $Config)
        {
            Write-Verbose "No configuration specified so viewing current configuration`r"
            $Config = (Get-WcsConfig -SkipDriver)
        }
        #------------------------------------------------
        # Display the disk info
        #------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-10} {1}`r" -f "Processor","Model")
       
        Write-Host  "$WCS_HEADER_LINE`r"
        $Config.WcsConfig.ChildNodes | Where-Object {"Processor" -eq $_.Name } | ForEach-Object {

           Write-Host  (" {0,-10} {1} `r" -f $_.Location.Value,$_.Description.Value )        
           Write-Host  (" {0,-10} {1} `r" -f " ",$_.Caption.Value)        
           Write-Host " `r"
        }

        Write-Host " `r"

    } #try
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
# View-WcsFru
#-------------------------------------------------------------------------------------
Function View-WcsFru() {

   <#
  .SYNOPSIS
   Displays basic FRU info for WCS blade

  .DESCRIPTION
   Displays the FRU info in WCS blade

  .EXAMPLE
   View-WcsFru

   Displays the FRU info in WCS blade

  .PARAMETER  Full
   Displays all FRU fields


  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
         [xml]    $Config = $null,
         [switch] $Full
    )
     
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #---------------------------------------------------------
        # If no config give then return the current configuration
        #---------------------------------------------------------
        if ($null -eq $Config)
        {
            Write-Verbose "No configuration specified so viewing current configuration`r"
            $Config = (Get-WcsConfig -SkipDriver)
        }
        #------------------------------------------------
        # Display the disk info
        #------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-25} {1} `r" -f "FRU Field","Value")       
        Write-Host  "$WCS_HEADER_LINE`r"

        If ($Full)
        {
            $Config.WcsConfig.FRU.ChildNodes | ForEach-Object {
            
                If ($WCS_CFG_DISPLAY.TRUE -eq $_.Display)  
                {
                    Write-Host  (" {0,-25} {1} `r" -f $_.Name, $_.Value) 
                }
            }
        }
        Else
        {
            Write-Host  (" {0,-25} {1} `r" -f "ProductName",$Config.WcsConfig.FRU.ProductName.Value)        
            Write-Host  (" {0,-25} {1}`r" -f "ProductModel",$Config.WcsConfig.FRU.ProductModel.Value)        
            Write-Host  (" {0,-25} {1}`r" -f "ProductAsset",$Config.WcsConfig.FRU.ProductAsset.Value)        
            Write-Host  (" {0,-25} {1}`r" -f "ProductSerial",$Config.WcsConfig.FRU.ProductSerial.Value)        
            Write-Host  (" {0,-25} {1}`r" -f "Version",$Config.WcsConfig.FRU.Version.Value)        
        }
        Write-Host " `r"

    } #try
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
# View-WcsFirmware
#-------------------------------------------------------------------------------------
Function View-WcsFirmware() {

   <#
  .SYNOPSIS
   Displays BIOS and BMC firmware versions on WCS blade

  .DESCRIPTION
   Displays BIOS and BMC firmware versions on WCS blade

  .EXAMPLE
   View-WcsFirmware

   Displays the BIOS and BMC versions

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]
    Param
    ( 
            [xml]    $Config     = $null
    )
     
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #---------------------------------------------------------
        # If no config give then return the current configuration
        #---------------------------------------------------------
        if ($null -eq $Config)
        {
            Write-Verbose "No configuration specified so viewing current configuration`r"
            $Config = (Get-WcsConfig -SkipDriver)
        }
        #------------------------------------------------
        # Display the disk info
        #------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" Firmware Versions`r")   
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-15} {1} `r" -f "BIOS ",$Config.WcsConfig.BIOS.SMBIOSVersion.Value)       
        Write-Host  (" {0,-15} {1} `r" -f "BMC ",$Config.WcsConfig.BMC.Version.Value)       

        Write-Host "`r`n "

    } #try

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
# View-WcsDrive
#-------------------------------------------------------------------------------------
Function View-WcsDrive() {

   <#
  .SYNOPSIS
   Displays the logical drives in WCS blade

  .DESCRIPTION
   Displays the logical drives in WCS blade

  .EXAMPLE
   View-WcsDrive

   Displays the logical drives in the system

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config

   #>
    [CmdletBinding(PositionalBinding=$false)]
    Param()

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #------------------------------------------------
        # Display the drive info
        #------------------------------------------------
        Write-Host  "$WCS_HEADER_LINE`r"
        Write-Host  (" {0,-6} {1,-20} {2}`r" -f "Drive","Description","Size")
        Write-Host  "$WCS_HEADER_LINE`r"

        Get-WmiObject Win32_LogicalDisk | ForEach-Object {

            If ($_.Size -eq $null) { Write-Host  (" {0,-6} {1,-20}                 `r" -f $_.DeviceID,$_.Description )    }
            Else                   { Write-Host  (" {0,-6} {1,-20} {2} ({3:f1} GB) `r" -f $_.DeviceID,$_.Description,$_.Size,($_.Size/$WCS_BYTES_IN_GB) )    }
           
        }
        Write-Host "`r`n "

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

#-----------------------------------------------------------------------------------
# View-WcsUpdate
#-----------------------------------------------------------------------------------
Function View-WcsUpdate()
{
   <#
  .SYNOPSIS
   Displays versions of available updates

  .DESCRIPTION
   Displays versions of available updates for programmable components such
   as BIOS, BMC, and adapter firmware.

   This command lists all updates available for all blades and chassis manager

   Use the -Path parameter to restrict the updates shown

  .PARAMETER Path
   Specifies the path to search for updates. This is the absolute path.  Example:

   \WcsTest\Scripts\Updates\Exchange
 
  .EXAMPLE
   View-WcsUpdate

   Shows all updates for all blades and chassis manager

  .EXAMPLE
   View-WcsUpdate  -Path \WcsTest\Scripts\Updates\Exchange\WCS_Blade_Gen1_Quanta

   Shows all updates for the Exchange configuration of the generation 1 Quanta
   compute blade.

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Config 

   #>
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [string] $Path=$WCS_UPDATE_DIRECTORY 
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        $Path = (Resolve-Path $Path).Path

        Write-Host ("$WCS_HEADER_LINE`r")
        Write-Host (" WCS Updates in {0}`r" -f $Path )
        Write-Host ("$WCS_HEADER_LINE`r")

        Get-ChildItem $Path -Recurse | ForEach-Object {

            $FileName = $_.FullName.Substring( ( 1 + $Path.Length))

            If ($_.Name -eq $WCS_UPDATE_SCRIPTFILE)
            {  
                If ($FileName -eq $WCS_UPDATE_SCRIPTFILE) { $FileName = "." }
                Else                                      { $FileName = $FileName.Substring(0, $FileName.Length - $WCS_UPDATE_SCRIPTFILE.Length - 1) }

                Get-Content -Path $_.FullName  | Select-String -SimpleMatch $WCS_UPDATE_VERSION_KEY  | ForEach-Object { 
        
                    $InputLine = $_.ToString().Split("=")

                    If ($InputLine.Count -eq 2)
                    {
                        $Key      = $InputLine[0].Trim()
                        $Version  = $InputLine[1].Trim()
                        $Version  = $Version.Trim('"')

                        If (($Key -eq $WCS_UPDATE_VERSION_KEY ) -and ($Version -ne $null))
                        {  
                            Write-Host (" {0,-50} {1}`r" -f $FileName,$Version )  
                        }
                    }                   
                }
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

