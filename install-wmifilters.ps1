<#
.Synopsis
   Script for creating WMI Filters for use with Group Policy Manager.
.DESCRIPTION
   The Script will create several WMI Filters for filtering based on:
   - Processor Architecture.
   - If the Hosts is a Hyper-V Virtual Machine
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
   Date: 1/12/13
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
					('Hyper-V Virtual Machines', 'SELECT * FROM Win32_ComputerSystem WHERE Model = "Virtual Machine"', 'Hyper-V'),
                    ('VMware Virtual Machines', 'SELECT * FROM Win32_ComputerSystem WHERE Model LIKE "VMware%"', 'VMware'),
                    ('Java is Installed', 'Select * From win32_Directory where (name="c:\\Program Files\\Java" or name="c:\\Program Files (x86)\\Java")', 'Oracle Java'),
                    ('Java JRE 7 is Installed', 'Select * From win32_Directory where (name="c:\\Program Files\\Java\\jre7" or name="c:\\Program Files (x86)\\Java\\jre7")', 'Oracle Java JRE 7'),
                    ('Java JRE 6 is Installed', 'Select * From win32_Directory where (name="c:\\Program Files\\Java\\jre6" or name="c:\\Program Files (x86)\\Java\\jre6")', 'Oracle Java JRE 6'),
                    ('Workstation 32-bit', 'Select * from WIN32_OperatingSystem where ProductType=1 Select * from Win32_Processor where AddressWidth = "32"', ''),
                    ('Workstation 64-bit', 'Select * from WIN32_OperatingSystem where ProductType=1 Select * from Win32_Processor where AddressWidth = "64"', ''),
                    ('Workstations', 'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "1"', ''),
                    ('Domain Controllers', 'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "2"', ''),
                    ('Servers', 'SELECT * FROM Win32_OperatingSystem WHERE ProductType = "3"', ''),
                    ('Windows XP', 'select * from Win32_OperatingSystem where (Version like "5.1%" or Version like "5.2%") and ProductType = "1"', ''),
                    ('Windows Vista', 'select * from Win32_OperatingSystem where Version like "6.0%" and ProductType = "1"', ''),
                    ('Windows 7', 'select * from Win32_OperatingSystem where Version like "6.1%" and ProductType = "1"', ''),
                    ('Windows 8', 'select * from Win32_OperatingSystem where Version like "6.2%" and ProductType = "1"', ''),
                    ('Windows Server 2003', 'select * from Win32_OperatingSystem where Version like "5.2%" and ProductType = "3"', ''),
                    ('Windows Server 2008', 'select * from Win32_OperatingSystem where Version like "6.0%" and ProductType = "3"', ''),
                    ('Windows Server 2008 R2', 'select * from Win32_OperatingSystem where Version like "6.1%" and ProductType = "3"', ''),
                    ('Windows Server 2012', 'select * from Win32_OperatingSystem where Version like "6.2%" and ProductType = "3"', ''),
                    ('Windows Vista and Windows Server 2008', 'select * from Win32_OperatingSystem where Version like "6.0%" and ProductType<>"2"', ''),
                    ('Windows Server 2003 and Windows Server 2008', 'select * from Win32_OperatingSystem where (Version like "5.2%" or Version like "6.0%") and ProductType="3"', ''),
                    ('Windows XP and 2003', 'select * from Win32_OperatingSystem where Version like "5.%" and ProductType<>"2"', ''),
                    ('Windows 8 and 2012', 'select * from Win32_OperatingSystem where Version like "6.2%" and ProductType<>"2"', ''),
                    ('Internet Explorer 10', '"Select * From CIM_Datafile Where (Name="c:\\Program Files (x86)\\Internet Explorer\\iexplore.exe" or Name="c:\\Program Files\\Internet Explorer\\iexplore.exe") and version like "10.%"'),
                    ('Internet Explorer 9', '"Select * From CIM_Datafile Where (Name="c:\\Program Files (x86)\\Internet Explorer\\iexplore.exe" or Name="c:\\Program Files\\Internet Explorer\\iexplore.exe") and version like "9.%"'),
                    ('Internet Explorer 8', '"Select * From CIM_Datafile Where (Name="c:\\Program Files (x86)\\Internet Explorer\\iexplore.exe" or Name="c:\\Program Files\\Internet Explorer\\iexplore.exe") and version like "8.%"'),
                    ('Internet Explorer 7', '"Select * From CIM_Datafile Where (Name="c:\\Program Files (x86)\\Internet Explorer\\iexplore.exe" or Name="c:\\Program Files\\Internet Explorer\\iexplore.exe") and version like "7.%"')
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
