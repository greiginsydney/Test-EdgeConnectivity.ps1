<#
.SYNOPSIS
	This script attempts a TCP connection to all the Edge servers found in the topology, as
		well as a TURN test to UDP 3478.
	It reports the results to screen and a file.

.DESCRIPTION
	This script queries the SfB topology and then probes all the Edge servers it finds on all the TCP ports
	that should be open, plus UDP3478. It reports the results to screen and a file.
	You can filter the servers it queries with the '-Site' or '-TargetFqdn' switches.
	Override the default ports by adding the '-Port' switch and a comma- or space-separated list of ports.

.NOTES
    Version				: 1.2
	Date				: TBA 2019
	Author    			: Greig Sheridan
	Lync/SfB version	: SfB 2015, 2019

	Revision History:
					v1.2 7th August 2019
						- Added 'TCP' and 'UDP' headers to the output object
						- Added previously excluded CLS ports 50002 & 50003
						- Added new '-ports' switch to let you specify one or more ports, overriding the defaults
							(All port numbers except 3478 will be treated as TCP)
						- Moved "$udpClient.Send" line inside the Try so invalid FQDNs don't spray red on screen

					v1.1 4th April 2019
						- Added Frank Carius' UDP3478 test. Thank you Frank!
						- Added '-TargetFqdn' switch to force a test to a single machine - or a list. (Thanks Naimesh!)
						- Added write-progress to the port tests so you can see when it's stuck on a bad port

					v1.0 9th December 2018
						- Initial release.


.LINK
    https://greiginsydney.com/Test-EdgeConnectivity.ps1

.EXAMPLE
	.\Test-EdgeConnectivity.ps1

	Description
	-----------
	Queries the SfB topology and then probes *all* the Edge servers it finds, on all the TCP ports
	that should be open: TCP 443, 4443, 5061, 5062, 8057, 50001, 50002, 50003 and UDP 3478.


.EXAMPLE
	.\Test-EdgeConnectivity.ps1 -Site AU

	Description
	-----------
	In this example, the script will only test Edge servers in the "Site:AU" site.
	(TargetFqdn & Site are mutually exclusive.)

.EXAMPLE
	.\Test-EdgeConnectivity.ps1 -TargetFqdn MyEdgeserver.domain.com

	Description
	-----------
	In this example, the script will only test to the single nominated Edge server.
	(TargetFqdn & Site are mutually exclusive.)

.EXAMPLE
	.\Test-EdgeConnectivity.ps1 | ft

	Description
	-----------
	Displays the output in tabular format (much like the CSV file)


.PARAMETER Site
	String. A site name to filter by. Valid with or without the "Site:" prefix.
	Only includes Edge servers in the named Topology site.

.PARAMETER TargetFqdn
	String. One or more server FQDNs to test. By providing this parameter you skip the Topo/Site query.

.PARAMETER Port
	String. One or more ports to test. Overrides the default list. Great for debugging, and in conjunction with TargetFqdn lets you test from an Edge *in*.

.PARAMETER SkipUpdateCheck
	Boolean. Skips the automatic check for an Update. Courtesy of Pat: http://www.ucunleashed.com/3168

#>
[CmdletBinding(DefaultParameterSetName = "none")]
param(
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Mandatory = $false, parametersetname="site")]
	[string]$Site,
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Mandatory = $false, parametersetname="targetFqdn")]
	[string]$TargetFqdn,
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
	[ValidateScript({
	If ($_ -notmatch "^[(\d| |,)]+$")
	{
		Throw "$_ is not a valid port or list of ports. Only numbers, comma and space are valid values. All ports are assumed TCP, except 3478"
	}
	else
	{
		$True
	}
	})]
	[string]$Port,
	[switch] $SkipUpdateCheck

)

$ScriptVersion = "1.2"
$Global:Debug = $psboundparameters.debug.ispresent
$Error.Clear()          #Clear PowerShell's error variable

# ============================================================================
# START FUNCTIONS ============================================================
# ============================================================================

