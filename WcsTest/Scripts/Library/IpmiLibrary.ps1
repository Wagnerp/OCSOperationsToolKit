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
# FRU Constants
#-----------------------------------------------------------------------------------------------------------------------
Set-Variable  -Name WCS_BLADE_FRU_READ_SIZE    -Value  16  -Option ReadOnly -Force
Set-Variable  -Name WCS_BLADE_FRU_WRITE_SIZE   -Value  8   -Option ReadOnly -Force
Set-Variable  -Name WCS_ALLOWED_FRU_RETRIES    -Value  3   -Option ReadOnly -Force

  
#-------------------------------------------------------------------
#  Define IPMI Constants
#-------------------------------------------------------------------
Set-Variable  -Name WCS_CHASSIS_NETFN        -Value  ([byte] 0x00) -Option ReadOnly -Force
Set-Variable  -Name WCS_BRIDGE_NETFN         -Value  ([byte] 0x02) -Option ReadOnly -Force
Set-Variable  -Name WCS_SENSOR_NETFN         -Value  ([byte] 0x04) -Option ReadOnly -Force
Set-Variable  -Name WCS_APP_NETFN            -Value  ([byte] 0x06) -Option ReadOnly -Force
Set-Variable  -Name WCS_FW_NETFN             -Value  ([byte] 0x08) -Option ReadOnly -Force
Set-Variable  -Name WCS_STORAGE_NETFN        -Value  ([byte] 0x0A) -Option ReadOnly -Force
Set-Variable  -Name WCS_TRANSPORT_NETFN      -Value  ([byte] 0x0C) -Option ReadOnly -Force
Set-Variable  -Name WCS_OEM_NETFN            -Value  ([byte] 0x30) -Option ReadOnly -Force

Set-Variable  -Name  IPMI_COMPLETION_CODE_NORMAL -Value ([byte] 0) -Option ReadOnly -Force

#-----------------------------------------------------------------------------------------------------------------------
# SEL Constants
#-----------------------------------------------------------------------------------------------------------------------
Set-Variable  -Name SEL_ENTRY  -Value    @{ RecordId                = $WCS_NOT_AVAILABLE;
                                            RecordType              = $WCS_NOT_AVAILABLE;
                                            TimeStamp               = $WCS_NOT_AVAILABLE;
                                            TimeStampDecoded        = $WCS_NOT_AVAILABLE;
                                            GeneratorId             = $WCS_NOT_AVAILABLE;
                                            ManufacturerId          = $WCS_NOT_AVAILABLE;
                                            EventMessageVersion     = $WCS_NOT_AVAILABLE;
                                            OemNonTimestampRecord   = $WCS_NOT_AVAILABLE;
                                            OemTimestampRecord      = $WCS_NOT_AVAILABLE;
                                            SensorType              = $WCS_NOT_AVAILABLE;
                                            Sensor                  = $WCS_NOT_AVAILABLE;
                                            EventDirType            = $WCS_NOT_AVAILABLE;
                                            EventData1              = $WCS_NOT_AVAILABLE;
                                            EventData2              = $WCS_NOT_AVAILABLE;
                                            EventData3              = $WCS_NOT_AVAILABLE;
                                            Location                = $WCS_NOT_AVAILABLE;
                                            Event                   = '';
                                            
                                            NoDecode                = '';
                                            Decode                  = '';

                                            HardwareError           = $false;
                                         } -Option ReadOnly -Force


#-------------------------------------------------------------------
#  Define IPMI Globals (used to speed up multiple IPMI accesses)
#-------------------------------------------------------------------
$Global:CimSession    = $null
$Global:IpmiInstance  = $null

#----------------------------------------------------------------------------------------------
# Helper function that decodes completion code byte into readable string format
#
# Refer to Completion Codes in the IPMI V2.0 specification for details
#----------------------------------------------------------------------------------------------
Function IpmiLib_DecodeCompletionCode([byte] $CompletionCode)
{   
    If ($CompletionCode -eq 0)       { Write-Output 'Command completed normally' ; Return }
    If ($CompletionCode -eq 0xC0)    { Write-Output 'Node busy' ; Return }
    If ($CompletionCode -eq 0xC1)    { Write-Output 'Invalid command' ; Return }
    If ($CompletionCode -eq 0xC2)    { Write-Output 'Invalid command for given LUN' ; Return }
    If ($CompletionCode -eq 0xC3)    { Write-Output 'Timeout'   ; Return }
    If ($CompletionCode -eq 0xC4)    { Write-Output 'Out of space' ; Return }
    If ($CompletionCode -eq 0xC5)    { Write-Output 'Invalid or cancelled reservation ID' ; Return }
    If ($CompletionCode -eq 0xC6)    { Write-Output 'Request data truncated' ; Return }
    If ($CompletionCode -eq 0xC7)    { Write-Output 'Request data length invalid' ; Return }
    If ($CompletionCode -eq 0xC8)    { Write-Output 'Request data field length limit exceeded' ; Return }
    If ($CompletionCode -eq 0xC9)    { Write-Output 'Parameter out of range' ; Return }
    If ($CompletionCode -eq 0xCA)    { Write-Output 'Cannot return number of requested bytes' ; Return }
    If ($CompletionCode -eq 0xCB)    { Write-Output 'Requested sensor, data, or record not present' ; Return }
    If ($CompletionCode -eq 0xCC)    { Write-Output 'Invalid data field in request' ; Return }
    If ($CompletionCode -eq 0xCD)    { Write-Output 'Command illegal for specified sensor or record type' ; Return }
    If ($CompletionCode -eq 0xCE)    { Write-Output 'Command response could not be provided' ; Return }
    If ($CompletionCode -eq 0xCF)    { Write-Output 'Cannot execute duplicate request' ; Return }

    If ($CompletionCode -eq 0xD0)    { Write-Output 'Response not provided. SDR repository in update mode' ; Return }
    If ($CompletionCode -eq 0xD1)    { Write-Output 'Response not provided.  Device in firmware update mode' ; Return }
    If ($CompletionCode -eq 0xD2)    { Write-Output 'Response not provided. BMC init in progress' ; Return }
    If ($CompletionCode -eq 0xD3)    { Write-Output 'Destination unavailable' ; Return }
    If ($CompletionCode -eq 0xD4)    { Write-Output 'Insufficient privilege' ; Return }
    If ($CompletionCode -eq 0xD5)    { Write-Output 'Command not supported in present state' ; Return }
    If ($CompletionCode -eq 0xD6)    { Write-Output 'Parameter is illegal because sub-function unavailable' ; Return }

    If ($CompletionCode -eq 0xff)    { Write-Output 'Unspecified' ; Return }

    If (($CompletionCode -ge 0x01) -and ($CompletionCode -le 0x7E))   { Write-Output 'Device specific OEM code' ; Return }
    If (($CompletionCode -ge 0x80) -and ($CompletionCode -le 0xBE))   { Write-Output 'Command specific code' ; Return }
  
    Write-Output 'Reserved'
}


