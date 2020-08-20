# Copyright Carlos Perez
# carlos_perez@darkoperator.com
 
(new-object System.Net.WebClient).DownloadFile('https://gist.githubusercontent.com/darkoperator/e229781fe44edac94bb8bcb027d786f7/raw/e3f478f8a9427421c137fd8d13d1c5546bd5429e/accounting.csv', "$env:temp\Accounting.csv")
(new-object System.Net.WebClient).DownloadFile('https://gist.githubusercontent.com/darkoperator/986058fbfe9fa18b537120b42762c82b/raw/d384504ee2d91ee28ef4834bbbc5fb9c3416d0e0/ops_acc.csv', "$env:temp\Ops.csv")
(new-object System.Net.WebClient).DownloadFile('https://gist.githubusercontent.com/darkoperator/1e7eff7a1aeb082ba241037cfa02bc2f/raw/3ec7f4a7d40fb96d44d6c832f7360c0f674afe7c/hr_acc.csv', "$env:temp\HR.csv")
(new-object System.Net.WebClient).DownloadFile('https://gist.githubusercontent.com/darkoperator/28f6e7ac6d5922b8e51cbb443ceffb23/raw/02a4a813f07d6beb33aa39cd9dc49774745cf72d/it_acc.csv', "$env:temp\IT.csv")
(new-object System.Net.WebClient).DownloadFile('https://gist.githubusercontent.com/darkoperator/a3e31fa0d75550a820da6bea5d83c62e/raw/6e6b0b366151e0be5a8eeeec567e64e3c38a3171/marketing.csv', "$env:temp\Marketing.csv")
(new-object System.Net.WebClient).DownloadFile('https://gist.githubusercontent.com/darkoperator/caa3414620c80bbab62435593358c774/raw/a8da36006066f161f19f2fa82b675e9fb7bcd4f5/sales.csv', "$env:temp\Sales.csv")
(new-object System.Net.WebClient).DownloadFile('https://gist.githubusercontent.com/darkoperator/9f4b29a2e14542d593b24893ffeacbce/raw/da5c01f0ceba8ccd29917b63997f33d4f3e01371/support.csv', "$env:temp\Support.csv")
 
 
$DomainDN = ([adsi]'').distinguishedName
<#
.SYNOPSIS
    Imports a CSV from Fake Name Generator to create test AD User accounts.
.DESCRIPTION
    Imports a CSV from Fake Name Generator to create test AD User accounts.
    It will create OUs per country under the OU specified. Bulk
   generated accounts from fakenamegenerator.com must have as fields:
   * GivenName
   * Surname
   * StreetAddress
   * City
   * Title
   * Username
   * Password
   * Country
   * TelephoneNumber
   * Occupation
.EXAMPLE
    C:\PS> Import-LabADUser -Path .\unique.csv -OU DemoUsers
#>
function Import-LabADUser
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path,
 
        [Parameter(Mandatory=$true,
                   position=1,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   HelpMessage="Organizational Unit to save users.")]
        [String]
        [Alias('OU')]
        $OrganizationalUnit
    )
     
    begin {
        if (-not (Get-Module -Name 'ActiveDirectory')) {
            Write-Error -Message 'ActiveDirectory module is not present'
            return
        }
    }
     
    process {
        
        $data =
        Import-Csv -Path $Path | select  @{Name="Name";Expression={$_.Surname + ", " + $_.GivenName}},
                @{Name="SamAccountName"; Expression={$_.Username}},
                @{Name="UserPrincipalName"; Expression={$_.Username +"@" + $forest}},
                @{Name="GivenName"; Expression={$_.GivenName}},
                @{Name="Surname"; Expression={$_.Surname}},
                @{Name="DisplayName"; Expression={$_.Surname + ", " + $_.GivenName}},
                @{Name="City"; Expression={$_.City}},
                @{Name="StreetAddress"; Expression={$_.StreetAddress}},
                @{Name="State"; Expression={$_.State}},
                @{Name="Country"; Expression={$_.Country}},
                @{Name="PostalCode"; Expression={$_.ZipCode}},
                @{Name="EmailAddress"; Expression={$_.Username +"@" + $forest}},
                @{Name="AccountPassword"; Expression={ (Convertto-SecureString -Force -AsPlainText $_.password)}},
                @{Name="OfficePhone"; Expression={$_.TelephoneNumber}},
                @{Name="Title"; Expression={$_.Occupation}},
                @{Name="Path"; Expression={$OrganizationalUnit}},
                @{Name="Enabled"; Expression={$true}},
                @{Name="PasswordNeverExpires"; Expression={$true}} | ForEach-Object -Process {
                    $_ | New-ADUser 
                }
    }   
    end {}
}
 