function Get-UpdateInfo
{
  <#
      .SYNOPSIS
      Queries an online XML source for version information to determine if a new version of the script is available.
	  *** This version customised by Greig Sheridan. @greiginsydney https://greiginsydney.com ***

      .DESCRIPTION
      Queries an online XML source for version information to determine if a new version of the script is available.

      .NOTES
      Version               : 1.2 - See changelog at https://ucunleashed.com/3168 for fixes & changes introduced with each version
      Wish list             : Better error trapping
      Rights Required       : N/A
      Sched Task Required   : No
      Lync/Skype4B Version  : N/A
      Author/Copyright      : © Pat Richard, Office Servers and Services (Skype for Business) MVP - All Rights Reserved
      Email/Blog/Twitter    : pat@innervation.com  https://ucunleashed.com  @patrichard
      Donations             : https://www.paypal.me/PatRichard
      Dedicated Post        : https://ucunleashed.com/3168
      Disclaimer            : You running this script/function means you will not blame the author(s) if this breaks your stuff. This script/function
                            is provided AS IS without warranty of any kind. Author(s) disclaim all implied warranties including, without limitation,
                            any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use
                            or performance of the sample scripts and documentation remains with you. In no event shall author(s) be held liable for
                            any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss
                            of business information, or other pecuniary loss) arising out of the use of or inability to use the script or
                            documentation. Neither this script/function, nor any part of it other than those parts that are explicitly copied from
                            others, may be republished without author(s) express written permission. Author(s) retain the right to alter this
                            disclaimer at any time. For the most up to date version of the disclaimer, see https://ucunleashed.com/code-disclaimer.
      Acknowledgements      : Reading XML files
                            http://stackoverflow.com/questions/18509358/how-to-read-xml-in-powershell
                            http://stackoverflow.com/questions/20433932/determine-xml-node-exists
      Assumptions           : ExecutionPolicy of AllSigned (recommended), RemoteSigned, or Unrestricted (not recommended)
      Limitations           :
      Known issues          :

      .EXAMPLE
      Get-UpdateInfo -Title "Compare-PkiCertificates.ps1"

      Description
      -----------
      Runs function to check for updates to script called <Varies>.

      .INPUTS
      None. You cannot pipe objects to this script.
  #>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
	[string] $title
	)
	try
	{
		[bool] $HasInternetAccess = ([Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]'{DCB00C01-570F-4A9B-8D69-199FDBA5723B}')).IsConnectedToInternet)
		if ($HasInternetAccess)
		{
			write-verbose "Performing update check"
			# ------------------ TLS 1.2 fixup from https://github.com/chocolatey/choco/wiki/Installation#installing-with-restricted-tls
			$securityProtocolSettingsOriginal = [System.Net.ServicePointManager]::SecurityProtocol
			try {
			  # Set TLS 1.2 (3072). Use integers because the enumeration values for TLS 1.2 won't exist in .NET 4.0, even though they are
			  # addressable if .NET 4.5+ is installed (.NET 4.5 is an in-place upgrade).
			  [System.Net.ServicePointManager]::SecurityProtocol = 3072
			} catch {
			  Write-verbose 'Unable to set PowerShell to use TLS 1.2 due to old .NET Framework installed.'
			}
			# ------------------ end TLS 1.2 fixup
			[xml] $xml = (New-Object -TypeName System.Net.WebClient).DownloadString('https://greiginsydney.com/wp-content/version.xml')
			[System.Net.ServicePointManager]::SecurityProtocol = $securityProtocolSettingsOriginal #Reinstate original SecurityProtocol settings
			$article  = select-XML -xml $xml -xpath "//article[@title='$($title)']"
			[string] $Ga = $article.node.version.trim()
			if ($article.node.changeLog)
			{
				[string] $changelog = "This version includes: " + $article.node.changeLog.trim() + "`n`n"
			}
			if ($Ga -gt $ScriptVersion)
			{
				$wshell = New-Object -ComObject Wscript.Shell -ErrorAction Stop
				$updatePrompt = $wshell.Popup("Version $($ga) is available.`n`n$($changelog)Would you like to download it?",0,"New version available",68)
				if ($updatePrompt -eq 6)
				{
					Start-Process -FilePath $article.node.downloadUrl
					Write-Warning "Script is exiting. Please run the new version of the script after you've downloaded it."
					exit
				}
				else
				{
					write-verbose "Upgrade to version $($ga) was declined"
				}
			}
			elseif ($Ga -eq $ScriptVersion)
			{
				write-verbose "Script version $($Scriptversion) is the latest released version"
			}
			else
			{
				write-verbose "Script version $($Scriptversion) is newer than the latest released version $($ga)"
			}
		}
		else
		{
		}

	} # end function Get-UpdateInfo
	catch
	{
		write-verbose "Caught error in Get-UpdateInfo"
		if ($Global:Debug)
		{
			$Global:error | fl * -f #This dumps to screen as white for the time being. I haven't been able to get it to dump in red
		}
	}
}

