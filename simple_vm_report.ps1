param 
(
	[string]$Server,
	[parameter(mandatory=$true)][string]$CSVFile
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
if ($Server){
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
 }
 
$vms = Get-VM
$report = @()
Write-Host "[*] Preparing report for VMs on server " -ForegroundColor Blue
foreach ($vm in $vms) {
	Write-Host "[*]`tProcessing"$v.Name -ForegroundColor Green
	$v = Get-View $vm
	$row = "" | Select VMname,VMUsedGB,VMProvisionedGB,HDname,HDformat,HDCapacity,PowerState,IPAddress,HostName,ToolStatus,CDStatus,ESX
	$hd = Get-HardDisk $vm
	$row.VMname = $v.Name
	$row.VMUsedGB = $vm.UsedSpaceGB
	$row.VMProvisionedGB = $vm.ProvisionedSpaceGB
	$row.PowerState = $vm.PowerState
	$row.IPAddress = [string]$vm.Guest.IPAddress
	$row.HostName = $vm.Guest.HostName
	$row.ToolStatus = $v.Guest.ToolsStatus
	$row.ESX = $vm.vmhost
	$cd = Get-CDDrive $vm | where {$_.ConnectionState.Connected -eq $true}
	if ($cd)
	{
		$row.CDStatus = $cd.IsoPath
	}
	else
	{
		$row.CDStatus = "CD Disconnected"	
	}
	$hds = Get-HardDisk $vm
	foreach ($hd in $hds)
	{
		$row.HDname = $hd.Name
		$row.HDformat = $hd.StorageFormat
		$row.HDCapacity = $hd.CapacityKB
		$report = $report + $row
	}
}
Write-Host "[*] Finished" -ForegroundColor Blue
Write-Host "[*] Report saved to"$CSVFile -ForegroundColor Blue
$report | Export-csv $CSVFile -NoTypeInformation -UseCulture