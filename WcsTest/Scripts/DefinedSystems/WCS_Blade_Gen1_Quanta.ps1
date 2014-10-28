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

 
#-----------------------------------------------------------------------------------------------------------------------
# This file defines functions specific to the Quanta Mt Rainier compute blade for WCS that allow:
#
#  1. Decoding system specific SEL entries
#  2. Displaying physical location of components
#
#-----------------------------------------------------------------------------------------------------------------------
$SystemDefined_EventErrors = $null

#-----------------------------------------------------------------------------------------------------------------------
# Helper function that converts DIMM number to location
#-----------------------------------------------------------------------------------------------------------------------
# Mt Rainier has 12 DIMMS.  This maps DIMM number to physical location.  It also maps the device locator property
# from Win32_PhysicalMemory to physical location because it does not match the board silkscreen.
#-----------------------------------------------------------------------------------------------------------------------
Function DefinedSystem_GetDimmLocation()
{   
    Param( [Parameter(Mandatory=$true)] $DimmId )

    Switch($DimmId)
    {
         1 { Write-Output 'DIMM A1'; break }
         2 { Write-Output 'DIMM A2'; break }
         3 { Write-Output 'DIMM B1'; break }
         4 { Write-Output 'DIMM B2'; break }
         5 { Write-Output 'DIMM C1'; break }
         6 { Write-Output 'DIMM C2'; break }
         7 { Write-Output 'DIMM D1'; break }
         8 { Write-Output 'DIMM D2'; break }
         9 { Write-Output 'DIMM E1'; break }
        10 { Write-Output 'DIMM E2'; break }
        11 { Write-Output 'DIMM F1'; break }
        12 { Write-Output 'DIMM F2'; break }

        CHANNELA_DIMM1 { Write-Output 'DIMM A1'; break }
        CHANNELA_DIMM2 { Write-Output 'DIMM A2'; break }
        CHANNELB_DIMM1 { Write-Output 'DIMM B1'; break }
        CHANNELB_DIMM2 { Write-Output 'DIMM B2'; break }
        CHANNELC_DIMM1 { Write-Output 'DIMM C1'; break }
        CHANNELC_DIMM2 { Write-Output 'DIMM C2'; break }
        CHANNELD_DIMM1 { Write-Output 'DIMM D1'; break }
        CHANNELD_DIMM2 { Write-Output 'DIMM D2'; break }
        CHANNELE_DIMM1 { Write-Output 'DIMM E1'; break }
        CHANNELE_DIMM2 { Write-Output 'DIMM E2'; break }
        CHANNELF_DIMM1 { Write-Output 'DIMM F1'; break }
        CHANNELF_DIMM2 { Write-Output 'DIMM F2'; break }

        Default        { Write-Output 'DIMM N/A'; break }
    }
}
#-----------------------------------------------------------------------------------------------------------------------
# Decode of Mt Rainier specific SEL entries.  Refer to the Mt Rainier BIOS and BMC specifications for details
#-----------------------------------------------------------------------------------------------------------------------
Function DefinedSystem_DecodeSelEntry() 
{
    Param
    ( 
        [Parameter(Mandatory=$true)]  [ref] $SelEntry,
        [Parameter(Mandatory=$false)]       $LastSelEntry=$null
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        $SelEntry.Value.Decode   =  ("{0} {1} " -f $SelEntry.Value.RecordId, $SelEntry.Value.TimeStampDecoded)
        $SelEntry.Value.Event         = ''
        #----------------------------------------------------
        # Decode sensor record type
        #----------------------------------------------------
        If ($SelEntry.Value.RecordType -eq 0x02)
        {
            #----------------------------------------------------
            # Then decode by sensor type
            #----------------------------------------------------
            Switch ($SelEntry.Value.SensorType)
            {
                #----------------------------------------------------
                # Sensor Type 07h - Processor Sensor
                #----------------------------------------------------
                0x07
                {
                    $SelEntry.Value.HardwareError = $true
                                     
                    Switch ($SelEntry.Value.Sensor)
                    {
                        0xD3 
                        { 
                            $SelEntry.Value.Location = 'Processor 0' 
                            $SelEntry.Value.Event    = 'Thermal Trip'
                            break 
                        }
                        0xD4  
                        { 
                            $SelEntry.Value.Location = 'Processor 1' 
                            $SelEntry.Value.Event    = 'Thermal Trip'
                            break 
                        }
                        0xD5
                        { 
                            $SelEntry.Value.Location = 'Processor' 
                            $SelEntry.Value.Event    = 'IERR'
                            break 
                        }                        
                        0xA7 
                        { 
                            $SelEntry.Value.Location = ("Processor {0}" -f (($SelEntry.Value.EventData3 -band 0xE) -shr 5)) 
                            $SelEntry.Value.Event    = 'IIO Error'                            
                            break 
                        }   
                        #-----------------------------------------------------------
                        # QPI error
                        #-----------------------------------------------------------
                        0x9D 
                        { 
                            #-----------------------------------------------------------
                            # Using the location defined in WCS-Softwarse-Blade-API.doc
                            #-----------------------------------------------------------
                            Switch (($SelEntry.Value.EventData3 -band 0x0F))
                            {
                                1       { $SelEntry.Value.Location   = 'Processor 0'    ; break }
                                2       { $SelEntry.Value.Location   = 'Processor 1'    ; break } 
                                4       { $SelEntry.Value.Location   = 'Processor 2'    ; break } 
                                8       { $SelEntry.Value.Location   = 'Processor 3'    ; break } 
                                Default { $SelEntry.Value.Location   = 'Processor'      ; break } 
                            }    
                                                            
                            If (($SelEntry.Value.EventData3 -band 0x10) -eq 0) { $SelEntry.Value.Event = 'QPI 0 ' }
                            Else                                               { $SelEntry.Value.Event = 'QPI 1 ' }
                            #-----------------------------------------------------------
                            # Correctable/Uncorrectable defined in IPMI
                            #-----------------------------------------------------------
                            If   (($SelEntry.Value.EventData1 -band 0x0F) -eq 0x0B) { $SelEntry.Value.Event += 'Uncorrectable Error'  }
                            Else                                                    { $SelEntry.Value.Event += 'Correctable Error'    }                          
                            break 
                        }                                             
                        Default 
                        { 
                            $SelEntry.Value.Location = 'Processor' 

                            #-----------------------------------------------------------
                            # From IPMI v2.0 for generic processor
                            #-----------------------------------------------------------
                            Switch (($SelEntry.Value.EventData1 -band 0x0F))
                            {
                                0       { $SelEntry.Value.Event   = 'IERR'         ; break }
                                1       { $SelEntry.Value.Event   = 'Thermal Trip' ; break } 
                                2       { $SelEntry.Value.Event   = 'FRB1'         ; break } 
                                3       { $SelEntry.Value.Event   = 'FRB2'         ; break } 
                                4       { $SelEntry.Value.Event   = 'FRB3'         ; break } 
                                5       { $SelEntry.Value.Event   = 'Configuration Error'         ; break } 
                                6       { $SelEntry.Value.Event   = 'SMBIOS Uncorrectable Error'   ; break } 
                                7       { $SelEntry.Value.Event   = 'Presence detected'            ; $SelEntry.Value.HardwareError = $false ; break } 
                                8       { $SelEntry.Value.Event   = 'Processor disabled'           ; break } 
                                9       { $SelEntry.Value.Event   = 'Terminator presence detected' ; $SelEntry.Value.HardwareError = $false ; break } 
                                0xA     { $SelEntry.Value.Event   = 'Automatically Throttled'      ; break } 
                                0xB     { $SelEntry.Value.Event   = 'Uncorrectable machine check'  ; break } 
                                0xC     { $SelEntry.Value.Event   = 'Correctable machine check'    ; break } 

                                Default { $SelEntry.Value.Event   = 'Processor event' }
                            }                              
                        }
                    }              
                    $SelEntry.Value.Decode   += ("{0} {1} Sensor {2:X2} EvtData(3-1) 0x{3:X2}{4:X2}{5:X2}" -f $SelEntry.Value.Location,$SelEntry.Value.Event,$SelEntry.Value.Sensor,$SelEntry.Value.EventData1,$SelEntry.Value.EventData2, $SelEntry.Value.EventData3)                     
                }
                #----------------------------------------------------
                # Sensor Type 0Ch - Memory Sensor
                #----------------------------------------------------
                0x0C
                {
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      =  (DefinedSystem_GetDimmLocation $SelEntry.Value.EventData3)

                    Switch (($SelEntry.Value.EventData1 -band 0x0F))
                    {
                        0x0       { $SelEntry.Value.Event   = 'Correctable ECC'               ; break }
                        0x1       { $SelEntry.Value.Event   = 'Uncorrectable ECC'             ; break } 
                        0x5       { $SelEntry.Value.Event   = 'Correctable ECC Limit Reached' ; break } 
                        Default   { $SelEntry.Value.Event   = 'Memory event' }
                    }
                    $SelEntry.Value.Decode   += ("{0} {1}" -f $SelEntry.Value.Location,$SelEntry.Value.Event) 
                }    
                #----------------------------------------------------
                # Sensor Type 13h - Critical Interrupt sensor Type
                #----------------------------------------------------
                0x13
                {
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'BOARD/ADAPTER'
                    
                    If ( $SelEntry.Value.Sensor -eq 0xA1)
                    {

                        If (($LastSelEntry -ne $NULL) -and ($LastSelEntry.Sensor -eq 0xA1) -and ($LastSelEntry.SensorType -eq 0x13))
                        {
                            $SelEntry.Value.Event   = 'PCIe Error (2/3)' 

                            $SelEntry.Value.Decode  += ("{0} {1} First Error:0x{2:X2} Second Error:0x{3:X2}" -f $SelEntry.Value.Location,$SelEntry.Value.Event,$SelEntry.Value.EventData3, (($SelEntry.Value.EventData2 -band 0xF8) -shr 3), ($SelEntry.Value.EventData2 -band 0x7))
                        }
                        Else
                        {
                            Switch (($SelEntry.Value.EventData1 -band 0x0F))
                            {
                                0x5       { $SelEntry.Value.Event   = 'PCI PERR'                 ; break }
                                0x5       { $SelEntry.Value.Event   = 'PCI SERR'                 ; break } 
                                0x7       { $SelEntry.Value.Event   = 'Correctable bus error'    ; break } 
                                0x8       { $SelEntry.Value.Event   = 'Uncorrectable bus error'  ; break } 
                                0xA       { $SelEntry.Value.Event   = 'Fatal bus error'          ; break } 
                                Default   { $SelEntry.Value.Event   = 'Critical interrupt' }
                            }

                            $SelEntry.Value.Decode  += ("{0} PCIe Error (1/3) {1} PCI Bus:{2} Dev:{3} Fun:{4}" -f $SelEntry.Value.Location,$SelEntry.Value.Event,$SelEntry.Value.EventData3, (($SelEntry.Value.EventData2 -band 0xF8) -shr 3), ($SelEntry.Value.EventData2 -band 0x7))
                        }
                    }
                    Else
                    {
                        IpmiLib_DecodeSelEntry  $SelEntry
                    }
                    Break
                }
                #----------------------------------------------------
                # Decode all other sensor types
                #----------------------------------------------------            
                Default
                {
                    IpmiLib_DecodeSelEntry  $SelEntry 
                }
            }
        }
        #----------------------------------------------------
        # Decode OEM timestamp record type
        #----------------------------------------------------
        ElseIf (($SelEntry.Value.RecordType -eq 0xC0) -and  ($SelEntry.Value.ManufacturerId -eq 0x1C4C))
        {
            $VID         =   [uint16] ("0x{0}" -f $SelEntry.Value.OemTimestampRecord.Substring( ($SelEntry.Value.OemTimestampRecord.Length - 4),4))
            $DID         =   [uint16] ("0x{0}" -f $SelEntry.Value.OemTimestampRecord.Substring( ($SelEntry.Value.OemTimestampRecord.Length - 8),4))

            $SelEntry.Value.Event         = 'PCIe Error (3/3)'
            $SelEntry.Value.HardwareError = $true

            If ($VID -eq $LSI_VENDOR_ID)
            {
                $SelEntry.Value.Location  = 'HBA ADAPTER'
            }
            ElseIf ($VID -eq $MELLANOX_VENDOR_ID)
            {
                $SelEntry.Value.Location  = 'NIC ADAPTER'
            }
            Else
            {
                $SelEntry.Value.Location  = 'BOARD'
            }

            $SelEntry.Value.Decode  += ("{0} {1} VID: {2:X4} DID: {3:X4} " -f $SelEntry.Value.Location,$SelEntry.Value.Event,$VID,$DID)
        }

        #----------------------------------------------------
        # Use generic decode for all others
        #----------------------------------------------------
        Else
        {
            IpmiLib_DecodeSelEntry  ($SelEntry) 
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
# Helper function that gets disk location
#-------------------------------------------------------------------------------------
# Mt Rainier has 4 HDD on server blade and 10 more on JBOD.  Must check if using an
# LSI adapter to determine the drive location.
#-------------------------------------------------------------------------------------
Function DefinedSystem_GetDiskLocation()
{
    Param
    (
        [Parameter(Mandatory=$true)]                       $DiskInfo,
        [Parameter(Mandatory=$true)]                       $EnclosureId,
        [Parameter(Mandatory=$true)]                       $SlotId
    )

    Try
    {
        $LabelLocation  = $DiskInfo.DeviceId

        #--------------------------------------------------------------------------------------------------------------------------
        # If Azure 3.1 Configuration
        #--------------------------------------------------------------------------------------------------------------------------
        If ((Get-WmiObject Win32_ComputerSystem).Model -eq 'C1020')
        {
            #--------------------------------------------------------------------------------------------------------------------------
            # Has 2 SSD connected to PCH on top of SSD4 and SSD2
            #--------------------------------------------------------------------------------------------------------------------------
            If ($DiskInfo.InterfaceType -eq "IDE")
            {
                Switch($DiskInfo.SCSIBus)
                {
                    0 { $LabelLocation = "SB-4-Top" ; break}
                    1 { $LabelLocation = "SB-2-Top" ; break}
                    default  {break}
                }
            }
            #--------------------------------------------------------------------------------------------------------------------------
            # Has 3 SSD and 1 HDD connected to LSI 9207
            #--------------------------------------------------------------------------------------------------------------------------
            Else
            {
                Switch($DiskInfo.SCSITargetId)
                {
                    0 { $LabelLocation = "SB-5" ; break}
                    1 { $LabelLocation = "SB-4" ; break}
                    2 { $LabelLocation = "SB-3" ; break}
                    3 { $LabelLocation = "SB-2" ; break}
                    default  {break}
                }

            }
        }
        #--------------------------------------------------------------------------------------------------------------------------
        # Else Exchange Configuration
        #--------------------------------------------------------------------------------------------------------------------------
        Else
        {
            #--------------------------------------------------------------------------------------------------------------------------
            # If IDE interface then connected directory to PCH and SCSIBus is the same as SATA port # which is same as the label #
            #--------------------------------------------------------------------------------------------------------------------------
            If ($DiskInfo.InterfaceType -eq "IDE")
            {
                Return ("SB-{0}" -f $DiskInfo.SCSIBus)             
            }
            #--------------------------------------------------------------------------------------------------------------------------
            # If SCSI interface and have LSI disk info then lookup the label location based on enclosure/slot IDs
            #--------------------------------------------------------------------------------------------------------------------------
            ElseIf ($DiskInfo.InterfaceType -eq "SCSI")
            {                
                # Map enclosure/slot ID to labels - For Mt Rainier/LSI 9270 only
                #----------------------------------------------------------------
                If ($EnclosureId -eq 252)
                {
                    Switch($SlotId)
                    {
                        0 { $LabelLocation = "SB-2" ; break}
                        1 { $LabelLocation = "SB-3" ; break}
                        2 { $LabelLocation = "SB-4" ; break}
                        3 { $LabelLocation = "SB-5" ; break}
                        default  {break}
                    }

                }
                ElseIf (($EnclosureId -ne 0) -and ($EnclosureId -ne $WCS_NOT_AVAILABLE))
                {
                    $LabelLocation = ("DB-{0}" -f $SlotId) 
                }    
            }
        }        
        Return $LabelLocation        

    }
    Catch
    {
        Return $LabelLocation
    }
}
#-----------------------------------------------------------------------------------------------------------------------
# Helper function that gets the base FRU inforamtion
#-----------------------------------------------------------------------------------------------------------------------
Function DefinedSystem_GetFruInformation()
{   
    $Model = (Get-WmiObject Win32_ComputerSystem).Model # Either C1000 or C1020

    If ($Model -eq 'C1020')
    {
        Write-Output (Get-WcsFru -File 'Fru_v0.03'  -LogDirectory "$WCS_REF_DIRECTORY\FruTemplates" )
    } 
    Else
    {
        Write-Output (Get-WcsFru -File 'Fru_v0.02'  -LogDirectory "$WCS_REF_DIRECTORY\FruTemplates" )
    }

}