function Test-UDP3478
{
<#
    .SYNOPSIS
    Simple Skype for Business Online Edge Turn test.

    .NOTES
      Author	: Frank Carius
      Website	: https://www.msxfaq.de/tools/end2end/end2end-udp3478.htm
	  Used with permission. Thank you Frank!
  #>

	param ([string]$hostname)

	[Int] $sourceudpport = 50000
	[Int] $remoteudpport = 3478
	[bool] $Result = $false

	$udpClient = new-Object System.Net.Sockets.Udpclient($sourceudpport)
	$udpClient.Client.ReceiveTimeout = 1000

	# Session Traversal Utilities for NAT
	# STSUN Packet from SfB Network Assessment Tool
	$byteBuffer = @(0x00,0x03,0x00,0x54,0x21,0x12,0xa4,0x42,0xd2,0x79,0xaa, 0x56,0x87,0x86,0x48,
					0x73,0x8f, 0x92,0xef, 0x58,0x00,0x0f, 0x00,0x04,0x72,0xc6,0x4b, 0xc6,0x80,0x08,
					0x00,0x04,0x00,0x00,0x00,0x04,0x00,0x06,0x00,0x30,0x04,0x00,0x00,0x1c, 0x00,
					0x09,0xbe, 0x58,0x24,0xe4,0xc5,0x1c, 0x33,0x4c, 0xd2,0x3f, 0x50,0xf1,0x5d, 0xCE,
					0x81,0xff, 0xa9,0xbe, 0x00,0x00,0x00,0x01,0xeb, 0x15,0x53,0xbd, 0x75,0xe2,0xca,
					0x14,0x1e, 0x36,0x31,0xbb, 0xe3,0xf5,0x4a, 0xa1,0x32,0x45,0xcb, 0xf9,0x00,0x10,
					0x00,0x04,0x00,0x00,0x01,0x5e, 0x80,0x06,0x00,0x04,0x00,0x00,0x00,0x01)

	$RemoteIpEndPoint = New-Object System.Net.IPEndPoint([system.net.IPAddress]::Parse("0.0.0.0"), 0);

	try
	{
		$sentbytes = $udpClient.Send($byteBuffer, $byteBuffer.length, $hostname, $remoteudpport)
		$Receive = $udpClient.Receive([ref] $remoteIpEndpoint)
		$Result = $true
	}
	catch
	{
		$result = $false
	}
	$udpClient.Dispose()
	return $result
}


# ============================================================================
# END FUNCTIONS ==============================================================
# ============================================================================


# ============================================================================
# START MAIN CODE EXECUTION ==================================================
# ============================================================================


if ($skipupdatecheck)
{
	write-verbose "Skipping update check"
}
else
{
	write-progress -id 1 -Activity "Performing update check" -Status "Running Get-UpdateInfo" -PercentComplete (50)
	Get-UpdateInfo -title "Test-EdgeConnectivity.ps1"
	write-progress -id 1 -Activity "Back from performing update check" -Status "Running Get-UpdateInfo" -Completed
}

$ports = @()
$TopoSites = @()
$Results = @()
$EdgeServers = @()

