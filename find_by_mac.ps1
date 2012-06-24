# Define Script Parameters
param 
(
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty]
	[string]$Server,
	
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty]
	[string]$MacAddress
)


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

 $ints = Get-VM | Get-NetworkAdapter
 $found = $null
 Write-Host "[*] Searching for "$MacAddress -ForegroundColor Green
 foreach ($i in $ints){
 	if ($i.MacAddress -eq $MacAddress){
 		$found = $i
	}
 }
 if ($found){
 	Write-Host "Mac Address: "$found.macaddress -ForegroundColor Green
	write-host "VM: "$found.Parent -ForegroundColor Green
 }
 else{
 	Write-Host "[-] Mac Address was not found on any VM on this server." -ForegroundColor Cyan
}