<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function New-RandomADComputerAccount
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # Path where to create the computer accounts.
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]
        $Path
    )
 
    Begin {}
    Process
    {
        1..(Get-Random -Maximum 10 -Minimum 2) | foreach {
            $name = "TL$(Get-Random -Minimum 1000 -Maximum 99999)"
            try {
                New-ADComputer -OperatingSystem 'Mac OS X' -OperatingSystemVersion "10.$(Get-Random -Minimum 10 -Maximum 11).$(Get-Random -Minimum 0 -Maximum 5)" -SAMAccountName $name -Name $name -path $Path 
            } catch {
                Write-Warning -Message "Failed to create OS X account named $($name)"
            }
        }
 
        1..(Get-Random -Maximum 10 -Minimum 2) | foreach {
            $name = "TL$(Get-Random -Minimum 1000 -Maximum 99999)"
            try {
                New-ADComputer -OperatingSystem 'Windows 7 Enterprise' -OperatingSystemVersion '6.1 (7601)' -SAMAccountName $name -Name $name -OperatingSystemServicePack "Service Pack 1" -path $Path
            } catch {
                Write-Warning -Message "Failed to create Win7 account named $($name)"
            }
         }
 
        1..(Get-Random -Maximum 10 -Minimum 2) | foreach {
            $name = "TL$(Get-Random -Minimum 1000 -Maximum 99999)"
            try {
                New-ADComputer -OperatingSystem 'Windows 8.1 Enterprise' -OperatingSystemVersion '6.3 (9600)' -SAMAccountName $name -Name $name -path $Path
            } catch {
                Write-Warning -Message "Failed to create Win8.1 account named $($name)"
            }
        }
 
        1..(Get-Random -Maximum 10 -Minimum 2) | foreach {
            $name = "TL$(Get-Random -Minimum 1000 -Maximum 99999)"
            try {
                New-ADComputer -OperatingSystem 'Windows 10 Enterprise' -OperatingSystemVersion '10.0 (14393)' -SAMAccountName $name -Name $name -path $Path
            } catch {
                Write-Warning -Message "Failed to create Win10 account named $($name)"
            }
        }  
    }
    End {}
}
 
$Groups = @(
    'Sales',
    'Support',
    'IT',
    'Marketing',
    'Accounting',
    'Ops',
    'HR'
)
 
foreach($Group in $Groups) {
    Write-Host -Object "Creating $($Group) OU" -ForegroundColor Cyan
    New-ADOrganizationalUnit -Name $Group -Path "$DomainDN" -ProtectedFromAccidentalDeletion $false
    Write-Host -Object "Creating Computers OU for $($Group)" -ForegroundColor Cyan
    New-ADOrganizationalUnit -Name 'Computers' -Path "OU=$($Group),$($DomainDN)" -ProtectedFromAccidentalDeletion $false
    Write-Host -Object "Creating fake computers accounts for $($Group)." -ForegroundColor Cyan
    New-RandomADComputerAccount -Path "OU=Computers,OU=$($Group),$($DomainDN)"
    Write-Host -Object "Creating Users OU for $($Group)" -ForegroundColor Cyan
    New-ADOrganizationalUnit -Name 'Users' -Path "OU=$($Group),$($DomainDN)" -ProtectedFromAccidentalDeletion $false
    Import-LabADUser -Path "$($env:temp)\$($Group).csv" -OrganizationalUnit "OU=Users,OU=$($Group),$($DomainDN)"
    $NewGroup = New-ADGroup -Name $Group -GroupScope Global -GroupCategory Security -PassThru
    Get-ADUser -SearchBase "OU=Users,OU=$($Group),$($DomainDN)" -Filter * | foreach {Add-ADGroupMember $NewGroup -Members $_ }
}
 
Write-Host -Object "Creating Admin accounts for enumeration."
$DsktpAdmins = New-ADGroup -Name 'DesktopAdmins' -SamAccountName 'DesktopAdmins' -GroupCategory Security -Description 'Desktop support personel' -GroupScope Global -PassThru
$SrvAdmis = New-ADGroup -Name 'SrvAdmins' -SamAccountName 'SrvAdmins' -GroupCategory Security -Description 'Server Administrators' -GroupScope Global -PassThru
$DaGroup = Get-ADGroup -Identity "Domain Admins"
Get-ADGroupMember it | Select -First 3 |foreach {Add-ADGroupMember $DaGroup -Members $_}
Get-ADGroupMember it | Select -Index 2,3,4 |foreach {Add-ADGroupMember $SrvAdmis -Members $_}
Get-ADGroupMember it | Select -Index 5,6,7,8 |foreach {Add-ADGroupMember $DsktpAdmins -Members $_}
 
