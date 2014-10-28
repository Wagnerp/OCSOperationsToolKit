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


#-------------------------------------------------------------------
#  Declare Alias
#-------------------------------------------------------------------
Set-Alias -Name wcsrest   -Value Invoke-WcsRest
  
#-----------------------------------------------------------------------------------------------------
# This code allows async callbacks to work with SSL.  To ignore the bad certificate from the chassis
# manager need to implement a dummy method but this method needs its own run space
#-----------------------------------------------------------------------------------------------------
if (-not ("CallbackEventBridge" -as [type])) {        

    
        Add-Type @"
            using System;
            using System.Net.Security;
            using System.Security.Cryptography.X509Certificates;

            public sealed class CallbackEventBridge
            {
                private CallbackEventBridge() {}
 
                private bool CallbackInternal(Object sender,X509Certificate certificate,X509Chain chain,SslPolicyErrors sslPolicyErrors )
                {
                    return true;
                }
 
                public RemoteCertificateValidationCallback Callback
                {
                    get { return new RemoteCertificateValidationCallback(CallbackInternal); }
                }
 
                public static CallbackEventBridge Create()
                {
                    return new CallbackEventBridge();
                }
            }
"@
 
}
$bridge = [callbackeventbridge]::create()
    
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $bridge.callback
#-----------------------------------------------------------------------------------
# Invoke-WcsRest 
#-----------------------------------------------------------------------------------
Function Invoke-WcsRest()
{
   <#
  .SYNOPSIS
   Invokes a WCS chassis manager REST command 

  .DESCRIPTION
   Invokes a WCS chassis manager REST command.  Specify one or more chassis managers
   as targets.  Can use localhost for local chassis manager

   Returns array of xml objects where each xml object is the response from one 
   chassis manager

   Uses the global chassis manager credentials which can be specified with the 
   Set-WcsChassisCredential command
 
  .EXAMPLE
   Invoke-WcsRest 'GetChassisInfo?bladeinfo=true&psuInfo=true&chassisInfo=true&batteryInfo=true'  LocalHost 

   Gets the chassis info on the local chassis manager

  .EXAMPLE
   Invoke-WcsRest 'GetServiceVersion' -TargetList @(192.168.200.10, 192.168.200.11) -SSL

   Gets the chassis manager service version on the chassis managers at 192.168.200.10 and 192.168.200.11.
   Uses SSL and reads the chassis managers one at a time

  .EXAMPLE
   Invoke-WcsRest 'GetServiceVersion' -TargetList @(192.168.200.10, 192.168.200.11) -Asynchronous -TimeOutInMs 10000

   Gets the chassis manager service version on the chassis managers at 192.168.200.10 and 192.168.200.11.
   Reads both concurrently and waits 10 seconds for them to respond

  .PARAMETER Command
   REST command to run.

  .PARAMETER TargetList
   List of remote targets either as a single IP address or array of IP addresses. Examples:

   192.168.200.10
   @(192.168.200.10, 192.168.200.11)

  .PARAMETER TimeOutInMs
   Time in mS to wait for the chassis manager to respond

   .PARAMETER SSL
   If specified uses SSL 

   .PARAMETER Asynchronous
   If specifed executes REST command concurrently to all chassis managers

  .OUTPUTS
   Array of responses where a successful response is an XML object and unsuccessful
   response is $null

  .COMPONENT
   WCS

  .FUNCTIONALITY
   Comm

   #>
    
    [CmdletBinding(PositionalBinding=$false)]

    Param
    (
        [Parameter(Mandatory=$true,Position=0)]    [string]    $Command,
        [Parameter(Mandatory=$true,Position=1)]    [array]     $TargetList,
        [Parameter(Mandatory=$false)]              [int]       $TimeoutInMs=30000,
                                                   [switch]    $SSL,
                                                   [switch]    $Asynchronous
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
        $webClient                = @()
        $ProcessedChassisManagers = @()
        $URI                      = "N/A"
        $Credentials              = $Global:ChassisManagerCredential

        $SyncResults              = @()
        $Targets                  = GetTargets $TargetList $true $SSL
        #-------------------------------------------------------
        # Process each chassis manager (Target)
        #-------------------------------------------------------
        ForEach ($ChassisManager in $Targets) {

            $ProcessedChassisManagers += $ChassisManager
 
            #-----------------------------------------------------------------------------------
            # Assembly the URI
            #-----------------------------------------------------------------------------------
            $URI = "${ChassisManager}:8000/$Command"

            #-----------------------------------------------------------------------------------
            # Synchronous read using WebRequest
            #-----------------------------------------------------------------------------------
            if (-NOT $Asynchronous)
            {
                Write-Verbose "Synchronous request: $URI`r"

                $req = [System.Net.WebRequest]::Create($URI)

                $req.Method           = "GET"
                $req.ContentLength    = 0
                $req.Timeout          = $TimeoutInMs
                $req.PreAuthenticate  = $true
                $req.Credentials      = $Credentials
                $req.CachePolicy      = ([System.Net.Cache.HttpRequestCachePolicy] [System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore)
                # $req.UseDefaultCredentials = $true
                #-----------------------------------------------------------------------------------
                # If ignore timeout then ignore timeout failures
                #-----------------------------------------------------------------------------------
                Try
                {
                    $FoundResult = $true
                    $resp = $req.GetResponse()
                }
                Catch
                {
                    $FoundResult = $false
                }

                If ($FoundResult -eq $false)
                {
                    If ($ErrorActionPreference -ne "SilentlyContinue")
                    {
                        Write-Host  "Command to '$ChassisManager' failed: '$URI'`r"
                    }
                    $SyncResults +=  $null
                }
                Else
                {
                    #-----------------------------------------------------------------------------------
                    # Read the response then return it
                    #-----------------------------------------------------------------------------------
                    $reader      = new-object System.IO.StreamReader($resp.GetResponseStream())
                    $xmlResponse = [xml] $reader.ReadToEnd()

                    Write-Verbose "Synchronous read of $URI returned response`r"

                    $SyncResults += $xmlResponse
                }
            }
            #-----------------------------------------------------------------------------------
            # Asynchronous read using WebClient
            #-----------------------------------------------------------------------------------
            else
            {
                Write-Verbose "Asynchronous request: $URI`r"
                #-----------------------------------------------------------------------------------
                # Asynchronous read.  First thing clear any old events
                #-----------------------------------------------------------------------------------
                $PipelineCount = $WebClient.Count
                Unregister-Event -SourceIdentifier  "wcsreset$PipelineCount"   -ErrorAction "SilentlyContinue"
                Get-Event        -SourceIdentifier  "wcsreset$PipelineCount"   -Erroraction "SilentlyContinue" | Remove-Event
                #-----------------------------------------------------------------------------------
                # Create new web client and enter credentials
                #-----------------------------------------------------------------------------------
                $webClient                             += New-Object System.Net.WebClient
                $webClient[$PipelineCount].credentials  = $Global:ChassisManagerCredential
                #-----------------------------------------------------------------------------------
                # Register event and start async read
                #-----------------------------------------------------------------------------------
                Write-Verbose "Registering event wcsreset$PipelineCount`r"

                Register-ObjectEvent -InputObject $webClient[$PipelineCount] -EventName OpenReadCompleted -SourceIdentifier "wcsreset$PipelineCount"

                $webClient[$PipelineCount].OpenReadAsync($URI)
            }
        }
        #-----------------------------------------------------------------------------------
        # If Asynchronous then read the results
        #-----------------------------------------------------------------------------------
        if ($Asynchronous)
        {
            $AsyncResults = @()
            $TimeWaiting  = 0
            $WaitStep     = 50  # Poll every 50mS
            #-----------------------------------------------------------------------------------
            # Check each chassis manager 
            #-----------------------------------------------------------------------------------
            For ($PipelineCount=0;$PipelineCount -lt $WebClient.Count; $PipelineCount++)  {

                $ChassisManager = $ProcessedChassisManagers[$PipelineCount]

                Write-Verbose  "Getting request from Chassis: $ChassisManager`r"

                $Event = $null
                #-----------------------------------------------------------------------------------
                # Wait for event that read has completed up to TimeoutInMs
                #-----------------------------------------------------------------------------------
                while ($null -eq $Event)
                {
                    $Event = Get-Event -SourceIdentifier "wcsreset$PipelineCount"  -ErrorAction "SilentlyContinue"

                    if ($null -eq $Event)
                    {
                        if ($TimeWaiting -gt $TimeoutInMs) 
                        {
                            If ($ErrorActionPreference -ne "SilentlyContinue")
                            {
                                Write-Host "Command to '$ChassisManager' failed: '$URI'`r"
                                Write-Host ("Timed out before getting event wcsreset$PipelineCount`r" )        
                            }
                            break 
                        }
                        Start-Sleep -Milliseconds $WaitStep 
                        $TimeWaiting += $WaitStep 
                    }
                    else
                    {                            
                        If ($null -ne $Event.SourceArgs[1].Result)
                        {
                            Write-Verbose ("Found event wcsreset$PipelineCount response`r" ) 
                              
                            [system.io.stream]          $Response = $Event.SourceArgs[1].Result 
                            [system.io.StreamReader]    $Reader   = New-Object system.io.StreamReader($Response)

                            $AsyncResults += ([xml] $Reader.ReadToEnd())
                        
                            $Reader.Close() | Out-Null
                            $Response.Close | Out-Null
                        }
                        Else
                        {
                            Write-Verbose ("Found event wcsreset$PipelineCount NO response`r" )   
                            $AsyncResults += $null
                        }

                        $webClient[$PipelineCount].Dispose() | Out-Null
 
                        break
                    }
 
                } #while

                if ($null -eq $Event) 
                {
                    $AsyncResults += $null 
                }
            }
            Return $AsyncResults
        } #if
        Else
        {
            Return $SyncResults
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
