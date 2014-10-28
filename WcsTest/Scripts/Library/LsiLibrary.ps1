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

#-------------------------------------------------------------------------------------------------
# Gets the info from a LSI adapter 
#-------------------------------------------------------------------------------------------------
#  -  Uses StorCli64.exe and Sas2Flash
#  -  Assumes no more than one adapter
#  -  Supported adapters 9270 and 9207
#-------------------------------------------------------------------------------------------------
Function Get-LsiInfo()
{   
    [CmdletBinding()]
    Param()

    $LsiInfo = @{   ProductName     = $WCS_NOT_AVAILABLE;  # Model field, ie:  Model = LSI MegaRAID SAS 9270CV-8i
                    SerialNumber    = $WCS_NOT_AVAILABLE;  # Serial Number field, ie: Serial Number = SV30617025
                    PackageVersion  = $WCS_NOT_AVAILABLE;  # Firmware Package Build field, ie: Firmware Package Build = 23.12.0-0013
                    FirmwareVersion = $WCS_NOT_AVAILABLE;  # Firmware Version field, ie: Firmware Version = 3.240.25-2382
                    Status          = $WCS_NOT_AVAILABLE;  # Controller status field, ie: Controller Status = Needs Attention

                    Output          = '';                  # Combined standard output and standard error from StorCli
                }

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Define vars and constants
        #-------------------------------------------------------
        $StdOutBuilder  = New-Object System.Text.StringBuilder(16384)
        $StdErrBuilder  = New-Object System.Text.StringBuilder(1024)

        #-------------------------------------------------------
        # Check if LSI adapter installed
        #-------------------------------------------------------
        $FoundLsi9207 = $false
        $FoundLsi9270 = $false

        Get-WmiObject Win32_ScsiController | ForEach-Object {
                
            If ($_.DeviceId.StartsWith('PCI\VEN_1000&DEV_0087')) { $FoundLsi9207 = $true } 
            If ($_.DeviceId.StartsWith('PCI\VEN_1000&DEV_005B')) { $FoundLsi9270 = $true }       
        }

        #-------------------------------------------------------
        # Get info on 9270 if installed
        #-------------------------------------------------------
        If ($FoundLsi9270)
        {

            $LSI_UTILITY    = "$WCS_BINARY_DIRECTORY\LSI\StorCli64.exe"
            $LSI_ARGS       = '/c0 show all'
            $STDOUT_FILE    = "$WCS_RESULTS_DIRECTORY\StorCli64_Info.out.txt"
            $STDERR_FILE    = "$WCS_RESULTS_DIRECTORY\StorCli64_Info.err.txt"
            #-------------------------------------------------------------------------------------------------
            # If app not installed return 
            #-------------------------------------------------------------------------------------------------
            If (-NOT (Test-Path $LSI_UTILITY))
            {
                Return $LsiInfo
            }
            #-------------------------------------------------------------------------------------------------
            # Delete temp files if exist
            #-------------------------------------------------------------------------------------------------
            Remove-Item $STDOUT_FILE -ErrorAction SilentlyContinue | Out-Null 
            Remove-Item $STDERR_FILE -ErrorAction SilentlyContinue | Out-Null 
 
            #-------------------------------------------------------------------------------------------------
            # Run show all on the C0 adapter looking for a RAID card
            #-------------------------------------------------------------------------------------------------
            $LsiProcess = Start-Process  -RedirectStandardError $STDERR_FILE -RedirectStandardOutput $STDOUT_FILE -FilePath $LSI_UTILITY -ArgumentList $LSI_ARGS -Wait -PassThru -NoNewWindow  
 
            If ($LsiProcess.ExitCode -ne 0)
            {
                Write-Verbose ("{0} {1} returned error code {1}`r" -f  $LSI_UTILITY,$LSI_ARGS,$LsiProcess.ExitCode)
            }
            #-------------------------------------------------------------------------------------------------
            # Parse the output from the utility. Note if adapter not found then these parameters will not 
            # be found and will be returned as Not Available
            #-------------------------------------------------------------------------------------------------
            Get-Content $STDOUT_FILE | ForEach-Object { 

                $Line = $_
                $StdOutBuilder.Append($Line + "`r") | Out-Null

                Switch ($Line.Split('=')[0].Trim())
                {
                    'Model'                    { $LsiInfo.ProductName       = $Line.Split('=')[1].Trim(); break}
                    'Serial Number'            { $LsiInfo.SerialNumber      = $Line.Split('=')[1].Trim(); break}
                    'Firmware Package Build'   { $LsiInfo.PackageVersion    = $Line.Split('=')[1].Trim(); break}
                    'Firmware Version'         { $LsiInfo.FirmwareVersion   = $Line.Split('=')[1].Trim(); break}

                    # Note:  Controller status from LSI needs to be better understood.  Some returning Needs Attention
                    #        ...so for now hard code to OK.
                    #--------------------------------------------------------------------------------------------------
                    'Controller Status'        { $LsiInfo.Status            = 'OK'; break} # $Line.Split('=')[1].Trim(); break}
    
                    default { }     
                } 
            }
            #-------------------------------------------------------------------------------------------------
            # Save the error output
            #-------------------------------------------------------------------------------------------------
            Get-Content $STDERR_FILE | ForEach-Object { 

                $Line = $_
                $StdErrBuilder.Append($Line + "`r") | Out-Null
            }
            #-------------------------------------------------------------------------------------------------
            # Merge standard out and standard error
            #-------------------------------------------------------------------------------------------------
            $LsiInfo.Output  = ("`r`n *** Standard Output for '$LSI_UTILITY $LSI_ARGS'  ***`r`n`r`n{0} " -f $StdOutBuilder.ToString() )
            $LsiInfo.Output += ("`r`n *** Standard Error for '$LSI_UTILITY $LSI_ARGS' ***  `r`n`r`n{0} " -f $StdErrBuilder.ToString() )

            #-------------------------------------------------------------------------------------------------
            # Remove the temp files
            #-------------------------------------------------------------------------------------------------
            Remove-Item $STDOUT_FILE -ErrorAction SilentlyContinue | Out-Null 
            Remove-Item $STDERR_FILE -ErrorAction SilentlyContinue | Out-Null 

        }
        #-------------------------------------------------------------------------------------------------
        # Get info on 9207 if installed
        #-------------------------------------------------------------------------------------------------
        If ($FoundLsi9207)
        {
            $LSI_UTILITY    = "$WCS_BINARY_DIRECTORY\LSI\Sas2Flash.exe"
            $LSI_ARGS       = '-list'
            $STDOUT_FILE    = "$WCS_RESULTS_DIRECTORY\Sas2Flash_Info.out.txt"
            $STDERR_FILE    = "$WCS_RESULTS_DIRECTORY\Sas2Flash_Info.err.txt"
            #-------------------------------------------------------------------------------------------------
            # If app not installed return 
            #-------------------------------------------------------------------------------------------------
            If (-NOT (Test-Path $LSI_UTILITY))
            {
                Return $LsiInfo
            }
            #-------------------------------------------------------------------------------------------------
            # Delete temp files if exist
            #-------------------------------------------------------------------------------------------------
            Remove-Item $STDOUT_FILE -ErrorAction SilentlyContinue | Out-Null 
            Remove-Item $STDERR_FILE -ErrorAction SilentlyContinue | Out-Null 
 
            #-------------------------------------------------------------------------------------------------
            # Run show all on the C0 adapter looking for a RAID card
            #-------------------------------------------------------------------------------------------------
            $LsiProcess = Start-Process  -RedirectStandardError $STDERR_FILE -RedirectStandardOutput $STDOUT_FILE -FilePath $LSI_UTILITY -ArgumentList $LSI_ARGS -Wait -PassThru -NoNewWindow  
 
            If ($LsiProcess.ExitCode -ne 0)
            {
                Write-Verbose ("{0} {1} returned error code {1}`r" -f  $LSI_UTILITY,$LSI_ARGS,$LsiProcess.ExitCode)
            }
            #-------------------------------------------------------------------------------------------------
            # Parse the output from the utility. Note if adapter not found then these parameters will not 
            # be found and will be returned as Not Available
            #-------------------------------------------------------------------------------------------------
            Get-Content $STDOUT_FILE | ForEach-Object { 

                $Line = $_
                $StdOutBuilder.Append($Line + "`r") | Out-Null

                Switch ($Line.Split(':')[0].Trim())
                {
                    'Board Name'               { $LsiInfo.ProductName       = $Line.Split(':')[1].Trim(); break}
                    'Board Tracer Number'      { $LsiInfo.SerialNumber      = $Line.Split(':')[1].Trim(); break}
                    'Firmware Version'         { $LsiInfo.FirmwareVersion   = $Line.Split(':')[1].Trim(); break}

                    'Controller Status'        { $LsiInfo.Status            = 'OK'; break} # $Line.Split('=')[1].Trim(); break}
    
                    default { }     
                } 
            }
            #-------------------------------------------------------------------------------------------------
            # Save the error output
            #-------------------------------------------------------------------------------------------------
            Get-Content $STDERR_FILE | ForEach-Object { 

                $Line = $_
                $StdErrBuilder.Append($Line + "`r") | Out-Null
            }
            #-------------------------------------------------------------------------------------------------
            # Merge standard out and standard error
            #-------------------------------------------------------------------------------------------------
            $LsiInfo.Output  = ("`r`n *** Standard Output for '$LSI_UTILITY $LSI_ARGS'  ***`r`n`r`n{0} " -f $StdOutBuilder.ToString() )
            $LsiInfo.Output += ("`r`n *** Standard Error for '$LSI_UTILITY $LSI_ARGS' ***  `r`n`r`n{0} " -f $StdErrBuilder.ToString() )

            #-------------------------------------------------------------------------------------------------
            # Remove the temp files
            #-------------------------------------------------------------------------------------------------
            Remove-Item $STDOUT_FILE -ErrorAction SilentlyContinue | Out-Null 
            Remove-Item $STDERR_FILE -ErrorAction SilentlyContinue | Out-Null 
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

    Return $LsiInfo
}

#-------------------------------------------------------------------------------------------------
# Gets the phsycial disk info from a LSI adapter 
#-------------------------------------------------------------------------------------------------
#  -  Uses StorCli64.exe
#  -  Assumes no more than one adapter
#  -  Supported adapters 9270 and 9207
#-------------------------------------------------------------------------------------------------
Function Get-LsiDiskInfo()
{
    
    [CmdletBinding()]
    Param()

    $LsiInfo = @{           Disks           = $null;               # Array of LSI disk info objects
                            Output          = "";                  # Standard output and error from StorCli
                }

    $LsiDiskInfo    = @{    EnclosureId      = $WCS_NOT_AVAILABLE; 
                            SlotId           = $WCS_NOT_AVAILABLE; 
                            DeviceId         = $WCS_NOT_AVAILABLE;

                            InterfaceType    = 'SCSI';
                            MediaType        = 'Fixed Hard Disk Media';
                            Status           = 'OK';

                            SerialNumber     = $WCS_NOT_AVAILABLE; 
                            FirmwareRevision = $WCS_NOT_AVAILABLE; 
                            Model            = $WCS_NOT_AVAILABLE;
                            SmartAlert       = $WCS_NOT_AVAILABLE;
                            Sectors          = $WCS_NOT_AVAILABLE;
                            SectorSize       = $WCS_NOT_AVAILABLE;                                                
                            Size             = $WCS_NOT_AVAILABLE;                    
                            LinkSpeed        = $WCS_NOT_AVAILABLE; 
                        }

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Check if LSI adapter installed
        #-------------------------------------------------------
        $FoundLsi9270 = $false

        Get-WmiObject Win32_ScsiController | ForEach-Object {
                
            If ($_.DeviceId.StartsWith('PCI\VEN_1000&DEV_005B')) { $FoundLsi9270 = $true }       
        }

        If (-NOT $FoundLsi9270) { Return $LsiInfo }

        #-------------------------------------------------------
        # Define vars and constants
        #-------------------------------------------------------
        $NO_DISKS       = -1
        $CurrentDisk    = $NO_DISKS

        $StdOutBuilder  = New-Object System.Text.StringBuilder(65536)
        $StdErrBuilder  = New-Object System.Text.StringBuilder(1024)

        $LSI_UTILITY    = "$WCS_BINARY_DIRECTORY\LSI\StorCli64.exe"
        $LSI_ARGS       = '/c0/eall/sall show all'
        $STDOUT_FILE    = "$WCS_RESULTS_DIRECTORY\StorCli64_pdlist.out.txt"
        $STDERR_FILE    = "$WCS_RESULTS_DIRECTORY\StorCli64_pdlist.err.txt"
        #-------------------------------------------------------------------------------------------------
        # If app not installed return 
        #-------------------------------------------------------------------------------------------------
        If (-NOT (Test-Path $LSI_UTILITY))
        {
             Return $LsiInfo
        }
        #-------------------------------------------------------------------------------------------------
        # Delete temp files if exist
        #-------------------------------------------------------------------------------------------------
        Remove-Item $STDOUT_FILE -ErrorAction SilentlyContinue | Out-Null 
        Remove-Item $STDERR_FILE -ErrorAction SilentlyContinue | Out-Null 

        #-------------------------------------------------------------------------------------------------
        # Run show all on the C0 adapter
        #-------------------------------------------------------------------------------------------------
        $LsiProcess = Start-Process  -RedirectStandardError $STDERR_FILE -RedirectStandardOutput $STDOUT_FILE -FilePath $LSI_UTILITY -ArgumentList $LSI_ARGS -Wait -PassThru -NoNewWindow  

        If ($LsiProcess.ExitCode -ne 0)
        {
            Write-Verbose ("{0} {1} returned error code {1}`r" -f  $LSI_UTILITY,$LSI_ARGS,$LsiProcess.ExitCode)
        }
        #-----------------------------------------------------------------------------------------------------
        # Read output from the file and parse data
        #-----------------------------------------------------------------------------------------------------
        Get-Content $STDOUT_FILE | ForEach-Object { 

            $Line = $_
            $StdOutBuilder.Append($Line + "`r") | Out-Null

            If ($Line.Split()[0] -eq 'Drive' -and $Line.Split()[1].StartsWith('/c0') -and $Line.Split()[2] -eq ':')
            {
                If ($CurrentDisk -eq $NO_DISKS)  { $LsiInfo.Disks   = @( $LsiDiskInfo.Clone()) ; $CurrentDisk = 0}
                Else                             { $LsiInfo.Disks  += $LsiDiskInfo.Clone()     ; $CurrentDisk++ }         
          
                $LsiInfo.Disks[$CurrentDisk].EnclosureId =  $Line.Split()[1].Split('/')[2].TrimStart('e')
                $LsiInfo.Disks[$CurrentDisk].SlotId      =  $Line.Split()[1].Split('/')[3].TrimStart('s')

                $LsiInfo.Disks[$CurrentDisk].DeviceId    = ("LsiDisk{0}" -f $CurrentDisk)
            }

            If ($CurrentDisk -ne $NO_DISKS)
            {
                Switch ($Line.Split('=')[0].Trim())
                {
                    'SN'                                        { $LsiInfo.Disks[$CurrentDisk].SerialNumber     = $Line.Split('=')[1].Trim(); break}
                    'Firmware Revision'                         { $LsiInfo.Disks[$CurrentDisk].FirmwareRevision = $Line.Split('=')[1].Trim(); break}
                    'Model Number'                              { $LsiInfo.Disks[$CurrentDisk].Model            = $Line.Split('=')[1].Trim(); break}
                    'S.M.A.R.T alert flagged by drive'          { $LsiInfo.Disks[$CurrentDisk].SmartAlert       = $Line.Split('=')[1].Trim().ToUpper(); break}
                    'Raw size'                                  { $LsiInfo.Disks[$CurrentDisk].Sectors          = ($Line.Split('=')[1].Trim() -split '\s+').split()[2].Trim('['); break}
                    'Logical Sector Size'                       { $LsiInfo.Disks[$CurrentDisk].SectorSize       = $Line.Split('=')[1].Trim().ToUpper(); break}
                    'Link Speed'                                { $LsiInfo.Disks[$CurrentDisk].LinkSpeed        = $Line.Split('=')[1].Trim(); break}

                    default { }      
                }
            } 
        }
        #-----------------------------------------------------------------------------------------------------
        # Compute the disk size and status
        #-----------------------------------------------------------------------------------------------------
        $LsiInfo.Disks | Where { $_ -ne $null} | ForEach-Object { 
        
            If (($_.Sectors -ne $WCS_NOT_AVAILABLE) -and ($_.SectorSize -ne $WCS_NOT_AVAILABLE))
            {

                If     ($_.SectorSize.Contains("KB")) { $_.SectorSize = ([int] ($_.SectorSize.Replace("KB","").Trim())) * 1024 }
                ElseIf ($_.SectorSize.Contains("B"))  { $_.SectorSize = ([int] ($_.SectorSize.Replace("B","").Trim()))         }

                $_.Size       = [int64] $_.SectorSize * [int64] $_.Sectors 
            }
            If ($_.SmartAlert -ne 'NO') { $_.Status = 'Pred Fail' }

        }
        #-------------------------------------------------------------------------------------------------
        # Save the error output
        #-------------------------------------------------------------------------------------------------
        Get-Content $STDERR_FILE | ForEach-Object { 

            $Line = $_
            $StdErrBuilder.Append($Line + "`r") | Out-Null
        }
        #-------------------------------------------------------------------------------------------------
        # Merge standard out and standard error
        #-------------------------------------------------------------------------------------------------
        $LsiInfo.Output  = ("`r`n *** Standard Output for '$LSI_UTILITY $LSI_ARGS'  ***`r`n`r`n{0} " -f $StdOutBuilder.ToString() )
        $LsiInfo.Output += ("`r`n *** Standard Error for '$LSI_UTILITY $LSI_ARGS' ***`r`n`r`n{0} "  -f $StdErrBuilder.ToString() )

        #-------------------------------------------------------------------------------------------------
        # Remove the temp files
        #-------------------------------------------------------------------------------------------------
        Remove-Item $STDOUT_FILE -ErrorAction SilentlyContinue | Out-Null 
        Remove-Item $STDERR_FILE -ErrorAction SilentlyContinue | Out-Null 
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
    
    Return $LsiInfo 
}
#-------------------------------------------------------------------------------------------------
# Flushes the LSI RAID adapter cache 
#-------------------------------------------------------------------------------------------------
Function Flush-LsiRaidCache()
{
    [CmdletBinding()]
    Param()

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Define vars and constants
        #-------------------------------------------------------
        $LSI_UTILITY    = "$WCS_BINARY_DIRECTORY\LSI\StorCli64.exe"
        $LSI_ARGS       = '/c0 flushcache'

        #-------------------------------------------------------------------------------------------------
        # Flush the cache
        #-------------------------------------------------------------------------------------------------
        $LsiProcess = Start-Process -FilePath $LSI_UTILITY -ArgumentList $LSI_ARGS -Wait -PassThru 

        If ($LsiProcess.ExitCode -ne 0)
        {
            Throw ("{0} {1} returned error code {1}`r" -f  $LSI_UTILITY,$LSI_ARGS,$LsiProcess.ExitCode)
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