$Admin2Remove = Get-ADGroupMember it | Select -Index 2
Remove-ADGroupMember -Members $Admin2Remove -Identity $DaGroup -Confirm:$false
 
 
# Lab GPO add exception to Defender
Write-Host -Object "Creating Windows Defender Excusion GPO" -ForegroundColor Cyan
$WdExclusion = New-GPO -Name 'IT Tools Defender Exclusion' -Comment 'Folder not scanned or monitored by Windows Defender for IT tools'
Set-GPRegistryValue -Name $WdExclusion.DisplayName -Key 'HKLM\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths' -ValueName "C:\tools" -Type DWord -Value 0
Write-Host -Object "GPO with GUID $($WdExclusion.Id) created." -ForegroundColor Green
Write-Host -Object "Linking Windows Defender GPO to OUs" -ForegroundColor Cyan
New-GPLink -Guid $WdExclusion.Id -Target "OU=Computers,OU=IT,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $WdExclusion.Id -Target "OU=Computers,OU=Support,$($DomainDN)" -LinkEnabled Yes
 
# Lab GPO Disable WSH
$WshGPO = New-GPO -Name 'Disable WSH' -Comment 'Disable Windows Scripting Host'
Set-GPRegistryValue -Name $WshGPO.DisplayName -Key 'HKLM\Software\Microsoft\Windows Script Host\Settings' -ValueName 'Enabled' -Type DWord -Value 0
New-GPLink -Guid $WshGPO.Id -Target "OU=Computers,OU=Ops,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $WshGPO.Id -Target "OU=Computers,OU=Marketing,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $WshGPO.Id -Target "OU=Computers,OU=Accounting,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $WshGPO.Id -Target "OU=Computers,OU=Sales,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $WshGPO.Id -Target "OU=Computers,OU=HR,$($DomainDN)" -LinkEnabled Yes
 
# Lab GPO disable macros.
$MacroGPO = New-GPO -Name 'Disable Office Macros' -Comment 'Disable Office Macros'
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\14.0\MSProject\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\14.0\Excel\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\14.0\Word\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\14.0\PowerPoint\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\15.0\MSProject\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\15.0\Excel\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\15.0\Word\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\15.0\PowerPoint\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\16.0\MSProject\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\16.0\Excel\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\16.0\Word\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
Set-GPRegistryValue -Name $MacroGPO.DisplayName -Key 'HKCU\Software\Policies\Microsoft\Office\16.0\PowerPoint\Security' -ValueName 'VBAWarnings' -Type DWord -Value 4
New-GPLink -Guid $MacroGPO.Id -Target "OU=Users,OU=IT,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $MacroGPO.Id -Target "OU=Users,OU=Support,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $MacroGPO.Id -Target "OU=Users,OU=Ops,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $MacroGPO.Id -Target "OU=Users,OU=Marketing,$($DomainDN)" -LinkEnabled Yes
 
# Lab GPO for Logging PS Actions
$PSGPO = New-GPO -Name 'PowerShell Logging Settings' -Comment 'Logging settings for PowerShell'
Set-GPRegistryValue -Name $PSGPO.DisplayName -Key 'HKLM\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' -Type DWord -ValueName 'EnableScriptBlockLogging' -Value 1
Set-GPRegistryValue -Name $PSGPO.DisplayName -Key 'HKLM\Software\Policies\Microsoft\Windows\PowerShell\Transcription' -Type DWord -ValueName 'EnableTranscripting' -Value 1
Set-GPRegistryValue -Name $PSGPO.DisplayName -Key 'HKLM\Software\Policies\Microsoft\Windows\PowerShell\Transcription' -Type DWord -ValueName 'EnableInvocationHeader' -Value 1
New-GPLink -Guid $PSGPO.Id -Target "OU=Users,OU=IT,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $PSGPO.Id -Target "OU=Users,OU=Support,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $PSGPO.Id -Target "OU=Users,OU=Ops,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $PSGPO.Id -Target "OU=Users,OU=Marketing,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $PSGPO.Id -Target "OU=Computers,OU=HR,$($DomainDN)" -LinkEnabled Yes
New-GPLink -Guid $PSGPO.Id -Target "OU=Computers,OU=Accounting,$($DomainDN)" -LinkEnabled Yes