#----------------------------------------------------------------------------------------------
# Helper function to get an ipmi instance, returns null if IPMI not running
#----------------------------------------------------------------------------------------------
Function IpmiLib_GetIpmiInstance()
{
    [CmdletBinding()]
    Param()

    Try
    {
        $Global:CimSession    = New-CimSession
        $Global:IpmiInstance  = Get-CimInstance -Namespace root/wmi -CimSession $Global:CimSession Microsoft_IPMI
    }
    Catch
    {
        $Global:IpmiInstance = $null
        Throw "[GetIpmiInstance] ERROR: Could not open IPMI communication with BMC. Verify system contains a BMC."
    }
}
#----------------------------------------------------------------------------------------------
# Invokes an IPMI command 
#----------------------------------------------------------------------------------------------
Function Invoke-WcsIpmi()
{
   <#
  .SYNOPSIS
   Invokes an IPMI command  

  .DESCRIPTION
   Invokes an IPMI command on a WCS blade

   Refer to the IPMI specification for details on using IPMI including
   the command values, input bytes and return bytes
 
  .EXAMPLE

   $ResponseBytes = Invoke-WcsIpmi 0x1 ([byte []] $RequestData = @()) $WCS_APP_NETFN 

   Sets $ResponseBytes with response from command 0x1 (get BMC version)

  .PARAMETER Command
   Byte containing the IPMI command

  .PARAMETER RequestData
   Byte array containing the request data for the command

  .PARAMETER NetworkFunction
   IPMI network function to use:

   WCS_CHASSIS_NETFN, WCS_BRIDGE_NETFN, WCS_SENSOR_NETFN 
   WCS_APP_NETFN, WCS_FW_NETFN, WCS_STORAGE_NETFN, WCS_TRANSPORT_NETFN  

  .PARAMETER LUN
   LUN (logical unit) to use

  .OUTPUTS
   On success returns array of [byte] contains response data from the IPMI command

   On error returns $null

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI
  
   #>
   
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [Parameter(Mandatory=$true,Position=0)]  [byte]   $Command,
        [Parameter(Mandatory=$false,Position=1)] [byte[]] $RequestData=@(),
        [Parameter(Mandatory=$false,Position=2)] [byte]   $NetworkFunction=$WCS_APP_NETFN,
        [Parameter(Mandatory=$false,Position=3)] [byte]   $LUN=0
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #----------------------------------------------------------------------------------------------
        # Check if have an IPMI instance, if not then get one
        #----------------------------------------------------------------------------------------------
        If ($null -eq $Global:IpmiInstance) 
        { 
            IpmiLib_GetIpmiInstance -ErrorAction Stop  
        }
        #----------------------------------------------------------------------------------------------
        # Build the command arguments
        #----------------------------------------------------------------------------------------------
        $IpmiArguments = @{
             Command          = $Command;
             LUN              = $LUN;
             NetworkFunction  = $NetworkFunction;
             RequestData      = $RequestData;
             RequestDataSize  = [uint32] $RequestData.Length;
             ResponderAddress = $Global:IpmiInstance.BmcAddress
        }
        #----------------------------------------------------------------------------------------------
        # Send the command and return the data
        #----------------------------------------------------------------------------------------------
        $IpmiResponseData = Invoke-CimMethod -InputObject $Global:IpmiInstance -CimSession $Global:CimSession RequestResponse -Arguments  $IpmiArguments -ErrorAction Stop

        Write-Output  ( [byte[]]  @($IpmiResponseData.ResponseData) )
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

#-----------------------------------------------------------------------------------------------------------------------
# Get-WcsFruData 
#-----------------------------------------------------------------------------------------------------------------------
Function Get-WcsFruData() 
{
   <#
  .SYNOPSIS
   Gets FRU data using IPMI Read FRU commands

  .DESCRIPTION
   Gets the FRU data specified using IPMI Read FRU commands.  Specify
   the FRU offset, FRU device ID, and number of bytes to read

   If FruOffset and NumberOfBytes not specified then gets the entire FRU

   If NumberOfBytes set as -1 then gets the FRU data from FruOffset to the 
   end of the FRU

   The FruOffset and NumberOfBytes cannot exceed the size of the FRU

  .EXAMPLE
   $FruData = Get-WcsFruData

   Stores the entire FRU content into the variable $FruData as [byte[]] array. 
   To display the FRU byte at offset 2 $FruData[2].  
   To display as ASCII ([char] $FruData[2])

  .EXAMPLE
   $FruData = Get-WcsFruData -FruOffset 0x16 -NumberOfBytes 8 

   Saves 8 bytes at FRU offset 0x16 to $FruData as [byte[]] array
   
   .PARAMETER FruOffset
   Specifies the offset to begin reading the FRU.  Default is 0.

   .PARAMETER NumberOfBytes
   Specifies the number of bytes to read. Default is -1.  If -1 specified
   then reads from FruOffset to the end of the FRU.

   .PARAMETER DeviceId
   Specifies the device ID of the FRU to read.  Default is 0.

   .OUTPUTS
   On success returns array of [byte] where each entry is a FRU byte

   On error returns $null

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (   
        [Parameter(Mandatory=$false)]   [uint16] $FruOffset      = 0,
        [Parameter(Mandatory=$false)]   [int16]  $NumberOfBytes  = -1,
        [Parameter(Mandatory=$false)]   [byte]   $DeviceId       = 0
    )

    $FruAsBytes   = @()  # Contains the bytes read from the FRU

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #--------------------------------------
        # Get the size of the FRU 
        #--------------------------------------
        [byte]    $IpmiCommand = 0x10
        [byte []] $RequestData = @($DeviceId)

        $IpmiData    = Invoke-WcsIpmi $IpmiCommand $RequestData $WCS_STORAGE_NETFN -ErrorAction Stop

        If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
        { 
            Throw ("Get FRU Info command returned completion code 0x{0:X2} {1}" -f $IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
        }
        [uint16] $FruSize = $IpmiData[2]*0x100 + $IpmiData[1]

        Write-Verbose ("[] FRU ID {0} size is 0x{1:X4}`r" -f  $DeviceId,$FruSize)
        #--------------------------------------
        # If NumberOfBytes is -1 set it to read to the end of FRU
        #--------------------------------------
        If ($NumberOfBytes -eq -1)
        {
            $NumberOfBytes = $FruSize - $FruOffset 
        }
        #--------------------------------------
        # Check that not reading above FRU size
        #--------------------------------------
        If (($FruOffset -gt $FruSize) -or (($FruOffset+$NumberOfBytes) -gt $FruSize))
        {
            Throw ("FruOffset 0x{0:X4} or FruOffset+NumberOfBytes 0x{1:X4} exceeds the FRU size 0xget-{2:X4}" -f $FruOffset,($FruOffset+$NumberOfBytes),$FruSize)
        }
        #--------------------------------------
        # Now read the FRU
        #--------------------------------------
        For ([uint16] $Offset=$FruOffset; $Offset -lt ($FruOffset + $NumberOfBytes); $Offset += $WCS_BLADE_FRU_READ_SIZE)
        {
            #-------------------------------------------------------------------
            # Make sure would not exceed FRU size with default read length
            #-------------------------------------------------------------------
            If (($Offset + $WCS_BLADE_FRU_READ_SIZE) -ge ($FruOffset + $NumberOfBytes)) 
            {
                $ReadLength = [byte] (($FruOffset + $NumberOfBytes) - $Offset)
            }
            Else
            {
                $ReadLength = [byte] $WCS_BLADE_FRU_READ_SIZE
            }        
            #--------------------------------------------------------
            # Setup the request data for IPMI command
            #--------------------------------------------------------    
            $OffsetLSB = [byte] ( $Offset -band 0xFF)
            $OffsetMSB = [byte] (($Offset -band 0xFF00) -shr 8)

            $RequestData = @($DeviceId,$OffsetLSB,$OffsetMSB,$ReadLength)
            $IpmiCommand = 0x11

            Write-Verbose ("[] FRU read at offset 0x{0:X4} (0x{1:X2}{2:X2}), Number of bytes {3}`r" -f $Offset,$OffsetMSB,$OffsetLSB,$ReadLength)
            #--------------------------------------------------------
            # Must use retries if FRU busy (completion code 0x81)
            #-------------------------------------------------------- 
            For ($Retries=0;$Retries -lt $WCS_ALLOWED_FRU_RETRIES ; $Retries++)
            {
                $IpmiData = Invoke-WcsIpmi  $IpmiCommand $RequestData $WCS_STORAGE_NETFN -ErrorAction Stop

                If ($IpmiData[0] -eq $IPMI_COMPLETION_CODE_NORMAL)
                {
                    break
                } 
                ElseIf ($IpmiData[0] -eq 0x81)
                {
                    Write-Verbose ("[] FRU Read command at {0} returned completion code 0x{1:X2} indicating FRU busy`r" -f $Offset,$IpmiData[0])
                    Start-Sleep -Milliseconds 30
                }
                Else
                {
                    Throw ("FRU Read command at {0} returned completion code 0x{1:X2} {2}" -f $Offset,$IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
                }
            }
            #--------------------------------------------------------
            # Return $null if could not read the entire FRU
            #--------------------------------------------------------
            If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
            { 
                Throw ("FRU read command failed to read FRU {0} times in a row. Last completion code 0x{1:X2} {2]" -f $WCS_ALLOWED_FRU_RETRIES,$IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
            }
            #--------------------------------------------------------
            # Return $null if could not read the entire FRU
            #--------------------------------------------------------
            If ($IpmiData[1] -ne $ReadLength) 
            { 
                Throw ("FRU read command returned wrong number of bytes.  Expected {0} but returned {1}" -f  $ReadLength ,$IpmiData[1])
            }
            #--------------------------------------------------------
            # Strip first two bytes (Completion Code, Count Returned)
            #--------------------------------------------------------
            For ($ByteCount=2; $ByteCount -lt (2 + $ReadLength); $ByteCount++)
            {
                $FruAsBytes  += [byte] $IpmiData[$ByteCount]
            }
        }
        #--------------------------------------
        # Return the data
        #--------------------------------------
        Write-Output $FruAsBytes
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
#-----------------------------------------------------------------------------------------------------------------------
# Log-WcsFru
#-----------------------------------------------------------------------------------------------------------------------
Function Log-WcsFru() 
{
   <#
  .SYNOPSIS
   Logs FRU information to a file in xml format

  .DESCRIPTION
   Logs FRU information to a file in xml format.  If FruData not specified
   reads the FRU data then logs it.
   
  .EXAMPLE
   Log-WcsFru MyFruData

   Saves the FRU data into the file MyFruData.fru.log

  .EXAMPLE
   Log-WcsFru -File MyFruData -LogDirectory \wcsTest\Results\MyFru

   Saves the FRU data into the file \wcsTest\Results\MyFru\MyFruData.fru.log

  .PARAMETER FruData
   Configuration xml object to save to the file.  If not specified logs the systems
   FRU information.

  .PARAMETER File
   Name of the file to log the data into.  Default file name FruInfo-<dateTime>.fru.log

  .PARAMETER LogDirectory
   Directory to log the file.  Default directory is <InstallDir>\Results\Log-WcsFru

  .PARAMETER DeviceId
   FRU device ID to read.  Defaults to 0.

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error
  
  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$false,Position=0)] [String] $File = ("FruInfo-{0}" -f (BaseLib_SimpleDate)),
        [Parameter(Mandatory=$false)]            [String] $LogDirectory = "$WCS_RESULTS_DIRECTORY\Log-WcsFru",
        [Parameter(Mandatory=$false)]            [int]    $DeviceId = 0,
        [Parameter(Mandatory=$false)]                     $FruData  = $null
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
        if (-NOT (Test-Path $LogDirectory -PathType Container)) 
        { 
            New-Item  $LogDirectory -ItemType Container | Out-Null 
        }

        $File = $File.ToLower()

        if ($File.EndsWith(".log"))    { $File =  $File.Remove($File.Length - ".log".Length)  }
        if ($File.EndsWith(".fru"))    { $File =  $File.Remove($File.Length - ".fru".Length)  }

        $RawFilePath      = Join-Path $LogDirectory ($File + ".fru.log")  

        Remove-Item $RawFilePath      -ErrorAction SilentlyContinue -Force | Out-Null
 
        #-------------------------------------------------------
        # If FruData not specified then read it
        #-------------------------------------------------------
        If ($FruData -eq $null) 
        { 
            $FruData = Get-WcsFru  -DeviceId $DeviceId -ErrorAction Stop
        }
        #-------------------------------------------------------
        # Save the file
        #-------------------------------------------------------
        $FruData.Save($RawFilePath) 
                 
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

#-----------------------------------------------------------------------------------------------------------------------
# Update-WcsFruData 
#-----------------------------------------------------------------------------------------------------------------------
Function Update-WcsFruData() 
{
   <#
  .SYNOPSIS
   Updates FRU data using IPMI Write FRU commands

  .DESCRIPTION
   Sets the FRU data specified using IPMI Write FRU commands.  Specify
   the FRU offset, FRU device ID, and bytes to write

   The FruOffset and number of bytes to write cannot exceed the size of the FRU

  .EXAMPLE
   Update-WcsFruData -FruOffset 0x16 -Bytes ([byte[]] 0,1,2,3)

   Writes 4 bytes (0,1,2,3) at FRU offset 0x16
   
   .PARAMETER FruOffset
   Specifies the offset to begin reading the FRU.  Default is 0.

   .PARAMETER DataToWrite
   Data to write as an array of byte

   .PARAMETER DeviceId
   Specifies the device ID of the FRU to read.  Default is 0.

   .OUTPUTS
   On success returns number of bytes written

   On error returns 0 or $null

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (   
        [Parameter(Mandatory=$true)]  [uint16] $FruOffset,
        [Parameter(Mandatory=$true)]  [byte[]] $DataToWrite,
        [Parameter(Mandatory=$false)] [byte]   $DeviceId = 0 
    )

    [int] $DataBytesWritten = 0

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #--------------------------------------
        # Get the size of the FRU 
        #--------------------------------------
        [byte]    $IpmiCommand = 0x10
        [byte []] $RequestData = @($DeviceId)

        [byte[]]  $IpmiData    = Invoke-WcsIpmi $IpmiCommand $RequestData $WCS_STORAGE_NETFN -ErrorAction Stop

        If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
        { 
            Throw ("Get FRU Info command returned completion code 0x{0:X2} {1}" -f $IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
        }
        [uint16] $FruSize = $IpmiData[2]*0x100 + $IpmiData[1]

        Write-Verbose ("[] FRU ID {0} size is 0x{1:X4}`r" -f  $DeviceId,$FruSize)

        #--------------------------------------
        # Check that not writing above FRU size
        #--------------------------------------
        [uint16]  $Length         = $DataToWrite.Count
        [uint16]  $RemainingBytes = $DataToWrite.Count

        If (($FruOffset+$Length) -gt $FruSize)
        {
            Throw ("FruOffset 0x{0:X4} or FruOffset+Bytes.Count 0x{1:X4} exceeds the FRU size 0x{2:X4}" -f $FruOffset,($FruOffset+$Length),$FruSize)
        }
        #--------------------------------------
        # Now write the FRU
        #--------------------------------------
        For ([int16] $Offset=$FruOffset; $Offset -lt ($FruOffset + $Length); $Offset += $WCS_BLADE_FRU_WRITE_SIZE)
        {
            $RemainingBytes = ($FruOffset + $Length) - $Offset 
            #-------------------------------------------------------------------
            # Check if remaining bytes less then max write size
            #-------------------------------------------------------------------
            If ($WCS_BLADE_FRU_WRITE_SIZE -ge $RemainingBytes) 
            {
                $LoopWriteData = [byte[]] $DataToWrite[($Offset-$FruOffset)..($Length - 1)]
            }
            Else
            {
                $LoopWriteData = [byte[]] $DataToWrite[($Offset-$FruOffset)..(($Offset-$FruOffset) + $WCS_BLADE_FRU_WRITE_SIZE - 1)]
            }        
            #--------------------------------------------------------
            # Setup the request data for IPMI command
            #--------------------------------------------------------    
            $OffsetLSB = [byte] ( $Offset -band 0xFF)
            $OffsetMSB = [byte] (($Offset -band 0xFF00) -shr 8)
        
            $IpmiCommand = 0x12
            $RequestData = @($DeviceId,$OffsetLSB,$OffsetMSB) + $LoopWriteData

            Write-Verbose ("Write FRU offset 0x{0:X4} 0x{1:X2}{2:X2}, length {3}`r" -f $Offset,$OffsetMSB,$OffsetLSB,$LoopWriteData.Count)
            #--------------------------------------------------------
            # Must use retries if FRU busy (completion code 0x81)
            #-------------------------------------------------------- 
            For ($Retries=0;$Retries -lt $WCS_ALLOWED_FRU_RETRIES ; $Retries++)
            {
                $IpmiData = Invoke-WcsIpmi  $IpmiCommand $RequestData $WCS_STORAGE_NETFN 

                If ($IpmiData[0] -eq $IPMI_COMPLETION_CODE_NORMAL)
                {
                    break
                } 
                ElseIf ($IpmiData[0] -eq 0x81)
                {
                    Write-Verbose ("[] FRU write command at {0} returned completion code 0x{1:X2} indicating FRU busy`r" -f $Offset,$IpmiData[0])
                    Start-Sleep -Milliseconds 30
                }
                Else
                {
                    Throw ("FRU write command at {0} returned completion code 0x{1:X2} {2}" -f $Offset,$IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
                }
            }
            #--------------------------------------------------------
            # Return $null if could not read the entire FRU
            #--------------------------------------------------------
            If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
            { 
                Throw ("FRU read command failed to read FRU {0} times in a row. Last completion code 0x{1:X2} {2]" -f $WCS_ALLOWED_FRU_RETRIES,$IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )

            }
            #--------------------------------------------------------
            # Return $null if could not read the entire FRU
            #--------------------------------------------------------
            If ($IpmiData[1] -ne $LoopWriteData.Count) 
            { 
                Throw ("FRU write command returned wrong number of bytes.  Expected {0} but returned {1}" -f  $LoopWriteData.Count ,$IpmiData[1])
            }
            Else
            {
                $DataBytesWritten += $LoopWriteData.Count
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
    #--------------------------------------
    # Return the data
    #--------------------------------------
    Write-Output $DataBytesWritten
} 

#-----------------------------------------------------------------------------------------------------------------------
# Update-WcsFruChecksum 
#-----------------------------------------------------------------------------------------------------------------------
Function Update-WcsFruChecksum() 
{
   <#
  .SYNOPSIS
   Updates checksum for a range of FRU data using IPMI Write FRU commands

  .DESCRIPTION
   Updates checksum for a range of FRU data using IPMI Write FRU commands

  .EXAMPLE
   Update-WcsFruChecksum -ChecksumStartOffset 8 -ChecksumEndOffset 62 -ChecksumEndOffset 63

   Writes checksum at offset 63 for the FRU range 8 to 62
   
  .PARAMETER ChecksumOffset
   Offset to write the checksum

  .PARAMETER ChecksumStartOffset
   Start of range to calculate the checksum

  .PARAMETER ChecksumEndOffset
   End of range to calculate the checksum

  .PARAMETER DeviceId
   Specifies the device ID of the FRU to read.  Default is 0.

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (   
        [Parameter(Mandatory=$true)]  [uint16] $ChecksumOffset,
        [Parameter(Mandatory=$true)]  [uint16] $ChecksumStartOffset,
        [Parameter(Mandatory=$true)]  [uint16] $ChecksumEndOffset,
        [Parameter(Mandatory=$false)] [byte]   $DeviceId = 0 
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Get FRU data
        #-------------------------------------------------------
        $Checksum = 0

        Get-WcsFruData -FruOffset $ChecksumStartOffset -NumberOfBytes (1 + $ChecksumEndOffset - $ChecksumStartOffset) -DeviceId $DeviceId -ErrorAction Stop | ForEach-Object { 

            $Checksum += $_      
        }
        
        $ByteChecksum = [byte] ($Checksum -band 0xFF)
        $ByteChecksum = [byte] (((0xFF - $ByteChecksum) + 1) -band 0xFF)

        Write-Verbose ("The checksum {0}`r" -f $ByteChecksum)
        $BytesWritten = Update-WcsFruData -FruOffset $ChecksumOffset -DataToWrite @([byte] $ByteChecksum ) -DeviceID $DeviceId -ErrorAction Stop
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
#-----------------------------------------------------------------------------------------------------------------------
# Update-WcsFru
#-----------------------------------------------------------------------------------------------------------------------
Function Update-WcsFru() 
{
   <#
  .SYNOPSIS
   Updates the FRU with the specified information

  .DESCRIPTION
   Updates the FRU with the specified information.  Also resets all FRU fields
   to the default values for the system.

  .EXAMPLE
   Update-WcsFru -AssetTag MS12345 -Serial SN01234567890

   Updates the asset tag and product serial number

  .EXAMPLE
   Update-WcsFru -TemplateFile FRU_V0.02

   Forces FRU update to FRU_V0.02 regardless of current system state

  .PARAMETER AssetTag
   Asset tag.  This is a 7 character field

  .PARAMETER SerialNumber
   Product serial number.  This is a 13 character field

  .PARAMETER MBSerialNumber
   Motherboard serial number.  This is a 11 character field

  .PARAMETER ChassisSerialNumber
   Chassis serial number.  This is a 13 character field

  .PARAMETER BuildVersion
   Build version.  This is a 3 character field

  .OUTPUTS
   Returns 0 on success, non-zero integer code on error

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$false)]
        [ValidateLength(7,7)]    
        [String] $AssetTag = '',
        
        [Parameter(Mandatory=$false)]
        [ValidateLength(13,13)]  
        [String] $SerialNumber = '',

        [Parameter(Mandatory=$false)]
        [ValidateLength(11,11)]  
        [String] $MBSerialNumber = '',

        [Parameter(Mandatory=$false)]
        [ValidateLength(13,13)]  
        [String] $ChassisSerialNumber = '',

        [Parameter(Mandatory=$false)]
        [ValidateLength(3,3)]  
        [String] $BuildVersion = '',
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("FRU_V0.02", "FRU_V0.03", "FRU_V0.04")]
        [String] $TemplateFile=''
    )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Read the current FRU info
        #-------------------------------------------------------
        $FruInfo = IpmiLib_GetBmcFru -ErrorAction SilentlyContinue

        #-------------------------------------------------------
        # Load the template  
        #-------------------------------------------------------
        If ('' -eq $TemplateFile)
        {            
            $FruTemplate  =  DefinedSystem_GetFruInformation  -ErrorAction Stop
        }
        Else
        {
            $FruTemplate  = Get-WcsFru -File $TemplateFile  -LogDirectory "$WCS_REF_DIRECTORY\FruTemplates" -ErrorAction Stop
        }
        

        $OutputFruData = @()

        $FruTemplate.WcsFruData.Offsets.ChildNodes | ForEach-Object { $OutputFruData += $_.Byte }
                           
        #---------------------------------------------------------
        # Merge unique fields back into the data
        #---------------------------------------------------------
        If ($FruInfo.BoardMinutes  -ne $WCS_NOT_AVAILABLE)  
        { 
            $Offset = [int]  $FruTemplate.WcsFruData.BoardMinutesOffset.Value
            $OutputFruData[$Offset]     = $FruInfo.BoardMinutes -band 0xFF
            $OutputFruData[($Offset+1)] = ($FruInfo.BoardMinutes -shr 8 ) -band 0xFF
            $OutputFruData[($Offset+2)] = ($FruInfo.BoardMinutes -shr 16) -band 0xFF         
        }
        #---------------------------------------------------------
        # MB serial number update
        #---------------------------------------------------------
        If ($MBSerialNumber -ne '')
        {
            $OutputFruData = MergeFruField $OutputFruData  $FruTemplate.WcsFruData.BoardSerialOffset.Value $MBSerialNumber       
        }         
        ElseIf (($FruInfo.BoardSerial  -ne $WCS_NOT_AVAILABLE)  -and ($FruInfo.BoardSerial.Length -eq 11))
        {  
            $OutputFruData = MergeFruField $OutputFruData  $FruTemplate.WcsFruData.BoardSerialOffset.Value $FruInfo.BoardSerial         
        }
        #---------------------------------------------------------
        # Chassis serial number update
        #---------------------------------------------------------
        If ($ChassisSerialNumber -ne '')
        {
            $OutputFruData = MergeFruField $OutputFruData  $FruTemplate.WcsFruData.ChassisSerialOffset.Value $ChassisSerialNumber     
        }  
        ElseIf (($FruInfo.ChassisSerial -eq $WCS_NOT_AVAILABLE) -and ($FruInfo.ChassisSerial.Length -eq 13)) 
        { 
            $OutputFruData = MergeFruField $OutputFruData  $FruTemplate.WcsFruData.ChassisSerialOffset.Value $FruInfo.ChassisSerial 
        }
        #---------------------------------------------------------
        # Build version number update
        #---------------------------------------------------------
        If ($BuildVersion -ne '')
        {
           $OutputFruData =  MergeFruField $OutputFruData  $FruTemplate.WcsFruData.ProductCustom3Offset.Value $BuildVersion     
        }
        ElseIf (($FruInfo.ProductCustom3 -eq $WCS_NOT_AVAILABLE) -and ($FruInfo.ProductCustom3.Length -eq 7))
        { 
           $OutputFruData = MergeFruField $OutputFruData  $FruTemplate.WcsFruData.ProductCustom3Offset.Value $FruInfo.ProductCustom3 
        }
        #---------------------------------------------------------
        # Product Serial number update
        #---------------------------------------------------------
        If ($SerialNumber -ne '')
        {
            $OutputFruData = MergeFruField $OutputFruData  $FruTemplate.WcsFruData.ProductSerialOffset.Value $SerialNumber       
        }        
        ElseIf (($FruInfo.ProductSerial -eq $WCS_NOT_AVAILABLE)  -and ($FruInfo.ProductSerial.Length -eq 7))
        {
            $OutputFruData = MergeFruField $OutputFruData  $FruTemplate.WcsFruData.ProductSerialOffset.Value $FruInfo.ProductSerial 
        }
        #---------------------------------------------------------
        # Asset Tag update
        #---------------------------------------------------------
        If ($AssetTag -ne '')
        {
            $OutputFruData =  MergeFruField $OutputFruData  $FruTemplate.WcsFruData.ProductAssetOffset.Value $AssetTag       
        } 
        ElseIf (($FruInfo.ProductAsset -ne $WCS_NOT_AVAILABLE) -and ($FruInfo.ProductAsset.Length -eq 7))
        {
            $OutputFruData = MergeFruField $OutputFruData  $FruTemplate.WcsFruData.ProductAssetOffset.Value $FruInfo.ProductAsset 
        }

        #---------------------------------------------------------
        # Update the FRU with the new checksums
        #---------------------------------------------------------
        $BytesWritten = Update-WcsFruData -FruOffset 0 -DataToWrite $OutputFruData

        $BytesWritten = Update-WcsFruChecksum -ChecksumOffset $FruTemplate.WcsFruData.BoardChecksumOffset.Value   -ChecksumStartOffset  $FruTemplate.WcsFruData.BoardStartOffset.Value   -ChecksumEndOffset ($FruTemplate.WcsFruData.BoardChecksumOffset.Value-1)
        $BytesWritten = Update-WcsFruChecksum -ChecksumOffset $FruTemplate.WcsFruData.ChassisChecksumOffset.Value -ChecksumStartOffset  $FruTemplate.WcsFruData.ChassisStartOffset.Value -ChecksumEndOffset ($FruTemplate.WcsFruData.ChassisChecksumOffset.Value-1)
        $BytesWritten = Update-WcsFruChecksum -ChecksumOffset $FruTemplate.WcsFruData.ProductChecksumOffset.Value -ChecksumStartOffset  $FruTemplate.WcsFruData.ProductStartOffset.Value -ChecksumEndOffset ($FruTemplate.WcsFruData.ProductChecksumOffset.Value-1)
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

#-----------------------------------------------------------------------------------------------------------------------
# Get-WcsFru 
#-----------------------------------------------------------------------------------------------------------------------
Function Get-WcsFru() 
{
   <#
  .SYNOPSIS
   Gets FRU information using IPMI Read FRU commands

  .DESCRIPTION
   Gets the FRU information from either the file specified or the local system

   The information is returned as an XML object

  .EXAMPLE
   $FruData = Get-WcsFru

   Stores the current FRU information in $FruData

  .EXAMPLE
   $FruData = Get-WcsFru -File SavedFruInfo -Logdirectory \wcstest\results\fru

   Stores the FRU information in \wcstest\results\fru\SavedFruInfo.fru.log
   into $FruData
   
  .PARAMETER File
   Name of the file to get the FRU data.  If not specified reads local system's
   FRU information 

  .PARAMETER LogDirectory
   Directory to read the file.  Default directory is <InstallDir>\Results\Log-WcsFru

   .PARAMETER DeviceId
   Specifies the device ID of the FRU to read.  Default is 0.

   .OUTPUTS
   On success returns array of [byte] where each entry is a FRU byte

   On error returns $null

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (   
        [Parameter(Mandatory=$false,Position=0)] [String] $File ='',
        [Parameter(Mandatory=$false)]            [String] $LogDirectory = "$WCS_RESULTS_DIRECTORY\Log-WcsFru",
        [Parameter(Mandatory=$false)]            [byte]   $DeviceId       = 0
    )

    $FruAsBytes   = @()  # Contains the bytes read from the FRU
    $FruOffset      = 0
    $NumberOfBytes  = -1
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Get FRU from file
        #-------------------------------------------------------
        If ($File -ne '')
        {
            $File = $File.ToLower()

            if ($File.EndsWith(".log"))    { $File =  $File.Remove($File.Length - ".log".Length)  }
            if ($File.EndsWith(".fru"))    { $File =  $File.Remove($File.Length - ".fru".Length)  }

            $RawFilePath      = Join-Path $LogDirectory ($File + ".fru.log") 

            $xmlFruData =  [xml] (Get-Content $RawFilePath)

            Write-Output $xmlFruData
        }
        #-------------------------------------------------------
        # Read local FRU
        #-------------------------------------------------------
        Else
        {
            #--------------------------------------
            # Get the size of the FRU 
            #--------------------------------------
            [byte]    $IpmiCommand = 0x10
            [byte []] $RequestData = @($DeviceId)

            $IpmiData    = Invoke-WcsIpmi $IpmiCommand $RequestData $WCS_STORAGE_NETFN -ErrorAction Stop

            If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
            { 
                Throw ("Get FRU Info command returned completion code 0x{0:X2} {1}" -f $IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
            }
            [uint16] $FruSize = $IpmiData[2]*0x100 + $IpmiData[1]

            Write-Verbose ("[] FRU ID {0} size is 0x{1:X4}`r" -f  $DeviceId,$FruSize)
            #--------------------------------------
            # If NumberOfBytes is -1 set it to read to the end of FRU
            #--------------------------------------
            If ($NumberOfBytes -eq -1)
            {
                $NumberOfBytes = $FruSize - $FruOffset 
            }
            #--------------------------------------
            # Check that not reading above FRU size
            #--------------------------------------
            If (($FruOffset -gt $FruSize) -or (($FruOffset+$NumberOfBytes) -gt $FruSize))
            {
                Throw ("FruOffset 0x{0:X4} or FruOffset+NumberOfBytes 0x{1:X4} exceeds the FRU size 0xget-{2:X4}" -f $FruOffset,($FruOffset+$NumberOfBytes),$FruSize)
            }
            #--------------------------------------
            # Now read the FRU
            #--------------------------------------
            For ([uint16] $Offset=$FruOffset; $Offset -lt ($FruOffset + $NumberOfBytes); $Offset += $WCS_BLADE_FRU_READ_SIZE)
            {
                #-------------------------------------------------------------------
                # Make sure would not exceed FRU size with default read length
                #-------------------------------------------------------------------
                If (($Offset + $WCS_BLADE_FRU_READ_SIZE) -ge ($FruOffset + $NumberOfBytes)) 
                {
                    $ReadLength = [byte] (($FruOffset + $NumberOfBytes) - $Offset)
                }
                Else
                {
                    $ReadLength = [byte] $WCS_BLADE_FRU_READ_SIZE
                }        
                #--------------------------------------------------------
                # Setup the request data for IPMI command
                #--------------------------------------------------------    
                $OffsetLSB = [byte] ( $Offset -band 0xFF)
                $OffsetMSB = [byte] (($Offset -band 0xFF00) -shr 8)

                $RequestData = @($DeviceId,$OffsetLSB,$OffsetMSB,$ReadLength)
                $IpmiCommand = 0x11

                Write-Verbose ("[] FRU read at offset 0x{0:X4} (0x{1:X2}{2:X2}), Number of bytes {3}`r" -f $Offset,$OffsetMSB,$OffsetLSB,$ReadLength)
                #--------------------------------------------------------
                # Must use retries if FRU busy (completion code 0x81)
                #-------------------------------------------------------- 
                For ($Retries=0;$Retries -lt $WCS_ALLOWED_FRU_RETRIES ; $Retries++)
                {
                    $IpmiData = Invoke-WcsIpmi  $IpmiCommand $RequestData $WCS_STORAGE_NETFN -ErrorAction Stop

                    If ($IpmiData[0] -eq $IPMI_COMPLETION_CODE_NORMAL)
                    {
                        break
                    } 
                    ElseIf ($IpmiData[0] -eq 0x81)
                    {
                        Write-Verbose ("[] FRU Read command at {0} returned completion code 0x{1:X2} indicating FRU busy`r" -f $Offset,$IpmiData[0])
                        Start-Sleep -Milliseconds 30
                    }
                    Else
                    {
                        Throw ("FRU Read command at {0} returned completion code 0x{1:X2} {2}" -f $Offset,$IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
                    }
                }
                #--------------------------------------------------------
                # Return $null if could not read the entire FRU
                #--------------------------------------------------------
                If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
                { 
                    Throw ("FRU read command failed to read FRU {0} times in a row. Last completion code 0x{1:X2} {2]" -f $WCS_ALLOWED_FRU_RETRIES,$IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
                }
                #--------------------------------------------------------
                # Return $null if could not read the entire FRU
                #--------------------------------------------------------
                If ($IpmiData[1] -ne $ReadLength) 
                { 
                    Throw ("FRU read command returned wrong number of bytes.  Expected {0} but returned {1}" -f  $ReadLength ,$IpmiData[1])
                }
                #--------------------------------------------------------
                # Strip first two bytes (Completion Code, Count Returned)
                #--------------------------------------------------------
                For ($ByteCount=2; $ByteCount -lt (2 + $ReadLength); $ByteCount++)
                {
                    $FruAsBytes  += [byte] $IpmiData[$ByteCount]
                }
            }

            #-------------------------------------------------------------------------------------
            # Build the XML object
            #-------------------------------------------------------------------------------------
            $myBuilder = New-Object System.Text.StringBuilder(350000)
            $xmlwriter = [system.xml.xmlwriter]::Create($myBuilder)

            $ChassisStart = 8* $FruAsBytes[2]
            $BoardStart   = 8* $FruAsBytes[3]
            $ProductStart = 8* $FruAsBytes[4]

            $xmlwriter.WriteStartElement('WcsFruData')
            $xmlwriter.WriteAttributeString('Version','1.0')

            $xmlwriter.WriteStartElement('FruSize')
            $xmlwriter.WriteAttributeString('Value',$FruSize)  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('ChassisStartOffset')
            $xmlwriter.WriteAttributeString('Value',$ChassisStart)  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('ChassisSerialOffset')
            $xmlwriter.WriteAttributeString('Value','N/A')  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('ChassisChecksumOffset')
            $xmlwriter.WriteAttributeString('Value',($BoardStart -1) )  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('BoardStartOffset')
            $xmlwriter.WriteAttributeString('Value',$BoardStart)  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('BoardMinutesOffset')
            $xmlwriter.WriteAttributeString('Value',( 3 + $BoardStart))
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('BoardSerialOffset')
            $xmlwriter.WriteAttributeString('Value','N/A')
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('BoardChecksumOffset')
            $xmlwriter.WriteAttributeString('Value',($ProductStart-1))  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('ProductStartOffset')
            $xmlwriter.WriteAttributeString('Value',$ProductStart)  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('ProductSerialOffset')
            $xmlwriter.WriteAttributeString('Value','N/A')  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('ProductAssetOffset')
            $xmlwriter.WriteAttributeString('Value','N/A')  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('ProductCustom3Offset')
            $xmlwriter.WriteAttributeString('Value','N/A')  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('ProductChecksumOffset')
            $xmlwriter.WriteAttributeString('Value',($ProductStart + (8* $FruAsBytes[($ProductStart+1)]) - 1))  
            $xmlwriter.WriteEndElement()

            $xmlwriter.WriteStartElement('Offsets')

            $Offset = 0

            $FruAsBytes | ForEach-Object {            

                If ($_ -ge 0x20) { $CharString = ([char] $_) }
                Else             { $CharString = '' }

                $xmlwriter.WriteStartElement('Offset')
                $xmlwriter.WriteAttributeString('Value',$Offset++)  
                $xmlwriter.WriteAttributeString('Byte',("0x{0:X2}" -f $_))  
                $xmlwriter.WriteAttributeString('Char',$CharString)  
                $xmlwriter.WriteEndElement()
            }

            $xmlwriter.WriteEndElement()        
            $xmlwriter.WriteEndElement()
            $xmlwriter.Close()
        
            $FruConfig = New-Object system.Xml.xmldocument
            $FruConfig.LoadXml( $myBuilder.ToString() )           
    
            Write-Output $FruConfig
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



#-------------------------------------------------------------------------------------
# Get-WcsSel
#-------------------------------------------------------------------------------------
Function Get-WcsSel() {

   <#
  .SYNOPSIS
   Gets the BMC SEL entries

  .DESCRIPTION
   Gets all of the SEL entries in the BMC

  .EXAMPLE
   $MyEntries = Get-WcsSel
 
  .PARAMETER NoDecode
   If specified does not decode the SEL entries

  .PARAMETER HardwareError
   If specified gets only hardware errors

  .PARAMETER RecordType
   If specified only returns entries with a RecordType that is listed 
   in the specified RecordType 

  .PARAMETER SensorType
   If specified only returns entries with a SensorType that is listed 
   in the specified SensorType 

  .PARAMETER Sensor
   If specified only returns entries with a Sensor that is listed 
   in the specified Sensor 
   
   .OUTPUTS
   On success returns an array of SEL entries

   On error returns 0 or $null

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [switch] $NoDecode, 
        [switch] $HardwareError, 
        [byte []] $RecordType= $Null,  
        [byte []] $SensorType= $null,  
        [byte []] $Sensor=$null
    ) 

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #--------------------------------------------------------
        # Open IPMI communication to BMC if not already opened
        #--------------------------------------------------------
        IpmiLib_GetIpmiInstance  -ErrorAction Stop

        #------------------------------------------------------
        # Read all the SEL events, first entry is always 0000
        #------------------------------------------------------
        $SelEntries  = @()    # Array to hold the Sel entries that meet input parameters
        $LastEntry   = $null  # Holds the previous SEL entry
        $SelEntry    = $null  # Holds the current SEL entry

        $FirstSelEntry = $true

        [byte] $CurrentIdLSB =  0
        [byte] $CurrentIdMSB =  0
            
        #------------------------------------------------------
        # Last entry has a next entry of 0xFFFF
        #------------------------------------------------------
        while ((0xFF -ne $CurrentIdLSB) -and (0xFF -ne $CurrentIdMSB))
        {
            Write-Verbose ("Getting entry 0x{0:X2}{1:X2}`r" -f $CurrentIdMSB,$CurrentIdLSB)

            [byte]    $IpmiCommand = 0x43   # Get SEL entry Command
            [byte []] $RequestData = @(0,0,$CurrentIdLSB,$CurrentIdMSB,0,0xFF)
            
            $IpmiData = Invoke-WcsIpmi  $IpmiCommand $RequestData $WCS_STORAGE_NETFN -ErrorAction Stop

            If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
            { 
                Throw ("Get SEL Entry command returned completion code 0x{0:X2} {1}" -f $IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
            }
            #------------------------
            # Save ID for next entry
            #------------------------
            $CurrentIdLSB = $IpmiData[1]
            $CurrentIdMSB = $IpmiData[2]

            Write-Verbose ("Next entry 0x{0:X2}{1:X2}`r" -f $CurrentIdMSB,$CurrentIdLSB)
            #--------------------------------------------
            # Add SEL entry to the array of SEL entries
            #--------------------------------------------
            $SelEntry     = $SEL_ENTRY.Clone()
 
            $SelEntry.RecordId    =  [string] ("{0:X2}{1:X2}" -f $IpmiData[4],$IpmiData[3])
            $SelEntry.RecordType  =  [byte]    ("0x{0:X2}"       -f $IpmiData[5] )           
            #---------------------------------------------------------------
            # Sensor entry - Decode timestamp and parse the sensor fields
            #---------------------------------------------------------------
            If ($SelEntry.RecordType -eq 0x02)
            {                
                $SelEntry.Timestamp             =  [uint32] ("0x{0:X2}{1:X2}{2:X2}{3:X2}" -f $IpmiData[9],$IpmiData[8],$IpmiData[7],$IpmiData[6]) 
                $SelEntry.TimeStampDecoded      = IpmiLib_DecodeTimestamp $SelEntry.Timestamp

                $SelEntry.GeneratorId           = [uint16] ("0x{0:X2}{1:X2}" -f $IpmiData[10],$IpmiData[11])
                $SelEntry.EventMessageVersion   = [byte] ("0x{0:X2}"       -f $IpmiData[12])
                $SelEntry.SensorType            = [byte] ("0x{0:X2}"       -f $IpmiData[13])
                $SelEntry.Sensor                = [byte] ("0x{0:X2}"       -f $IpmiData[14])
                $SelEntry.EventDirType          = [byte] ("0x{0:X2}"       -f $IpmiData[15])
                $SelEntry.EventData1            = [byte] ("0x{0:X2}"       -f $IpmiData[16])
                $SelEntry.EventData2            = [byte] ("0x{0:X2}"       -f $IpmiData[17])
                $SelEntry.EventData3            = [byte] ("0x{0:X2}"       -f $IpmiData[18])

                $SelEntry.NoDecode              = ("{0:X4} RecordType: 0x{1:X2} TimeStamp: {2:X8} {3}" -f $SelEntry.RecordID,$SelEntry.RecordType,$SelEntry.TimeStamp, (IpmiLib_FormatSensorRecordData $SelEntry))
            }
            #--------------------------------------------------
            # OEM timestamp entry - Decode timestamp
            #--------------------------------------------------
            ElseIf (($SelEntry.RecordType -ge 0xC0) -and ($SelEntry.RecordType -le 0xDF))
            {
                $SelEntry.Timestamp         =  [uint32] ("0x{0:X2}{1:X2}{2:X2}{3:X2}" -f $IpmiData[9],$IpmiData[8],$IpmiData[7],$IpmiData[6] ) 
                $SelEntry.TimeStampDecoded  =  IpmiLib_DecodeTimestamp $SelEntry.Timestamp
                $SelEntry.ManufacturerId    =  [uint32] ("0x{0:X2}{1:X2}{2:X2}" -f $IpmiData[12],$IpmiData[11],$IpmiData[10] ) 

                $SelEntry.OemTimestampRecord  = ""

                For ($ByteIndex = 18; $ByteIndex -ge 13; $ByteIndex--)
                {
                    $SelEntry.OemTimestampRecord += ("{0:X2}" -f $IpmiData[$ByteIndex])
                }

                $SelEntry.NoDecode = ("{0:X4} RecordType: 0x{1:X2} TimeStamp: {2:X8} MfgId: 0x{3:X6}  OEM Data (16-11): 0x{4}"-f $SelEntry.RecordID,$SelEntry.RecordType,$SelEntry.TimeStamp,$SelEntry.ManufacturerId,$SelEntry.OemTimestampRecord )
            }
            ElseIf (($SelEntry.RecordType -ge 0xE0) -and ($SelEntry.RecordType -le 0xFF))
            {
                $SelEntry.OemNonTimestampRecord  = ""

                For ($ByteIndex = 18; $ByteIndex -ge 6; $ByteIndex--)
                {
                        $SelEntry.OemNonTimestampRecord += ("{0:X2}" -f $IpmiData[$ByteIndex])
                }
                $SelEntry.NoDecode  = ("{0:X4} RecordType: 0x{1:X2} OEM Data (16-4): 0x{3}" -f $SelEntry.RecordID,$SelEntry.RecordType,$SelEntry.OemNonTimestampRecord )
            }
            Else 
            {
                $UnknownRecordType = ("Unknown Record Type: 0x{0:X2}  OEM Data (16-4): 0x" -f $SelEntry.RecordType)
                For ($ByteIndex = 18; $ByteIndex -ge 6; $ByteIndex--)
                {
                         $UnknownRecordType  += ("{0:X2}" -f $IpmiData[$ByteIndex])
                }
                $SelEntry.NoDecode            = ("{0:X4} {1}" -f $SelEntry.RecordID,$UnknownRecordType)
            }

            #--------------------------------------------------
            # Decode the SEL entry (add readable description)
            #--------------------------------------------------
            If ($FirstSelEntry) 
            { 
                DefinedSystem_DecodeSelEntry ([ref] $SelEntry) 
            }
            Else
            {
                DefinedSystem_DecodeSelEntry ([ref] $SelEntry)  $LastEntry
            }
            #--------------------------------------------------
            # Add to the array if meet input requirements
            #--------------------------------------------------
            If (  (($RecordType -eq $null) -or ($SelEntry.RecordType -in $RecordType)) -and
                  (($SensorType -eq $null) -or ($SelEntry.SensorType -in $SensorType)) -and
                  (($Sensor     -eq $null) -or ($SelEntry.Sensor     -in $Sensor ))    -and
                  (-NOT $HardwareError -or ($HardwareError  -and $SelEntry.HardwareError))    
            )    
            {
                $SelEntries   += $SelEntry.Clone()
            }
            $LastEntry     = $SelEntry.Clone()
            $FirstSelEntry = $false

        }
        #------------------- 
        # Output the array
        #-------------------
        Write-Output $SelEntries 
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

#-------------------------------------------------------------------------------------
# Log-WcsSel
#-------------------------------------------------------------------------------------
Function Log-WcsSel() {

   <#
  .SYNOPSIS
   Logs the BMC SEL entries

  .DESCRIPTION
   Logs the BMC SEL entries.  If SelEntries not specified then reads the SEL and
   logs all entries

  .EXAMPLE
   Log-WcsSel
   
  .OUTPUTS
   Returns 0 on success, non-zero integer code on error
  
  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>

    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$false,Position=0)] [String] $File = ("SelEntries-{0}" -f (BaseLib_SimpleDate)),
                                                 [String] $LogDirectory = "$WCS_RESULTS_DIRECTORY\Log-WcsSel",
                                                          $SelEntries = $null
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

        $File = $File.ToLower()

        if ($File.EndsWith(".log"))    { $File =  $File.Remove($File.Length - ".log".Length)     }
        if ($File.EndsWith(".sel"))    { $File =  $File.Remove($File.Length - ".sel".Length)  }

        $RawFilePath      = Join-Path $LogDirectory ($File + ".sel.log")  
        $DecodedFilePath  = Join-Path $LogDirectory ($File + ".decoded.sel.log")  

        Remove-Item $RawFilePath      -ErrorAction SilentlyContinue -Force | Out-Null
        Remove-Item $DecodedFilePath  -ErrorAction SilentlyContinue -Force | Out-Null
                    
        If ($null -eq $SelEntries) { $SelEntries = Get-WcsSel }

        $SelEntries | ForEach-Object {
            Add-Content -Path  $RawFilePath        -Value $_.NoDecode
            Add-Content -Path  $DecodedFilePath    -Value $_.Decode
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

#-------------------------------------------------------------------------------------
# Clear-WcsSel
#-------------------------------------------------------------------------------------
Function Clear-WcsSel() {

   <#
  .SYNOPSIS
   Clears the BMC SEL  

  .DESCRIPTION
   Clears the BMC SEL then waits for the SEL erase to complete.

  .EXAMPLE
   Clear-WcsSel

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>

    [CmdletBinding()]

    Param( )
    
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Wait for SEL erase to complete
        #-------------------------------------------------------
        $SelEraseComplete = $False
        $TimeOut          = 30

        #-----------------------------------------------------------------
        # Need new reservation ID because clear SEL command cancels it
        #-----------------------------------------------------------------
        [byte []] $IpmiData = Invoke-WcsIpmi  0x42 @() $WCS_STORAGE_NETFN -ErrorAction Stop

        If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
        { 
            Throw ("Reserve SEL command returned completion code 0x{0:X2} {1}" -f $IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
        }
        $ReservationMSB = $IpmiData[2]
        $ReservationLSB = $IpmiData[1]

        #-----------------------------------------------------------------
        # Clear SEL command 
        #-----------------------------------------------------------------
        [byte []] $RequestData = @($ReservationLSB,$ReservationMSB,0X43,0X4C,0X52,0xAA)

        $IpmiData = Invoke-WcsIpmi  0x47 $RequestData  $WCS_STORAGE_NETFN -ErrorAction Stop
        
        If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
        { 
            Throw ("Clear SEL command returned completion code 0x{0:X2} {1}" -f $IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
        }
        #-----------------------------------------------------------------
        # Wait for clear to complete
        #-----------------------------------------------------------------
        For ($WaitTime = 0; $WaitTime -lt $TimeOut; $WaitTime++)
        {
            #-----------------------------------------------------------------
            # Need new reservation ID because clear SEL command cancels it
            #-----------------------------------------------------------------
            [byte []] $IpmiData = Invoke-WcsIpmi  0x42 @() $WCS_STORAGE_NETFN -ErrorAction Stop

            If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
            { 
                Throw ("Reserve SEL command returned completion code 0x{0:X2} {1}" -f $IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
            }
            $ReservationMSB = $IpmiData[2]
            $ReservationLSB = $IpmiData[1]

            #-----------------------------------------------------------------
            # Get SEL status
            #-----------------------------------------------------------------
            [byte []] $RequestData = @($ReservationLSB,$ReservationMSB,0X43,0X4C,0X52,0x00)

            $IpmiData = Invoke-WcsIpmi  0x47 $RequestData  $WCS_STORAGE_NETFN -ErrorAction Stop

            If ($IpmiData[0] -ne $IPMI_COMPLETION_CODE_NORMAL) 
            { 
                Throw ("Clear SEL command returned completion code 0x{0:X2} {1}" -f $IpmiData[0],(ipmiLib_DecodeCompletionCode $IpmiData[0]) )
            }
            If (($IpmiData[1] -band 0x0F) -eq 0x1) 
            {
                $SelEraseComplete = $true
                break 
            }
            #-----------------------------------------------------------------
            # Wait one second before trying again
            #-----------------------------------------------------------------
            Start-Sleep -Seconds 1

         }
         #-----------------------------------------------------------------
         # If failed to complete throw error
         #-----------------------------------------------------------------
         If (-NOT $SelEraseComplete) 
         {
            Throw "SEL erase did complete in $TimeOut seconds"
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

#-------------------------------------------------------------------------------------
# View-WcsSel
#-------------------------------------------------------------------------------------
Function View-WcsSel() {

   <#
  .SYNOPSIS
   Views the BMC SEL entries

  .DESCRIPTION
   Views the BMC SEL entries

  .EXAMPLE
   View-WcsSel

  .COMPONENT
   WCS

  .FUNCTIONALITY
   IPMI

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    ( 
        [switch]  $NoDecode, 
        [switch]  $HardwareError,
        [byte []] $RecordType = $Null,  
        [byte []] $SensorType = $null,  
        [byte []] $Sensor     = $null
    )
    
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation
        #-------------------------------------------------------
        # Get the entries
        #-------------------------------------------------------
        $SelEntries = @( Get-WcsSel -RecordType $RecordType -SensorType $SensorType -Sensor $Sensor -HardwareError:$HardwareError -ErrorAction Stop )

        If ($SelEntries.Count -eq 0 )
        {
            Write-Host " View-WcsSel found no entries in the SEL`r`n`r"
        }
        Else
        {
            $SelEntries| ForEach-Object {

                If ($NoDecode) { Write-Host ("{0}`r" -f $_.NoDecode) }
                Else           { Write-Host ("{0}`r" -f $_.Decode)   }
            }
        }
        Write-Host "`r"
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


#-----------------------------------------------------------------------------------------------------------------------
# Formats record type 0x02 into a readable (undecoded) string
#-----------------------------------------------------------------------------------------------------------------------
Function IpmiLib_FormatSensorRecordData($SelEntry) 
{
    $FormattedData = ''

    $FormattedData += ("GenID: {0:X4} EvMRev: {1:X2} "                  -f $SelEntry.GeneratorId,$SelEntry.EventMessageVersion)
    $FormattedData += ("SensorType: {0:X2} Sensor: {1:X2} "              -f $SelEntry.SensorType,$SelEntry.Sensor)
    $FormattedData += ("EventDirType: {0:X2} EventData(3-1): {1:X2} {2:X2} {3:X2} " -f $SelEntry.EventDirType,$SelEntry.EventData3,$SelEntry.EventData2,$SelEntry.EventData1)
    
    Write-Output $FormattedData
}

#-----------------------------------------------------------------------------------------------------------------------
# Converts the IPMI timestamp to a readable string of 23 characters
#
# See the Timestamp Format section of IPMI v2.0 specification for details
#-----------------------------------------------------------------------------------------------------------------------
Function IpmiLib_DecodeTimestamp([uint32] $TimeStamp)
{
    If ($TimeStamp -eq 0xFFFFFFFF) 
    {
        $DecodeTimeStamp = '[Invalid TimeStamp]'
    }
    ElseIf ($TimeStamp -le 0x20000000) 
    {
        $DecodeTimeStamp = ("[PreInit 0x{0:X8}sec]" -f $TimeStamp)
    }
    Else
    {
        $ConvertedDate   = (get-date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0).AddSeconds($Timestamp)
        $DecodeTimeStamp = ("[{0} {1}]" -f $ConvertedDate.ToShortDateString(),$ConvertedDate.ToLongTimeString())
    }

    Write-Output ("{0,-24}" -f $DecodeTimeStamp)
}
#-----------------------------------------------------------------------------------------------------------------------
# Generic decode of IPMI SEL entries
#
# See the IPMI v2.0 specification for details
#-----------------------------------------------------------------------------------------------------------------------
Function IpmiLib_DecodeSelEntry([ref] $SelEntry) 
{
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
                # Sensor Type 01h - Temperature Sensor
                #----------------------------------------------------
                0x01
                {
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'System'

                    Switch ($SelEntry.Value.EventDirType)
                    {
                        0x01    {  $SelEntry.Value.Event = 'Temperature exceeded threshold.' ; break }
                        0x81    {  $SelEntry.Value.Event = 'Temperature within threshold.'   ; break }
                        Default {  $SelEntry.Value.Event = 'Temperature event.' }
                    }
                    $SelEntry.Value.Decode   += ("{0} Sensor {1:X2} EvtData(3-1) 0x{2:X2}{3:X2}{4:X2}" -f $SelEntry.Value.Event,$SelEntry.Value.Sensor,$SelEntry.Value.EventData3,`
                                                                                                                $SelEntry.Value.EventData2, $SelEntry.Value.EventData1)
                }
                #----------------------------------------------------
                # Sensor Type 02h - Voltage Sensor
                #----------------------------------------------------
                0x02
                {
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'BOARD'

                    Switch ($SelEntry.Value.EventDirType)
                    {
                        0x01    {  $SelEntry.Value.Event = 'Voltage exceeded threshold.' ; break }
                        0x81    {  $SelEntry.Value.Event = 'Voltage within threshold.'   ; break }
                        Default {  $SelEntry.Value.Event = 'Voltage event.' }
                    }
                    $SelEntry.Value.Decode   += ("{0} Sensor {1:X2} EvtData(3-1) 0x{2:X2}{3:X2}{4:X2}" -f $SelEntry.Value.Event,$SelEntry.Value.Sensor,$SelEntry.Value.EventData3,`
                                                                                                                $SelEntry.Value.EventData2, $SelEntry.Value.EventData1)
                }
                #----------------------------------------------------
                # Sensor Type 07h - Processor Sensor
                #----------------------------------------------------
                0x07
                {
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'Processor'

                    Switch (($SelEntry.Value.EventData1 -band 0x0F))
                    {
                        0       { $SelEntry.Value.Event   = 'IERR'         ; break }
                        1       { $SelEntry.Value.Event   = 'Thermal Trip' ; break } 
                        2       { $SelEntry.Value.Event   = 'FRB1'         ; break } 
                        3       { $SelEntry.Value.Event   = 'FRB2'         ; break } 
                        4       { $SelEntry.Value.Event   = 'FRB3'         ; break } 
                        5       { $SelEntry.Value.Event   = 'Configuration Error'         ; break } 
                        6       { $SelEntry.Value.Event   = 'SMBIOS Uncorrectable Error'   ; break } 
                        7       { $SelEntry.Value.Event   = 'Presence detected'            ; $SelEntry.Value.HardwareError = $false ;  break } 
                        8       { $SelEntry.Value.Event   = 'Processor disabled'           ; break } 
                        9       { $SelEntry.Value.Event   = 'Terminator presence detected' ; $SelEntry.Value.HardwareError = $false ; break } 
                        0xA     { $SelEntry.Value.Event   = 'Automatically Throttled'      ; break } 
                        0xB     { $SelEntry.Value.Event   = 'Uncorrectable machine check'  ; break } 
                        0xC     { $SelEntry.Value.Event   = 'Correctable machine check'    ; break } 

                        Default { $SelEntry.Value.Event   = 'Processor event' }
                    }   
                    $SelEntry.Value.Decode   += ("{0} Sensor {1:X2} EvtData(3-1) 0x{2:X2}{3:X2}{4:X2}" -f $SelEntry.Value.Event,$SelEntry.Value.Sensor,$SelEntry.Value.EventData3,`
                                                                                                                $SelEntry.Value.EventData2, $SelEntry.Value.EventData1)                     
                }
                #----------------------------------------------------
                # Sensor Type 0Ch - Memory Sensor
                #----------------------------------------------------
                0x0C
                {
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'DIMM'

                    Switch (($SelEntry.Value.EventData1 -band 0x0F))
                    {
                        0x0       { $SelEntry.Value.Event   = 'Correctable ECC'               ; break }
                        0x1       { $SelEntry.Value.Event   = 'Uncorrectable ECC'             ; break } 
                        0x5       { $SelEntry.Value.Event   = 'Correctable ECC Limit Reached' ; break } 
                        Default   { $SelEntry.Value.Event   = 'Memory event' }
                    }
                    $SelEntry.Value.Decode   += ("{0} Sensor {1:X2} EvtData(3-1) 0x{2:X2}{3:X2}{4:X2}" -f $SelEntry.Value.Event,$SelEntry.Value.Sensor,$SelEntry.Value.EventData3,`
                                                                                                                $SelEntry.Value.EventData2, $SelEntry.Value.EventData1)
                }
                #---------------------------------------------------------
                # Sensor Type 0Fh - System Firmware Progress (POST error)
                #---------------------------------------------------------
                0x0F
                { 
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'System'

                    $SelEntry.Value.Event   = ("POST error EvtData(3-1) 0x{0:X2}{1:X2}{2:X2}" -f $SelEntry.Value.EventData3, $SelEntry.Value.EventData2, $SelEntry.Value.EventData1)
                         
                    $SelEntry.Value.Decode   += $SelEntry.Value.Event                               
                }
                #----------------------------------------------------
                # Sensor Type 10h - Event logging disabled
                #----------------------------------------------------
                0x10
                { 
                    Switch (($SelEntry.Value.EventData1 -band 0x0F))
                    {
                        0       { $SelEntry.Value.Event   = ("Correctable memory logging disabled on DIMM {0}" -f $SelEntry.Value.EventData1)   ; break }
                        1       { $SelEntry.Value.Event   = ("Event logging disabled for specific type.  EvtData2 {0] EvtData3 {1}" -f $SelEntry.Value.EventData2, $SelEntry.Value.EventData3); break } 
                        2       { $SelEntry.Value.Event   = 'SEL cleared'                         ; break } 
                        3       { $SelEntry.Value.Event   = 'Event logging disabled'              ; break } 
                        4       { $SelEntry.Value.Event   = 'SEL full'                            ; break } 
                        5       { $SelEntry.Value.Event   = ("SEL almost full.  EvtData3 {0}" -f $SelEntry.Value.EventData3)                             ; break } 
                        6       { $SelEntry.Value.Event   = ("Correctable Machine Check logging disabled.  EvtData2 {0] EvtData3 {1}" -f $SelEntry.Value.EventData2, $SelEntry.Value.EventData3);  ; break } 

                        Default { $SelEntry.Value.Event   = 'Event logging disabled' }
                    }        
                    $SelEntry.Value.Decode   += $SelEntry.Value.Event                               
                }
                #----------------------------------------------------
                # Sensor Type 13h - Critical Interupt
                #----------------------------------------------------
                0x13
                { 
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'Board/Adapter'

                    Switch (($SelEntry.Value.EventData1 -band 0x0F))
                    {
                                0x5       { $SelEntry.Value.Event   = 'PCI PERR'                 ; break }
                                0x5       { $SelEntry.Value.Event   = 'PCI SERR'                 ; break } 
                                0x7       { $SelEntry.Value.Event   = 'Correctable bus error'    ; break } 
                                0x8       { $SelEntry.Value.Event   = 'Uncorrectable bus error'  ; break } 
                                0xA       { $SelEntry.Value.Event   = 'Fatal bus error'          ; break } 
                                Default   { $SelEntry.Value.Event   = 'Critical interrupt' }
                    }

                    $SelEntry.Value.Decode   += ("{0} Sensor {1:X2} EvtData(3-1) 0x{2:X2}{3:X2}{4:X2}" -f $SelEntry.Value.Event,$SelEntry.Value.Sensor,$SelEntry.Value.EventData3,`
                                                                                                                $SelEntry.Value.EventData2, $SelEntry.Value.EventData1)                            
                }
                #----------------------------------------------------
                # Sensor Type 19h - Chipset
                #----------------------------------------------------
                0x19
                { 
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'Board'

                    Switch (($SelEntry.Value.EventData1 -band 0x0F))
                    {
                                0x1       { $SelEntry.Value.Event   = 'Chipset Thermal Trip'       ; break }
                                Default   { $SelEntry.Value.Event   = 'Chipset Soft Power Control Failure' }
                    }

                    $SelEntry.Value.Decode   += ("{0} Sensor {1:X2} EvtData(3-1) 0x{2:X2}{3:X2}{4:X2}" -f $SelEntry.Value.Event,$SelEntry.Value.Sensor,$SelEntry.Value.EventData3,`
                                                                                                                $SelEntry.Value.EventData2, $SelEntry.Value.EventData1)                            
                }
                #----------------------------------------------------
                # Sensor Type 1Fh - Base OS Boot/Installation  
                #----------------------------------------------------
                0x1F
                {
                    Switch (($SelEntry.Value.EventData1 -band 0x0F))
                    {
                        0       { $SelEntry.Value.Event   = 'A: boot complete'                       ; break }
                        1       { $SelEntry.Value.Event   = 'C: boot complete'                       ; break }
                        2       { $SelEntry.Value.Event   = 'PXE boot complete'                      ; break }
                        3       { $SelEntry.Value.Event   = 'Diagnostic boot complete'               ; break } 
                        4       { $SelEntry.Value.Event   = 'CD-ROM boot complete'                   ; break } 
                        5       { $SelEntry.Value.Event   = 'ROM boot complete'                      ; break } 
                        6       { $SelEntry.Value.Event   = 'Base OS boot complete'                  ; break } 
                        7       { $SelEntry.Value.Event   = 'Base OS/Hypervisor install started'     ; break } 
                        8       { $SelEntry.Value.Event   = 'Base OS/Hypervisor install completed'   ; break } 
                        9       { $SelEntry.Value.Event   = 'Base OS/Hypervisor install aborted'     ; break } 
                        0xA     { $SelEntry.Value.Event   = 'Base OS/Hypervisor install failed'      ; break } 

                        Default { $SelEntry.Value.Event   = 'Base OS Boot/Installation status' }
                    }   
                    $SelEntry.Value.Decode   += $SelEntry.Value.Event                                           
                }
                #----------------------------------------------------
                # Sensor Type 20h - OS Stop/Shutdown
                #----------------------------------------------------
                0x20
                {
                    Switch (($SelEntry.Value.EventData1 -band 0x0F))
                    {
                        0       { $SelEntry.Value.Event   = 'OS critical stop during OS load'           ; break }
                        1       { $SelEntry.Value.Event   = 'OS run-time critical stop'                 ; break }
                        2       { $SelEntry.Value.Event   = 'OS graceful stop'                          ; break }
                        3       { $SelEntry.Value.Event   = 'OS graceful shutdown'                      ; break } 
                        4       { $SelEntry.Value.Event   = 'OS Stop/Shutdown | Soft shutdown by PEF'   ; break } 
                        5       { $SelEntry.Value.Event   = 'OS Stop/Shutdown | Agent not responding'   ; break } 

                        Default { $SelEntry.Value.Event   = 'OS Stop/Shutdown' }
                    }     
                    $SelEntry.Value.Decode   += $SelEntry.Value.Event                                         
                }  
                #----------------------------------------------------
                # Sensor Type 23h - Watchdog timer
                #----------------------------------------------------
                0x23
                {
                    $SelEntry.Value.HardwareError = $true
                    $SelEntry.Value.Location      = 'System'

                    Switch (($SelEntry.Value.EventData2 -band 0x0F))
                    {

                        1       { $SelEntry.Value.Event   = 'BIOS FRB2 watchdog timeout'                ; break }
                        2       { $SelEntry.Value.Event   = 'BIOS POST watchdog timeout'                ; break }
                        3       { $SelEntry.Value.Event   = 'OS load watchdog timeout'                  ; break } 
                        4       { $SelEntry.Value.Event   = 'OS/SMS watchdog timeout'                   ; break } 
                        5       { $SelEntry.Value.Event   = 'OEM watchdog timeout'                      ; break } 

                        Default { $SelEntry.Value.Event   = 'Watchdog timeout' }
                    }     
                    $SelEntry.Value.Decode   += $SelEntry.Value.Event                                         
                }                     
                #----------------------------------------------------
                # Decode all other sensor types
                #----------------------------------------------------            
                Default
                {
                      $SelEntry.Value.Decode   += IpmiLib_FormatSensorRecordData $SelEntry.Value 
                }
            }
        }
        #----------------------------------------------------
        # Decode OEM timestamp record type
        #----------------------------------------------------
        ElseIf (($SelEntry.Value.RecordType -ge 0xC0) -and ($SelEntry.Value.RecordType -le 0xDF))
        {
            $SelEntry.Value.Decode   += $SelEntry.Value.NoDecode
        }
        #----------------------------------------------------
        # Decode OEM non-timestamp record type
        #----------------------------------------------------
        ElseIf (($SelEntry.Value.RecordType -ge 0xE0) -and ($SelEntry.Value.RecordType -le 0xFF))
        {
            $SelEntry.Value.Decode   += $SelEntry.Value.NoDecode
        }
        #----------------------------------------------------
        # Decode illegal type
        #----------------------------------------------------
        Else
        {
            $SelEntry.Value.Decode = $SelEntry.Value.NoDecode
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
#  This function gets BMC version information
#----------------------------------------------------------------------------------------------
Function IpmiLib_GetBmcVersion()
{
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (   
 
    )

    Try
    {
        Write-Debug "IpmiLib_GetBmcVersion called"

        [byte []] $RequestData = @()
            
        $IpmiData = Invoke-WcsIpmi  0x1 $RequestData $WCS_APP_NETFN -ErrorAction Stop

        If (0 -ne $IpmiData[0])
        {
            Throw  
        }

        Write-Output ("{0}.{1:00}" -f ($IpmiData[3] -band 0x7F),$IpmiData[4])

    }
    Catch
    {
        Write-Output $WCS_NOT_AVAILABLE

    }
}
#----------------------------------------------------------------------------------------------
#  This function gets the CPLD version information
#----------------------------------------------------------------------------------------------
Function IpmiLib_GetCpldVersion()
{
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (   
 
    )

    Try
    {
        [byte []] $RequestData = @(3)

        $ipmiData = Invoke-WcsIpmi  0x17 $RequestData $WCS_OEM_NETFN -ErrorAction Stop
        
        If (0 -ne $IpmiData[0])
        {
            Throw  
        }

        $CpldVersion = ("{0:X2}{1:X2}" -f $ipmiData[2],$ipmiData[1])
 
        Write-Output $CpldVersion

    }
    Catch
    {
        Write-Output $WCS_NOT_AVAILABLE
    }
}
#----------------------------------------------------------------------------------------------
#  This function gets BMC FRU version information
#----------------------------------------------------------------------------------------------
Function IpmiLib_GetBmcFruVersion()
{
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (   
 
    )

    Try
    {
        [byte []] $RequestData = @(0,87,0,12)
            
        $ipmiData = Invoke-WcsIpmi  0x11 $RequestData $WCS_STORAGE_NETFN  -ErrorAction Stop
        
        If (0 -ne $IpmiData[0])
        {
            Throw  
        }

        $FruVersion = ""

        For ($Loop=2; $Loop -lt 12; $Loop++)
        {
            $FruVersion += [char] $ipmiData[$Loop]
        }
        Write-Output $FruVersion
    }
    Catch
    {
        Write-Output $WCS_NOT_AVAILABLE

    }
}
#----------------------------------------------------------------------------------------------
#  Helper function for getting a FRU field
#----------------------------------------------------------------------------------------------
Function IpmiLib_GetFruStringField($Start, $FruAsBytes, $FruAsString, $CheckLength=-1, [switch] $AllowC1)
{
    $Field  = $WCS_NOT_AVAILABLE
    $Length = $FruAsBytes[($Start -1)] -band  0x3F
    $Type   = $FruAsBytes[($Start -1)] -band  0xC0

    If ($Type -ne 0xC0) 
    { 
       Throw ("FRU FORMAT ERROR: Field type/length code at offset {0} (0x{0:X2}) is invalid: {1} (0x{1:X2})" -f ($Start -1), $FruAsBytes[($Start -1)])
    }
    If (($Length -eq 1) -and (-NOT $AllowC1)) 
    { 
       Throw ("FRU FORMAT ERROR: Unexpected end of field found at offset {0} (0x{0:X2})" -f ($Start -1))
    }
    
    If (($CheckLength -ne -1) -and ($CheckLength -ne $Length))
    {
        $Field  = $WCS_NOT_AVAILABLE
    }
    ElseIf  ($Length -ne 0)  
    { 
       $Field  = $FruAsString.Substring($Start,$Length)
    }   
    Else
    {
        $Field  = $WCS_NOT_AVAILABLE
    } 
    Write-Output @{Length=$Length;Field=$Field}
}
#----------------------------------------------------------------------------------------------
#  This function gets BMC FRU version information
#----------------------------------------------------------------------------------------------
Function IpmiLib_GetBmcFru()
{
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (   
 
    )

    $BmcFru = $WCS_COMPUTE_BLADE_FRU_OBJECT.Clone()

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        $FruAsBytes   = @()
        $FruAsString  = "" 
        $ReadLength   = 16

        #--------------------
        # Read the entire FRU 
        #-------------------------
        $FruAsBytes = Get-WcsFruData -ErrorAction Stop

        #------------------------------------------------------------------------------------------
        # Create a string of characters for human readable info.  If not a char replace with space
        #------------------------------------------------------------------------------------------
        $FruAsBytes | ForEach-Object { 
        
            If ( $_ -as [char] )
            {
                $ThisChar = ([char] $_)
            }
            Else
            {
                $ThisChar = ([char] ' ')
            }

            $FruAsString += $ThisChar
        }

        #-----------------------------------------------------------------------------------
        # Get the board fields since it contains the FRU version (same for all versions)
        #-----------------------------------------------------------------------------------
        $Start               = 8*$FruAsBytes[3] + 3
        $Length              = 3        
        $BmcFru.BoardMinutes = $FruAsBytes[$Start] + 0x100 * $FruAsBytes[($Start+1)] + 0x10000 * $FruAsBytes[($Start+2)]       
        $BmcFru.BoardMfgDate = (get-date -Year 1996 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0).AddMinutes($BmcFru.BoardMinutes)

        $Start                    = 8*$FruAsBytes[3] + 7

        $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
        $Start                   += $Info.Length+1
        $BmcFru.BoardManufacturer = $Info.Field

        $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
        $Start                   += $Info.Length+1
        $BmcFru.BoardName         = $Info.Field

        $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString  11     # unique field, verify 11 char long
        $Start                   += $Info.Length+1
        $BmcFru.BoardSerial       = $Info.Field

        $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
        $Start                   += $Info.Length+1
        $BmcFru.BoardPartNumber   = $Info.Field

        $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
        $Start                   += $Info.Length+1
        $BmcFru.BoardFruFileId    = $Info.Field

        #----------------------------------------------------------------
        # Get the chassis info fields (New fields for version 0.04)
        #----------------------------------------------------------------
        $Start                    = 8*$FruAsBytes[2] + 4
        $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
        $Start                   += $Info.Length+1
        $BmcFru.ChassisPartNumber = $Info.Field


        Try
        {
            #------------------------------------------------
            # The following fields do not exist in v0.01
            #------------------------------------------------
            If ($BmcFru.BoardFruFileId -ne 'FRU v0.01')
            {
                $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString 13    # unique field, verify 13 char longld
                $Start                   += $Info.Length+1
                $BmcFru.ChassisSerial     = $Info.Field

                $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString  
                $Start                   += $Info.Length+1
                $BmcFru.ChassisCustom1    = $Info.Field

                $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString -AllowC1
                $Start                   += $Info.Length+1
                $BmcFru.ChassisCustom2    = $Info.Field
           }
        }
        Catch
        {
            If ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Yellow ("{0}`r" -f  $_ ) }
        }
        #----------------------------------------------------------------
        # Get the product info fields
        #----------------------------------------------------------------
        $Start                       = 8*$FruAsBytes[4] + 4

        $Info                        = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
        $Start                      += $Info.Length+1
        $BmcFru.ProductManufacturer  = $Info.Field

        Try
        {

            $Info                        = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
            $Start                      += $Info.Length+1
            $BmcFru.ProductName          = $Info.Field
         
            $Info                        = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
            $Start                      += $Info.Length+1
            $BmcFru.ProductModel         = $Info.Field
         
            $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString  -AllowC1
            $Start                   += $Info.Length+1
            $BmcFru.ProductVersion    = $Info.Field
         
            $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString 13 # unique field, verify 13 char long
            $Start                   += $Info.Length+1
            $BmcFru.ProductSerial        = $Info.Field

            $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString 7   # unique field, verify 7 char long
            $Start                   += $Info.Length+1
            $BmcFru.ProductAsset      = $Info.Field

            $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString -AllowC1
            $Start                   += $Info.Length+1
            $BmcFru.ProductFruFileId  = $Info.Field

            #------------------------------------------------
            # The following fields do not exist in v0.01
            #------------------------------------------------
            If ($BmcFru.BoardFruFileId -ne 'FRU v0.01')
            {
                $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString -AllowC1
                $Start                   += $Info.Length+1
                $BmcFru.ProductCustom1    = $Info.Field

                $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString
                $Start                   += $Info.Length+1
                $BmcFru.ProductCustom2    = $Info.Field

                $Info                     = IpmiLib_GetFruStringField $Start $FruAsBytes $FruAsString  3            # unique field, verify 3 char long
                $Start                   += $Info.Length+1
                $BmcFru.ProductCustom3    = $Info.Field
            }
     
     }
     Catch
     {
        If ($ErrorActionPreference -ne 'SilentlyContinue') { Write-Host -ForegroundColor Yellow ("{0}`r" -f  $_ ) }
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
    Write-Output $BmcFru
}


#----------------------------------------------------------------------------------------------
#  This function cycles power
#----------------------------------------------------------------------------------------------
Function Cycle-WcsPower()
{
    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #Set Interval to 30 seconds
                    
        [byte []] $RequestData = @(0x1E)
        
        $IpmiData = Invoke-WcsIpmi  0xB $RequestData $WCS_CHASSIS_NETFN -ErrorAction Stop

        If (0 -ne $IpmiData[0])
        {
            Throw ("Set Interval command returned IPMI completion code: {0} {1} " -f $IpmiData[0],(IpmiLib_DecodeCompletionCode $IpmiData[0]))
        }

        #Cycle power

        [byte []] $RequestData = @(0x2)

        $IpmiData = Invoke-WcsIpmi  0x2 $RequestData $WCS_CHASSIS_NETFN -ErrorAction Stop

        If (0 -ne $IpmiData[0])
        {
            Throw ("Power cycle command returned IPMI completion code: {0} {1} " -f $IpmiData[0],(IpmiLib_DecodeCompletionCode $IpmiData[0]))
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
#  This function adds sel entries for ECC errors - Under development
#----------------------------------------------------------------------------------------------
Function IpmiLib_AddEccErrors()
{
    Try
    {
        #---------------------------------------
        # Add correctable and uncorrectable ECC 
        #---------------------------------------
        For ($Dimm=1;$Dimm -le 12; $Dimm++)
        {
            [byte[]]$RequestData = @(0,0,2, 0,0,0,0, 0,1,4,  0x0C,0x87,0x6F, 0xA0,0,$Dimm)
           
            $IpmiData = Invoke-WcsIpmi  0x44 $RequestData $WCS_STORAGE_NETFN 

            [byte[]]$RequestData = @(0,0,2, 0,0,0,0, 0,1,4,  0x0C,0x87,0x6F, 0xA1,0,$Dimm)
           
            $IpmiData = Invoke-WcsIpmi  0x44 $RequestData $WCS_STORAGE_NETFN 
        }

        Write-Output 0

    }
    Catch
    {
        Write-Output 1
    }
}
#----------------------------------------------------------------------------------------------
# Helper function to merge fields into FRU data
#----------------------------------------------------------------------------------------------
Function MergeFruField([byte[]]$FruData,[int]$Offset,[string] $Field)
{
    for ($Index=0;$Index -lt $Field.Length; $Index++)
    {
        $FruData[($Offset+$Index)] = [byte] $Field[$Index]
    }
    Write-Output $FruData

}
#----------------------------------------------------------------------------------------------
# Helper function that turns on attention LED on blade
#----------------------------------------------------------------------------------------------
Function IpmiLib_ChassisIdentifyOn()
{
    [CmdletBinding()]

    Param( )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Turn the LED on
        #-------------------------------------------------------           
        $IpmiData = Invoke-WcsIpmi  0x4  @(0,1) $WCS_CHASSIS_NETFN 

        If (0 -ne $IpmiData[0])
        {
            Throw ("Returned IPMI completion code: {0} {1} " -f $IpmiData[0],(IpmiLib_DecodeCompletionCode $IpmiData[0]))
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
# Helper function that turns off attention LED on blade
#----------------------------------------------------------------------------------------------
Function IpmiLib_ChassisIdentifyOff()
{
    [CmdletBinding()]

    Param( )

    Try
    {
        #-------------------------------------------------------
        # Get calling details for debug
        #-------------------------------------------------------
        $FunctionInfo = CoreLib_FormatFunctionInfo $MyInvocation

        #-------------------------------------------------------
        # Turn the LED off
        #-------------------------------------------------------            
        $IpmiData = Invoke-WcsIpmi  0x4 @(0,0) $WCS_CHASSIS_NETFN 
        
        If (0 -ne $IpmiData[0])
        {
            Throw ("Returned IPMI completion code: {0} {1} " -f $IpmiData[0],(IpmiLib_DecodeCompletionCode $IpmiData[0]))
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