if ($port)
{
	$ports += $Port.split(", ",[System.StringSplitOptions]::RemoveEmptyEntries)	#Splits on space OR comma
}
else
{
	$ports += ("443", "4443", "5061", "5062", "8057", "50001", "50002", "50003", "3478")
}

#We need to know the server's name in a few places:
$server = Get-WmiObject -Query "Select DNSHostName, Domain from Win32_ComputerSystem"
$Fqdn = $server.DnsHostName + "." + $server.Domain

#Prepare the output file:
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$OutputFile  = $dir + "\" + "OutgoingEdgeCheck-$($Fqdn).csv"


if ($TargetFqdn)
{
	$EdgeServers += $TargetFqdn.split(", ",[System.StringSplitOptions]::RemoveEmptyEntries)	#Splits on space OR comma
}
else
{
	$Site = [regex]::replace($Site, "site:" , "", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
	if ($Site)
	{
		$TopoSites += $Site
	}
	else
	{
		$TopoSites += (get-cssite -verbose:$false).Identity
	}

	foreach ($TopoSite in ($TopoSites))
	{
		foreach ($pool in (get-cspool -site $TopoSite -verbose:$false))
		{
			if ($pool.Services -match 'Edge')
			{
				if ($pool.computers -contains $pool.FQDN)
				{
					#Single computer pool. Only write one value
					$EdgeServers += $pool.FQDN
				}
				else
				{
					#Multiple computer pool. Write pool name and computers
					foreach ($computer in $pool.computers)
					{
						$EdgeServers += $computer
					}
				}
			}
		}
	}
}

foreach ($Edge in $EdgeServers)
{
	$ThisEdge = New-Object -TypeName PSObject -Property @{FromFqdn = $Fqdn; ToFqdn = $edge}
	foreach ($port in $ports)
	{
		if ($port -ne "3478")
		{
			write-progress -id 1 -Activity "Testing $($Edge)" -Status "TCP port $($port)"
			try
			{
				$connection = New-Object System.Net.Sockets.TCPClient -ArgumentList $Edge,$port
				if ($connection.Connected)
				{
					$connection.Close() #kthkxbye
					write-host "$Fqdn able to reach $Edge over port $port"
					$ThisEdge | Add-Member NoteProperty "TCP$port"("True")
				}
				else
				{
					write-warning "$Fqdn failed to reach $Edge over port $port"
					$ThisEdge | Add-Member NoteProperty "TCP$port"("False")
				}
			}
			catch
			{
				write-warning "$Fqdn failed to reach $Edge over port $port"
				$ThisEdge | Add-Member NoteProperty "TCP$port"("False")
			}
			write-progress -id 1 -Activity "Testing $($Edge)" -Status "TCP port $($port)" -Completed
		}
		else
		{
			write-progress -id 1 -Activity "Testing $($Edge)" -Status "UDP port 3478"
			if (Test-UDP3478 $Edge)
			{
				write-host "$Fqdn able to reach $Edge over port 3478"
				$ThisEdge | Add-Member NoteProperty "UDP3478"("True")
			}
			else
			{
				write-warning "$Fqdn failed to reach $Edge over port 3478"
				$ThisEdge | Add-Member NoteProperty "UDP3478"("False")
			}
			write-progress -id 1 -Activity "Testing $($Edge)" -Status "UDP port 3478" -Completed
		}
	}
	$Results += $ThisEdge
}
$Results | export-csv -NoTypeInformation -path $outputfile
$Results


# References
# Thank you Mike Robbins: https://mikefrobbins.com/2013/08/08/powershell-parameter-validation-building-a-better-validatepattern-with-validatescript/


# Code signing certificate with thanks to DigiCert:
# SIG # Begin signature block
# MIIceAYJKoZIhvcNAQcCoIIcaTCCHGUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUyju9kkewnTSvFs7waxV6YmVb
# QjegghenMIIFMDCCBBigAwIBAgIQA1GDBusaADXxu0naTkLwYTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTIwMDQxNzAwMDAwMFoXDTIxMDcw
# MTEyMDAwMFowbTELMAkGA1UEBhMCQVUxGDAWBgNVBAgTD05ldyBTb3V0aCBXYWxl
# czESMBAGA1UEBxMJUGV0ZXJzaGFtMRcwFQYDVQQKEw5HcmVpZyBTaGVyaWRhbjEX
# MBUGA1UEAxMOR3JlaWcgU2hlcmlkYW4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
# ggEKAoIBAQC0PMhHbI+fkQcYFNzZHgVAuyE3BErOYAVBsCjZgWFMhqvhEq08El/W
# PNdtlcOaTPMdyEibyJY8ZZTOepPVjtHGFPI08z5F6BkAmyJ7eFpR9EyCd6JRJZ9R
# ibq3e2mfqnv2wB0rOmRjnIX6XW6dMdfs/iFaSK4pJAqejme5Lcboea4ZJDCoWOK7
# bUWkoqlY+CazC/Cb48ZguPzacF5qHoDjmpeVS4/mRB4frPj56OvKns4Nf7gOZpQS
# 956BgagHr92iy3GkExAdr9ys5cDsTA49GwSabwpwDcgobJ+cYeBc1tGElWHVOx0F
# 24wBBfcDG8KL78bpqOzXhlsyDkOXKM21AgMBAAGjggHFMIIBwTAfBgNVHSMEGDAW
# gBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4EFgQUzBwyYxT+LFH+GuVtHo2S
# mSHS/N0wDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGA1Ud
# HwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3Vy
# ZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hh
# Mi1hc3N1cmVkLWNzLWcxLmNybDBMBgNVHSAERTBDMDcGCWCGSAGG/WwDATAqMCgG
# CCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAgGBmeBDAEE
# ATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmluZ0NBLmNydDAMBgNVHRMB
# Af8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQCtV/Nu/2vgu+rHGFI6gssYWfYLEwXO
# eJqOYcYYjb7dk5sRTninaUpKt4WPuFo9OroNOrw6bhvPKdzYArXLCGbnvi40LaJI
# AOr9+V/+rmVrHXcYxQiWLwKI5NKnzxB2sJzM0vpSzlj1+fa5kCnpKY6qeuv7QUCZ
# 1+tHunxKW2oF+mBD1MV2S4+Qgl4pT9q2ygh9DO5TPxC91lbuT5p1/flI/3dHBJd+
# KZ9vYGdsJO5vS4MscsCYTrRXvgvj0wl+Nwumowu4O0ROqLRdxCZ+1X6a5zNdrk4w
# Dbdznv3E3s3My8Axuaea4WHulgAvPosFrB44e/VHDraIcNCx/GBKNYs8MIIFMDCC
# BBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0BAQsFADBlMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0Ew
# HhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5n
# IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+NOzHH8OEa9ndwfT
# CzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ1DcZ17aq8JyGpdgl
# rA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0sSgmuyRpwsJS8hRn
# iolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6scKKrzn/pfMuSoeU7
# MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4TzrGdOtcT3jNEgJSPr
# CGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg0A9kczyen6Yzqf0Z
# 3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8E
# BAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUHAQEEbTBrMCQGCCsG
# AQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0
# dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwTwYDVR0g
# BEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRp
# Z2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYEFFrEuXsqCqOl6nED
# wGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqG
# SIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06GsTvMGHXfgtg/cM9
# D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5jDhNLrddfRHnzNhQG
# ivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgCPC6Ro8AlEeKcFEeh
# emhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIysjaKJAL+L3J+HNdJ
# RZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4GbT8aTEAb8B4H6i9r5
# gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIGajCCBVKgAwIBAgIQAwGa
# Ajr/WLFr1tXq5hfwZjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEw
# HwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTEwHhcNMTQxMDIyMDAwMDAw
# WhcNMjQxMDIyMDAwMDAwWjBHMQswCQYDVQQGEwJVUzERMA8GA1UEChMIRGlnaUNl
# cnQxJTAjBgNVBAMTHERpZ2lDZXJ0IFRpbWVzdGFtcCBSZXNwb25kZXIwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCjZF38fLPggjXg4PbGKuZJdTvMbuBT
# qZ8fZFnmfGt/a4ydVfiS457VWmNbAklQ2YPOb2bu3cuF6V+l+dSHdIhEOxnJ5fWR
# n8YUOawk6qhLLJGJzF4o9GS2ULf1ErNzlgpno75hn67z/RJ4dQ6mWxT9RSOOhkRV
# fRiGBYxVh3lIRvfKDo2n3k5f4qi2LVkCYYhhchhoubh87ubnNC8xd4EwH7s2AY3v
# J+P3mvBMMWSN4+v6GYeofs/sjAw2W3rBerh4x8kGLkYQyI3oBGDbvHN0+k7Y/qpA
# 8bLOcEaD6dpAoVk62RUJV5lWMJPzyWHM0AjMa+xiQpGsAsDvpPCJEY93AgMBAAGj
# ggM1MIIDMTAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDCCAb8GA1UdIASCAbYwggGyMIIBoQYJYIZIAYb9bAcBMIIB
# kjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCCAWQG
# CCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMA
# IABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMA
# IABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMA
# ZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkA
# bgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgA
# IABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUA
# IABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAA
# cgBlAGYAZQByAGUAbgBjAGUALjALBglghkgBhv1sAxUwHwYDVR0jBBgwFoAUFQAS
# KxOYspkH7R7for5XDStnAs0wHQYDVR0OBBYEFGFaTSS2STKdSip5GoNL9B6Jwcp9
# MH0GA1UdHwR2MHQwOKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRENBLTEuY3JsMDigNqA0hjJodHRwOi8vY3JsNC5kaWdpY2Vy
# dC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNybDB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Q0EtMS5jcnQwDQYJKoZIhvcNAQEFBQADggEBAJ0lfhszTbImgVybhs4jIA+Ah+WI
# //+x1GosMe06FxlxF82pG7xaFjkAneNshORaQPveBgGMN/qbsZ0kfv4gpFetW7ea
# sGAm6mlXIV00Lx9xsIOUGQVrNZAQoHuXx/Y/5+IRQaa9YtnwJz04HShvOlIJ8Oxw
# YtNiS7Dgc6aSwNOOMdgv420XEwbu5AO2FKvzj0OncZ0h3RTKFV2SQdr5D4HRmXQN
# JsQOfxu19aDxxncGKBXp2JPlVRbwuwqrHNtcSCdmyKOLChzlldquxC5ZoGHd2vNt
# omHpigtt7BIYvfdVVEADkitrwlHCCkivsNRu4PQUCjob4489yq9qjXvc2EQwggbN
# MIIFtaADAgECAhAG/fkDlgOt6gAK6z8nu7obMA0GCSqGSIb3DQEBBQUAMGUxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBD
# QTAeFw0wNjExMTAwMDAwMDBaFw0yMTExMTAwMDAwMDBaMGIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAOiCLZn5ysJClaWAc0Bw0p5WVFypxNJBBo/J
# M/xNRZFcgZ/tLJz4FlnfnrUkFcKYubR3SdyJxArar8tea+2tsHEx6886QAxGTZPs
# i3o2CAOrDDT+GEmC/sfHMUiAfB6iD5IOUMnGh+s2P9gww/+m9/uizW9zI/6sVgWQ
# 8DIhFonGcIj5BZd9o8dD3QLoOz3tsUGj7T++25VIxO4es/K8DCuZ0MZdEkKB4YNu
# gnM/JksUkK5ZZgrEjb7SzgaurYRvSISbT0C58Uzyr5j79s5AXVz2qPEvr+yJIvJr
# GGWxwXOt1/HYzx4KdFxCuGh+t9V3CidWfA9ipD8yFGCV/QcEogkCAwEAAaOCA3ow
# ggN2MA4GA1UdDwEB/wQEAwIBhjA7BgNVHSUENDAyBggrBgEFBQcDAQYIKwYBBQUH
# AwIGCCsGAQUFBwMDBggrBgEFBQcDBAYIKwYBBQUHAwgwggHSBgNVHSAEggHJMIIB
# xTCCAbQGCmCGSAGG/WwAAQQwggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3LmRp
# Z2ljZXJ0LmNvbS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUHAgIw
# ggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQA
# aQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBjAGUA
# cAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMA
# UAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEA
# cgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBtAGkA
# dAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBjAG8A
# cgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBlAHIA
# ZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTASBgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsG
# AQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8v
# Y3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqg
# OKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3JsMB0GA1UdDgQWBBQVABIrE5iymQftHt+ivlcNK2cCzTAfBgNVHSME
# GDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEARlA+
# ybcoJKc4HbZbKa9Sz1LpMUerVlx71Q0LQbPv7HUfdDjyslxhopyVw1Dkgrkj0bo6
# hnKtOHisdV0XFzRyR4WUVtHruzaEd8wkpfMEGVWp5+Pnq2LN+4stkMLA0rWUvV5P
# sQXSDj0aqRRbpoYxYqioM+SbOafE9c4deHaUJXPkKqvPnHZL7V/CSxbkS3BMAIke
# /MV5vEwSV/5f4R68Al2o/vsHOE8Nxl2RuQ9nRc3Wg+3nkg2NsWmMT/tZ4CMP0qqu
# AHzunEIOz5HXJ7cW7g/DvXwKoO4sCFWFIrjrGBpN/CohrUkxg0eVd3HcsRtLSxwQ
# nHcUwZ1PL1qVCCkQJjGCBDswggQ3AgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUwEwYD
# VQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAv
# BgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EC
# EANRgwbrGgA18btJ2k5C8GEwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAI
# oAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIB
# CzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFBIV/SKD4nL3mLg2z/24
# /P+8WzKpMA0GCSqGSIb3DQEBAQUABIIBAEagQCed1qoEUMlSb9GacaoK919HVId/
# eAe/0DV47heEgIAzOn28tMRkn/Unp0fRHwSkn1+PGfnxUM4D3zUPFMPwMQ501hmV
# BgJuEeAYxNQfZ5wZSJO5pzNkhKDE9bYMOzG6A45H3PP7vevxYUR7L+KnAjLleukp
# /cq9jFyld4WNsZyRKlw63rTckep1mD4hTOXvHQzDsAiJ7ULDkLJzG+tUEcOgXVzT
# SvnF12WzF2EdvWr/iXA9OhLdwDV5Y5OEaANxXKjaQIcbFzdF68ePQ5pOdtikddEM
# w/sCq0uYWCgRsq702cDQeAlkUv14EayoydbPgo9ImTLGR7y1ToamKyGhggIPMIIC
# CwYJKoZIhvcNAQkGMYIB/DCCAfgCAQEwdjBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTECEAMBmgI6/1ixa9bV6uYX8GYw
# CQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTIwMDUwNTExMjI1M1owIwYJKoZIhvcNAQkEMRYEFOYJs6eAT96y6lcF
# 2/W4mwGSj0yXMA0GCSqGSIb3DQEBAQUABIIBAD+1PcugJFBJsNaEmm1AwyIjeIMA
# /dN1+MJHlKADAKoesfeA8ZgQoIUHxXckUyhyGGfgA8DH2olRZkGBa5NgC4vfJTcb
# Rxzll76QXLt+Scz3tYc12wRXvk5TqNZrFihjESKAG2hhsr5Bz5xMHZU5QeIXCN5g
# nzhLJ3c7yV0k1PuIFIQmRL51KECsQPOnCAxAXcRGa+OuTK8EFNYaoKT1WRS2AO2x
# FULEr/A1lAhPxyqMOZd+LXADesI0metISKlegTYhK6mYwwWL8B/StsI5RRCYF7e1
# Vtu8XnTARKW0fr3MAjTXB/tKET31owQ9UwBMcA5sH/4TBfwT7oVzaf696sA=
# SIG # End signature block
