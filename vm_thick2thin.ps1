# Based on LucD script in http://www.lucd.info/2009/11/08/thick-to-thin-with-powercli-and-the-sdk/
# Define Script Parameters
param 
(
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty]
	[string]$vCenter,
	
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty]
	[string]$VM,
	
	[string]$ESXUser,
	[string]$ESXPass,
	[bool]$DeleteThick = $false
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
     if (get-vmhost -Server $vCenter -State connected -erroraction "Stop"){
         $connected = $True
     }
 }
 Catch {
     #Try to connect
     Try {
	 	Write-Host "[*] Connecting to $Server" -ForegroundColor Green 
        $viserver = Connect-VIserver -Server $vCenter -errorAction "Stop"
        $connected = $True
     }
     Catch {
         $msg = "[-] Failed to connect to server $Server"
         Write-Warning $msg
         Write-Warning $error[0].Exception.Message
     }
 }

function clone_disk{
	param(
		$vmName,
		$esxAccount,
		$esxPasswd,
		$delold
	)
	$vmImpl = Get-VM $vmName
	if($vmImpl.PowerState -ne "PoweredOff"){
		Write-Host "Guest must be powered off to use this script !" -ForegroundColor red
		exit
	}
	$vm = $vmImpl | Get-View
	$esxName = (Get-View $vm.Runtime.Host).Name
	Write-Host "[*] Connecting to ESX server"$esxName -ForegroundColor Green
	# For Virtual Disk Manager we need to connect to the ESX server
	$esxHost = Connect-VIServer -Server $esxName -User $esxAccount -Password $esxPasswd

	$vDiskMgr = Get-View -Id (Get-View ServiceInstance).Content.VirtualDiskManager
	$firstHD = $true
	$vm.Config.Hardware.Device | where {$_.GetType().Name -eq "VirtualDisk"} | % {
	 if(!$_.Backing.ThinProvisioned){
	 	$dev = $_
	 	$srcName = $dev.Backing.FileName
	 	$dstName = $srcName.Replace("/","/thin_")
	 	$srcDC = Get-Datacenter | Get-View
	 	$spec = New-Object VMware.Vim.VirtualDiskSpec
	 	$controller = $vm.Config.Hardware.Device | where {$_.Key -eq $dev.ControllerKey}
	 	switch($controller.GetType().Name){
	 		"VirtualBusLogicController" {$adapter = "busLogic"}
	 		"VirtualIDEController" {$adapter = "ide"}
	 		"VirtualLsiLogicController" {$adapter = "lsiLogic"}
	 		"VirtualLsiLogicSASController" {$adapter = "lsiLogic"}
	 		"ParaVirtualSCSIController" {$adapter = ""}
	 		"Default"{
	 			Write-Host "Unknown controller type"
	 			exit
	 		}
		}
	 	$spec.adapterType = $adapter
	 	$spec.diskType = "thin"
		Write-Host "[*] Cloning disk $srcName as $dstName" -ForegroundColor Green
	 	$taskMoRef = $vDiskMgr.CopyVirtualDisk_Task($srcName, $srcDC.MoRef, $dstName, $srcDC.MoRef, $spec, $false)
	 	$task = Get-View $taskMoRef
	 	while("running","queued" -contains $task.Info.State){
	 		$task.UpdateViewData("Info")
	 	}
		if ($delold){
			Write-Host "[*] Deleting thick disk "$srcName -ForegroundColor Green
			$taskMoRef = $vDiskMgr.DeleteVirtualDisk_Task($srcName, $srcDC.MoRef)
	 		$task = Get-View $taskMoRef
	 		while("running","queued" -contains $task.Info.State){
	 			$task.UpdateViewData("Info")
	 		}
		}
	 	if($firstHD){
	 		$specHD = New-Object VMware.Vim.VirtualMachineConfigSpec
	 		$firstHD = $false
	 	}
	 	$deviceMod = New-Object VMware.Vim.VirtualDeviceConfigSpec
	 	$deviceMod.device = $dev
	 	$deviceMod.device.Backing.FileName = $dstName
	 	$deviceMod.Operation = "edit"
	 	$specHD.deviceChange += $deviceMod
	 }
	}
	Write-Host "[*] Disconnecting from ESX server "$esxHost -ForegroundColor Green
	Disconnect-VIServer -Server $esxHost -Confirm:$false
	
	# return disk spec
	$specHD
}

# Function for reconfiguring the VM given the Spec
function conf_vm {
	param(
		$vmSpec,
		$vCenter,
		$vmName
	)
	# For the reconfiguration of the VM we connect to the vCenter
	Write-Host "[*] Connecting to vCenter server to reconfigure VM" -ForegroundColor Green
	Connect-VIServer -Server $vCenter | Out-Null
	$vm = Get-VM $vmName | Get-View
	$taskMoRef = $vm.ReconfigVM_Task($vmSpec)
	$task = Get-View $taskMoRef
	while("running","queued" -contains $task.Info.State){
		$task.UpdateViewData("Info")
	}
}
$spec_vm = clone_disk $VM $ESXUser $ESXPass $DeleteThick
conf_vm $spec_vm $vCenter $VM