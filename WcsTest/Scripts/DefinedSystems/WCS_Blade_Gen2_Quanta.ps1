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
# This file defines functions specific to the Quanta Mt Hood compute blade for WCS that allow:
#
#  1. Decoding system specific SEL entries
#  2. Displaying physical location of components
#
#-----------------------------------------------------------------------------------------------------------------------
$SystemDefined_EventErrors = $null

#-----------------------------------------------------------------------------------------------------------------------
# Helper function that converts DIMM number to location
#
# Mt Hood has 16 DIMMs that are mapped as shown below
#-----------------------------------------------------------------------------------------------------------------------
Function DefinedSystem_GetDimmLocation()
{   
    Param( [Parameter(Mandatory=$true)]   $DimmId )

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
        13 { Write-Output 'DIMM G1'; break }
        14 { Write-Output 'DIMM G2'; break }
        15 { Write-Output 'DIMM H1'; break }
        16 { Write-Output 'DIMM H2'; break }

         'DIMM_A1' { Write-Output 'DIMM A1'; break }
         'DIMM_A2' { Write-Output 'DIMM A2'; break }
         'DIMM_B1' { Write-Output 'DIMM B1'; break }
         'DIMM_B2' { Write-Output 'DIMM B2'; break }
         'DIMM_C1' { Write-Output 'DIMM C1'; break }
         'DIMM_C2' { Write-Output 'DIMM C2'; break }
         'DIMM_D1' { Write-Output 'DIMM D1'; break }
         'DIMM_D2' { Write-Output 'DIMM D2'; break }
         'DIMM_E1' { Write-Output 'DIMM E1'; break }
         'DIMM_E2' { Write-Output 'DIMM E2'; break }
         'DIMM_F1' { Write-Output 'DIMM F1'; break }
         'DIMM_F2' { Write-Output 'DIMM F2'; break }
         'DIMM_G1' { Write-Output 'DIMM G1'; break }
         'DIMM_G2' { Write-Output 'DIMM G2'; break }
         'DIMM_H1' { Write-Output 'DIMM H1'; break }
         'DIMM_H2' { Write-Output 'DIMM H2'; break }

        Default        { Write-Output 'DIMM N/A'; break }
    }
}
#-----------------------------------------------------------------------------------------------------------------------
# Decode of Mt Hood specific SEL entries.  Refer to the Mt Hood BIOS and BMC specifications for details
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
                        0x1C 
                        { 
                            $SelEntry.Value.Location = 'Processor 0' 
                            Switch ($SelEntry.Value.EventData1)
                            {
                                0x0     { $SelEntry.Value.Event = 'CPU Critical Temperature' ;break}
                                0x1     { $SelEntry.Value.Event = 'PROCHOT# Assertion'       ;break}
                                0x2     { $SelEntry.Value.Event = 'TCC Activation'           ;break}
                                Default { $SelEntry.Value.Event = 'Processor event' }
                            }
                        }
                        0x1D  
                        { 
                            $SelEntry.Value.Location = 'Processor 1' 
                            Switch ($SelEntry.Value.EventData1)
                            {
                                0x0     { $SelEntry.Value.Event = 'CPU Critical Temperature' ;break}
                                0x1     { $SelEntry.Value.Event = 'PROCHOT# Assertion'       ;break}
                                0x2     { $SelEntry.Value.Event = 'TCC Activation'           ;break}
                                Default { $SelEntry.Value.Event = 'Processor event' }
                            }
                        }
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
                    $SelEntry.Value.Decode   += ("{0} {1} Sensor {2:X2} EvtData(3-1) 0x{3:X2}{4:X2}{5:X2}" -f $SelEntry.Value.Location ,$SelEntry.Value.Event,$SelEntry.Value.Sensor,$SelEntry.Value.EventData1,`                                                                                                         $SelEntry.Value.EventData2, $SelEntry.Value.EventData3)                     
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
                        Default    { $SelEntry.Value.Event   = 'Memory event' }
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
            $DID         =   [uint16]  ("0x{0}" -f $SelEntry.Value.OemTimestampRecord.Substring( ($SelEntry.Value.OemTimestampRecord.Length - 8),4))

            $SelEntry.Value.HardwareError = $true
            $SelEntry.Value.Event = 'PCIe Error (3/3)'

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
# Gets the physical drive location
#-------------------------------------------------------------------------------------
Function DefinedSystem_GetDiskLocation()
{
    Param
    (
        [Parameter(Mandatory=$true)]  $DiskInfo,
        [Parameter(Mandatory=$true)]  $EnclosureId,
        [Parameter(Mandatory=$true)]  $SlotId
    )

    Try
    {
        $LabelLocation  = $DiskInfo.DeviceId
        #--------------------------------------------------------------------------------------------------------------------------
        # If IDE interface then connected directory to PCH and SCSIBus is the same as SATA port # which is same as the label #
        #--------------------------------------------------------------------------------------------------------------------------
        If ($DiskInfo.InterfaceType -eq "IDE")
        {
            If ($DiskInfo.ScsiPort -eq "0")
            {
                Return ("SB-{0}" -f $DiskInfo.SCSIBus)   
            }
            Else
            {
                Return ("SB-SSD{0}" -f $DiskInfo.SCSIBus)
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
    Write-Output (Get-WcsFru -File 'Fru_v0.04'  -LogDirectory "$WCS_REF_DIRECTORY\FruTemplates" )
}