<#
.Synopsis
   Script for creating WMI Filters for use with Group Policy Manager.
.DESCRIPTION
   The Script will create several WMI Filters for filtering based on:
   - Processor Architecture.
   - If the Hosts is a Virtual Machine
   - Operating System Version.
   - Type of Operating System.
   - If Java is installed
   - If Version 6 or 7 of Java JRE is installed.
   - Version of IE
.EXAMPLE
   Running script if verbose output

   .\install-wmifilters.ps1 -Verbose
.NOTES
   Author: Carlos Perez carlos_perez[at]darkoperator.com
   Date: 1/13/13
   Requirements: Execution policy should be RemoteSigned since script is not signed.
#>

[cmdletbinding(SupportsShouldProcess=$true)]
param()

Import-Module ActiveDirectory

Function Set-DCAllowSystemOnlyChange
{
	param ([switch]$Set)
	if ($Set)
	{
		Write-Verbose "Checking is registry key is set to allow changes to AD System Only Attributes is set."
		$ntds_vals = (Get-Item HKLM:\System\CurrentControlSet\Services\NTDS\Parameters).GetValueNames()
		if ( $ntds_vals -eq "Allow System Only Change")
		{
			$kval = Get-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -name "Allow System Only Change"
			if ($kval -eq "1")
			{
		    	Write-Verbose "Allow System Only Change key is already set"    
			}
			else
			{
		    	Write-Verbose "Allow System Only Change key is not set"
				Write-Verbose "Creating key and setting value to 1"
				Set-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -name "Allow System Only Change" -Value 0 | Out-Null
			}
		}
		else
		{
			New-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -name "Allow System Only Change" -Value 1 -PropertyType "DWord" | Out-Null
		}
	}
	else
	{
		
		$ntds_vals = (Get-Item HKLM:\System\CurrentControlSet\Services\NTDS\Parameters).GetValueNames()
		if ( $ntds_vals -eq "Allow System Only Change")
		{
			Write-Verbose "Disabling Allow System Only Change Attributes on server"
			Set-ItemProperty HKLM:\System\CurrentControlSet\Services\NTDS\Parameters -name "Allow System Only Change" -Value 0 | Out-Null
		}
	}
}
Function Create-WMIFilters
{
	# Based on function from http://gallery.technet.microsoft.com/scriptcenter/f1491111-9f5d-4c83-b436-537eca9e8d94
    # Name,Query,Description
    $WMIFilters = @(
                    ('Hyper-V Virtual Machines', 
                        'SELECT * FROM Win32_ComputerSystem WHERE Model = "Virtual Machine"', 
                        'Microsoft Hyper-V 2.0 AND 3.0'),
                    ('VMware Virtual Machines', 
                        'SELECT * FROM Win32_ComputerSystem WHERE Model LIKE "VMware%"', 
                        'VMware Fusion, WORkstation AND ESXi'),
                    ('Parallels Virtual Machines', 
                        'SELECT * FROM Win32_ComputerSystem WHERE Model LIKE "Parallels%"', 
                        'OSX Parallels Virtual Machine'),
                    ('VirtualBox Virtual Machines', 
                        'SELECT * FROM Win32_ComputerSystem WHERE Model LIKE "VirtualBox%"', 
                        'Oracle VirtualBox Virtual Machine'),
                    ('Xen Virtual Machines', 
                        'SELECT * FROM Win32_ComputerSystem WHERE Model LIKE "HVM dom%"', 
                        'Citrix Xen Server Virtual Machine'),
                    ('Virtual Machines',
                        'SELECT * FROM Win32_ComputerSystem WHERE (Model LIKE "Parallels%" OR Model LIKE "HVM dom% OR Model LIKE "VirtualBox%" OR Model LIKE "Parallels%" OR Model LIKE "VMware%" OR Model = "Virtual Machine")',
                        'Virtual Machine from Hyper-V, VMware, Xen, Parallels OR VirtualBox'),
                    ('Java is Installed', 
                        'SELECT * FROM win32_DirectORy WHERE (name="c:\\Program Files\\Java" OR name="c:\\Program Files (x86)\\Java")', 
                        'Oracle Java'),
                    ('Java JRE 7 is Installed', 
                        'SELECT * FROM win32_DirectORy WHERE (name="c:\\Program Files\\Java\\jre7" OR name="c:\\Program Files (x86)\\Java\\jre7")', 
                        'Oracle Java JRE 7'),
                    ('Java JRE 6 is Installed', 
                        'SELECT * FROM win32_DirectORy WHERE (name="c:\\Program Files\\Java\\jre6" OR name="c:\\Program Files (x86)\\Java\\jre6")', 
                        'Oracle Java JRE 6'),
                    ('Workstation 32-bit', 
                        'Select * from WIN32_OperatingSystem WHERE ProductType=1 Select * from Win32_Processor WHERE AddressWidth = "32"', 
                        ''),
                    ('Workstation 64-bit', 
                        'Select * from WIN32_OperatingSystem WHERE ProductType=1 Select * from Win32_Processor WHERE AddressWidth = "64"', 
                        ''),
                    ('Workstations', 
                        'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "1"', 
                        ''),
                    ('Domain Controllers', 
                        'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "2"', 
                        ''),
                    ('Servers', 
                        'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "3"', 
                        ''),
                    ('Windows XP', 
                        'SELECT * FROM Win32_OperatingSystem WHERE (Version LIKE "5.1%" OR Version LIKE "5.2%") AND ProductType = "1"', 
                        ''),
                    ('Windows Vista', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "6.0%" AND ProductType = "1"', 
                        ''),
                    ('Windows 7', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "6.1%" AND ProductType = "1"', 
                        ''),
                    ('Windows 8', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "6.2%" AND ProductType = "1"', 
                        ''),
                    ('Windows Server 2003', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "5.2%" AND ProductType = "3"', 
                        ''),
                    ('Windows Server 2008', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "6.0%" AND ProductType = "3"', 
                        ''),
                    ('Windows Server 2008 R2', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "6.1%" AND ProductType = "3"', 
                        ''),
                    ('Windows Server 2012', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "6.2%" AND ProductType = "3"', 
                        ''),
                    ('Windows Vista AND Windows Server 2008', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "6.0%" AND ProductType<>"2"', 
                        ''),
                    ('Windows Server 2003 AND Windows Server 2008', 
                        'SELECT * FROM Win32_OperatingSystem WHERE (Version LIKE "5.2%" OR Version LIKE "6.0%") AND ProductType="3"', 
                        ''),
                    ('Windows XP AND 2003', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "5.%" AND ProductType<>"2"', 
                        ''),
                    ('Windows 8 AND 2012', 
                        'SELECT * FROM Win32_OperatingSystem WHERE Version LIKE "6.2%" AND ProductType<>"2"', 
                        ''),
                    ('Internet ExplORer 10', 
                        '"SELECT * FROM CIM_Datafile WHERE (Name="c:\\Program Files (x86)\\Internet ExplORer\\iexplORe.exe" OR Name="c:\\Program Files\\Internet ExplORer\\iexplORe.exe") AND version LIKE "10.%"'),
                    ('Internet ExplORer 9', 
                        '"SELECT * FROM CIM_Datafile WHERE (Name="c:\\Program Files (x86)\\Internet ExplORer\\iexplORe.exe" OR Name="c:\\Program Files\\Internet ExplORer\\iexplORe.exe") AND version LIKE "9.%"'),
                    ('Internet ExplORer 8', 
                        '"SELECT * FROM CIM_Datafile WHERE (Name="c:\\Program Files (x86)\\Internet ExplORer\\iexplORe.exe" OR Name="c:\\Program Files\\Internet ExplORer\\iexplORe.exe") AND version LIKE "8.%"'),
                    ('Internet ExplORer 7', 
                        '"SELECT * FROM CIM_Datafile WHERE (Name="c:\\Program Files (x86)\\Internet ExplORer\\iexplORe.exe" OR Name="c:\\Program Files\\Internet ExplORer\\iexplORe.exe") AND version LIKE "7.%"')
                )

    $defaultNamingContext = (get-adrootdse).defaultnamingcontext 
    $configurationNamingContext = (get-adrootdse).configurationNamingContext 
    $msWMIAuthor = "Administrator@" + [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain().name
    
	Write-Verbose "Starting creation of WMI Filters:"
    for ($i = 0; $i -lt $WMIFilters.Count; $i++) 
    {
        $WMIGUID = [string]"{"+([System.Guid]::NewGuid())+"}"   
        $WMIDN = "CN="+$WMIGUID+",CN=SOM,CN=WMIPolicy,CN=System,"+$defaultNamingContext
        $WMICN = $WMIGUID
        $WMIdistinguishedname = $WMIDN
        $WMIID = $WMIGUID

        $now = (Get-Date).ToUniversalTime()
        $msWMICreationDate = ($now.Year).ToString("0000") + ($now.Month).ToString("00") + ($now.Day).ToString("00") + ($now.Hour).ToString("00") + ($now.Minute).ToString("00") + ($now.Second).ToString("00") + "." + ($now.Millisecond * 1000).ToString("000000") + "-000"

        $msWMIName = $WMIFilters[$i][0]
        $msWMIParm1 = $WMIFilters[$i][2] + " "
        $msWMIParm2 = "1;3;10;" + $WMIFilters[$i][1].Length.ToString() + ";WQL;root\CIMv2;" + $WMIFilters[$i][1] + ";"

        $Attr = @{"msWMI-Name" = $msWMIName;"msWMI-Parm1" = $msWMIParm1;"msWMI-Parm2" = $msWMIParm2;"msWMI-Author" = $msWMIAuthor;"msWMI-ID"=$WMIID;"instanceType" = 4;"showInAdvancedViewOnly" = "TRUE";"distinguishedname" = $WMIdistinguishedname;"msWMI-ChangeDate" = $msWMICreationDate; "msWMI-CreationDate" = $msWMICreationDate}
        $WMIPath = ("CN=SOM,CN=WMIPolicy,CN=System,"+$defaultNamingContext)
    	
		Write-Verbose "Adding WMI Filter for: $msWMIName"
        New-ADObject -name $WMICN -type "msWMI-Som" -Path $WMIPath -OtherAttributes $Attr | Out-Null
    }
	Write-Verbose "Finished adding WMI Filters"
}

Set-DCAllowSystemOnlyChange -Set
Create-WMIFilters
Set-DCAllowSystemOnlyChange 
