# Define Script Parameters
param 
(
	[string]$Server,
	[string]$VM
)
# Check Paramters
if ($Server -eq $null)
{
	$Host.UI.WriteErrorLine("[-] You must specify a server to check against.")
	exit
}
if ($VM -eq $null)
{
	$Host.UI.WriteErrorLine("[-] You must specify a VM Name.")
}

# Check if VMware Snappin is loaded for when ran outside of PowerCli
if ( (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
{
	Write-Host "[*] VMware Automation Snapin is not loaded, attempting to load..." -ForegroundColor Green
    Try {
		Add-PsSnapin VMware.VimAutomation.Core | Out-Null
	} 
	Catch {
		$Host.UI.WriteErrorLine("[-] Could not load snapping check that PowerCli is installed.")
		exit
	}
}

#verify we're connected to a VM host
 Try {
     if (get-vmhost -Server $Server -State connected -erroraction "Stop") {
         $connected=$True
     }
 }
 Catch {
     #Try to connect
     Try {
	 	Write-Host -ForegroundColor Green "[*] Connecting to $Server"
        $viserver=Connect-VIserver -Server $Server -errorAction "Stop"
        $connected=$True
     }
     Catch {
         $msg="[-] Failed to connect to server $Server"
         Write-Warning $msg
         Write-Warning $error[0].Exception.Message
     }
 }
$po_events = Get-VIEvent | where {$_.FullFormattedMessage -match "(shutdown|powered off|reset)"}

foreach ($e in $po_events){
	if ($e.FullFormattedMessage -match $VM){
		Write-Host  "User: "$e.username
		write-host "Time: "$e.CreatedTime.DateTime
		write-host "Action: "$e.FullFormattedMessage
		Write-Host
	}
}