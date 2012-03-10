######################################################################################################################
# File:             clone_vm.ps1                                                                                      #
# Author:           Carlos Peres                                                                                      #
# Email:            carlos_perez@darkoperator.com                                                                     #
# Copyright:        © 2012 . All rights reserved.                                                                     #
# Usage:            To load this module in your Script Editor:                                                        #
#                   1. Open PowerCli shell.                                                                           #
#                   2. Navigate to where the script is located.                                                       #
#                   3. Call script with options. .\clone_vm.ps1 -Server <ESX> -VM <VM to Clone> -CloneName            #
#                      <Name to give to Clone VM> <Enter>                                                             #
# License:			BSD 3 Clause License                                                                              #
# Version:          0.2                                                                                               #
#######################################################################################################################
# Define Script Parameters
param 
(
	[string]$Server,
	[string]$VM,
	[string]$CloneName
)

# Check Paramters
if ($Server -eq $null)
{
	$Host.UI.WriteErrorLine("[-] You must specify a server wher the VM to clone is located.")
	exit
}
if ($VM -eq $null)
{
	$Host.UI.WriteErrorLine("[-] You must specify a Powered Off VM name to Clone.")
}
if ($CloneName -eq $null)
{
	$Host.UI.WriteErrorLine("[-] You must specify a name for the clone.")
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
 
# Function Returns hash with datastore name and folder name
function find_vm {
	param($vm_name)
	$vm_info =@{}
	$orig_vm = Get-VM | where {$_.name -match $vm_name} | select -First 1

	if ($orig_vm -ne $null){
		if ($orig_vm.PowerState -eq "PoweredOff"){
			$vm_info_raw = $orig_vm.Extensiondata.Summary.Config.VmPathName.Split(" ")
			$vm_info['datastore'] = $vm_info_raw[0] -creplace "\[|\]", ""
			$vm_info['folder'] = $vm_info_raw[1].split("/")[0]
			$VM_info['vmhost'] = $orig_vm.VMHost
		}
		else {
			$Host.UI.WriteErrorLine("[-] VM must be powered off before attempting to clone")
			exit
		}
	}
	else {
		$Host.UI.WriteErrorLine(" [-] Could not find the VM specified")
		exit
	}
	$vm_info
}

function clone {
	param($dsstore, $fs_folder, $clone_name, $vmhost)
	# Generate PSDrive
	$datastore = Get-Datastore $dsstore 
	# Check if a previous PSDrive exists
	$psd = Get-PSDrive | where {$_.name -eq "vmds"}
	if ($psd -eq $null){ 
		$ds_path = New-PSDrive -Location $datastore -Name vmds -PSProvider VimDatastore -Root "\"
	}
	Write-Host "[*] Making copy of VM as $clone_name (Depending size, number of files and server load it may take a while)" -ForegroundColor Green
	Copy-DatastoreItem -Item "vmds:\$fs_folder\*" -Destination "vmds:\$clone_name\" -Force
	Write-Host "[*] Registering $clone_name" -ForegroundColor Green
	dir "vmds:\$clone_name\*.vmx" | %{New-VM -Name $clone_name -VMFilePath $_.DatastoreFullPath -VMHost $vmhost} | Out-Null
	Write-Host "[*] VM has been cloned!" -ForegroundColor Green
	Write-Host "[*] Cleaning up remaining  tasks" -ForegroundColor Green
	Remove-PSDrive -Name "vmds"
}

# Function to check if a VM already exists
function check_vm {
	param($clone_name, $exiting_vm)
	$to_clone = $found_vm = Get-VM | where {$_.name -eq $exiting_vm}
	if ($found_vm -ne $null) {
		$Host.UI.WriteErrorLine("[-] VM $VM specified does not exist on this server!")
		exit
	}
	$found_vm = Get-VM | where {$_.name -eq $clone_name}
	if ($found_vm -ne $null) {
		$Host.UI.WriteErrorLine("[-] VM $clone_name already exists on this server")
		exit
	}
}

# Function to change VM UUID
function change_uuid{
	param($cloned_vm)
	$key = "uuid.action"
	$value = "create"
	Write-Host "[*] Changing the VM UUID of the cloned VM" -ForegroundColor Green
	$vm = get-vm $cloned_vm
	$vm_id = Get-View $vm.Id
  	$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
  	$vmConfigSpec.extraconfig += New-Object VMware.Vim.optionvalue
  	$vmConfigSpec.extraconfig[0].Key=$key
  	$vmConfigSpec.extraconfig[0].Value=$value
  	$vm_id.ReconfigVM($vmConfigSpec)
	Write-Host "[*] UUID Changed" -ForegroundColor Green
}
########## MAIN ########## 

if ($connected) {
	Write-Host "[*] Cloning $VM as $CloneName" -ForegroundColor Green
	check_vm $CloneName
	$vmhash = find_vm $VM
	clone $vmhash['datastore'] $vmhash['folder'] $CloneName $vmhash['vmhost']
	change_uuid $CloneName
}