if (!(Test-Path -Path "C:\output")) {
	New-Item -ItemType Directory -Path "C:\output"
	$getacl = (Get-Acl -path "$PSScriptRoot\Other\outputacl.txt")
	$getacl.SetAccessRuleProtection($true, $true)  
	Set-Acl -Path "C:\output" -AclObject $getacl
} 

#0a
function Unblock-Scripts {
	(Get-ChildItem -Filter * -Path $PSScriptRoot -Recurse).PSPath | ForEach-Object { Unblock-File $_ }
}

<# 

	More info about scripts in 
	CCDC Administration myBox

	NOTE: It probably isn't up-to-date

#>

<#

	NOTES ABOUT SCRIPT:
		- 3 and 4 use static names
		- Make sure you enter your credentials immediately if you launch scripts that require them
		- It's scuffed
		
#>

<#

	Brian Notes:
		- Import-File, Import-Module
		- Create web server with all files needed for comp
		- Get-EventLog for userlogonmonitor
		- psexec = SMB
		- remote shutdown = remote shutdown protocol
		- auto backup
		- auto remove user?
		- login attempt monitor (with windows event id)
		- msiexec
		- add groups automatically
		
Rahul Notes:
 - get-service | where-object (StartName -match "") | Sort-Object StartName |  Select-object Name, (#DisplayName), StartName | Fotmat-List

		COMMANDS:
			- Layer 1: ncpa.cpl, vCenter's Guest VM's NIC "Connected", get-netadapter
			- Layer 2: ipconfig, arp -a, (use ping <broadcast>)
			- Layer 3: ipconfig, ping, tracert, netstat
			- Layer 4: netstat, test-netconnection, telnet <port>
			- Layer 5-7: netstat -ano

#>

<#

	Import module commands start below

#>

# Will load all modules if you choose yes
$unblockScriptsCond = Read-Host "Unblock all scripts? (Use if you want to load all features) [Y/N]"
if ($unblockScriptsCond -eq "Y") {
	Unblock-Scripts
	$unblockScriptsCond = $true
}
elseif ($unblockScriptsCond -eq "N") {
	Write-Host -ForegroundColor Yellow "Ok"
	$unblockScriptsCond = $false
}
else {
	Write-Host -ForegroundColor Magenta "I'll do it anyways"
	Unblock-Scripts
	$unblockScriptsCond = $true
}

if ($unblockScriptsCond -eq $true) {
	Import-Module -Name "$PSScriptRoot\Private\lib\ImportExcel" -Verbose
	Import-Module -Name "$PSScriptRoot\Private\lib\PSWindowsUpdate" -Verbose
}

<#

	Import module commands end above

#>

<#

	Functions for command start below

	NOTES:
		- Comments above functions show which switch statement its linked to

#>

#1a
function Ping-LocalADMachines {
		
	$listArray = @()
	$numList = 1
	$1a = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name | Sort-Object -desc
	foreach ($1 in $1a) {
		"(" + $numList.ToString() + ")" + $1
		$numList++
		$listArray += $1
	}
		
	Write-Host "Choose a computer to ping"
	$choose = Read-Host
	$result = $listArray[$choose - 1]
	Test-NetConnection $result
}

#1b (Need to add other CIDR logic)
function Use-PingInfoView {
	
	Write-Host -ForegroundColor Yellow "If no IP address is returned you may have APIPA"
	[string]$subnetBinary = @()
	$count = 1
	$netAdapConf = Get-CimInstance Win32_NetworkAdapterConfiguration | Select-object IPSubnet
	$netAdapIP = Get-CimInstance Win32_NetworkAdapterConfiguration | Select-object IPAddress
	$netAdapDG = Get-CimInstance Win32_NetworkAdapterConfiguration | Select-Object DefaultIPGateway 
	Get-CimInstance Win32_NetworkAdapterConfiguration | Select-Object -ExpandProperty Description | ForEach-Object { Write-Output "[$count]$_"; $count++ }
	$cnetAdapConf = Read-Host "Choose a number"
	$netAdapConf = ($netAdapConf[$cnetAdapConf - 1]).IpSubnet | Where-Object { $_ -like "255.*" }
	$netAdapIP = ($netAdapIP[$cnetAdapConf - 1]).IPAddress | Where-Object { ($_ -like "192.*") -or ($_ -like "172.*") -or ($_ -like "10.*") }
	$netAdapDG = ($netAdapDG[$cnetAdapConf - 1]).DefaultIPGateway | Where-Object { ($_ -like "192.*") -or ($_ -like "172.*") -or ($_ -like "10.*") }
	$netAdapConf = $netAdapConf.Split('.') | ForEach-Object {
		[int]$_
		$num = $_
		if ($_ -lt 1) {
		}
		else {
			while ($num -gt 1) {
				$num = $num / 2
				$subnetBinary += "1"
			}
		}
	}
    
	$cidr = $subnetBinary.Length
	$cidrIP = $netAdapIP
	$cidrDG = $netAdapDG

	switch ($cidr) {
		24 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/24"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt" 

			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		23 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/23"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		22 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/22"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"

			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		21 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/21"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break
		}
		
		20 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/20"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"

			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		19 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/19"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break
		}
		
		18 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/18"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break
		}
		
		17 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/17"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"

			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		16 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/16"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"

			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		15 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP[1] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/15"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break
		}
		
		14 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP[1] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/14"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break
		}
		
		13 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP[1] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/13"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break
		}
		
		12 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP[1] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/12"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		11 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP[1] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/11"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		10 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP[1] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/10"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		9 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP[1] = $cidrDG
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/9"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt"
			
			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}
		
		8 {
			
			$cidrIP = $cidrIP.Split('.') 
			$cidrIP[3] = 0
			$cidrIP[2] = 0
			$cidrIP[1] = 0
			$cidrIP = $cidrIP -join '.'
			$cidrIP = "$cidrIP/8"
			$global:CIDRN = $cidrIP
			Start-Process -FilePath "pwsh" -ArgumentList $PSScriptRoot\Scripts\nmap.ps1
			$cidrIP | Out-File -FilePath "C:\output\tempCIDR.txt" 

			Set-Location $PSScriptRoot\Private\bin\PingInfoView\
			.\PingInfoView.exe /scomma "C:\output\tempPingList.csv"
			Invoke-Item "C:\output"
			.\PingInfoView.exe /loadfile "C:\output\tempCIDR.txt" /PingEverySeconds 5 /StartPingImmediately 1
			Set-Location $PSScriptRoot

			break

		}

	}

	#Add switch statement that determines format of IP address + CIDR into 

}

#2a
function Reset-LocalADUserPassword {
	
	[string]$adUserInput = Read-Host "Enter first initial (filters automatically)"
	$adUserInput = $adUserInput + "*"
	$getADUsers = Get-ADUser -Filter { Name -like $adUserInput } | Select-Object -ExpandProperty SamAccountName
	
	$count = 1

	foreach ($ADUser in $getADUsers) {
		Write-Host "[$count]$ADUser"
		$count++
	}

	Write-Host "Choose a user"
	$choose = Read-Host
	$result = $getADUsers[$choose - 1]
	$if = Read-Host "Change password on next logon? (Y/N)"
	if ($if -eq "Y") {
		if ((Get-ADUser -Identity $result -Properties PasswordNeverExpires | Select-Object -ExpandProperty PasswordNeverExpires) -eq $true) {
			Set-ADUser -Identity $result -PasswordNeverExpires 0
		}
		Set-ADAccountPassword -Credential $credential -Identity $result -Reset
		Set-ADUser -Credential $credential -Identity $result -ChangePasswordAtLogon 1
	}
	ElseIf ($if -eq "N") {
		Set-ADAccountPassword -Credential $credential -Identity $result -Reset
		Set-ADUser -Credential $credential -Identity $result -ChangePasswordAtLogon 0
	}
	Else {
		Write-Host -ForegroundColor Red "Incorrect value proceeding to password reset (User will change password on logon)"
		Set-ADAccountPassword -Credential $credential -Identity $result -Reset
		Set-ADUser -Credential $credential -Identity $result -ChangePasswordAtLogon 1
	}
	

}

#3a
function Invoke-PodGPUpdate {
	$condition = Read-Host "GPU and Restart Machines (Y/N)"
	if ($condition -eq "Y") {
		Invoke-GPUpdate NPOD1, NPOD2, NPOD3, NPOD4, WPOD1, WPOD2, WPOD3, WPOD4, LPOD1, LPOD2, LPOD3, LPOD4 -Force -Boot
	}
	ElseIf ($condition -eq "N") {
		Invoke-GPUpdate NPOD1, NPOD2, NPOD3, NPOD4, WPOD1, WPOD2, WPOD3, WPOD4, LPOD1, LPOD2, LPOD3, LPOD4 -Force
	}
	Else {
		Write-Host -ForegroundColor Red "Incorrect value proceeding to regular update"
		Invoke-GPUpdate NPOD1, NPOD2, NPOD3, NPOD4, WPOD1, WPOD2, WPOD3, WPOD4, LPOD1, LPOD2, LPOD3, LPOD4 -Force
	}
}

#4a
function Restart-Pods {
	Restart-Computer NPOD1, NPOD2, NPOD3, NPOD4, WPOD1, WPOD2, WPOD3, WPOD4, LPOD1, LPOD2, LPOD3, LPOD4 -Force -Confirm
}

#5a
function Set-ADUserAccountExpiration {
	$listArray = @()
	$numList = 1
	$5a = Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName | Sort-Object -desc
	foreach ($5 in $5a) {
		"(" + $numList.ToString() + ")" + $5
		$numList++
		$listArray += $5
	}
		
	Write-Host "Choose an OU"
	$choose = Read-Host
	$result = $listArray[$choose - 1]
	$users = @(Get-ADUser -Filter * -SearchBase $result | Select-Object -ExpandProperty SamAccountName | Sort-Object -desc)
	Write-Host -ForegroundColor Yellow "How powershell reads dates:'6/9/2069'"
	[string]$year = Read-Host "Enter year"
	[string]$month = Read-Host "Enter month (ADD '/' @ END)"
	[string]$day = Read-Host "Enter day(ADD '/' @ END)"
	[string]$date = $month + $day + $year
	foreach ($user in $users) {
		Set-ADAccountExpiration -Credential $credential -Identity $user -DateTime $date
	}
}

#6a
function Remove-ADAccountExpiration {
	$listArray = @()
	$numList = 1
	$6a = Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName | Sort-Object -desc
	foreach ($6 in $6a) {
		"(" + $numList.ToString() + ")" + $6
		$numList++
		$listArray += $6
	}
		
	$inp = Read-Host "Enter numbers"
	$numbers = $inp -split ', ' | Where-Object { $_ -ne "" } | ForEach-Object { [int]$_ }
	foreach ($number in $numbers) {
		Clear-ADAccountExpiration -Identity $listArray[$number - 1]
			
	}
		
}

#7a
function Set-ADAccountEmails {
	$listArray = @()
	$numList = 1
	$OUArr = Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName | Sort-Object -desc
	foreach ($OU in $OUArr) {
		"(" + $numList.ToString() + ")" + $OU
		$numList++
		$listArray += $OU
	}
	$choose = Read-Host "Choose OU"
	$result = $listArray[$choose - 1]
	Write-Host -ForegroundColor Yellow "$result CHOSEN"
	Get-ADUser -Filter * -SearchBase "$result" | Select-Object -ExpandProperty SamAccountName | ForEach-Object { Set-ADUser -Credential $credential -Identity $_ -EMailAddress "$_@CSUNLayer8.com" }
}

#8a
function New-ADUsers {

	#Delete the comment block below if you want to use this script outside the main script / I'm sending this standalone script to you
	#$credential = Get-Credential -Message "Enter Domain Admin credentials"
	
	<#
		HOW TO USE SCRIPT:
		1. Create a text file named users.txt
		2. Place users.txt in the same directory as this script
		3. Each line of the text file should contain a first and last name separated by a space
			- Example:
				John Doe
				Jane Smith
				Jim Brown
				Freddy von Fazbear -> (Incorrect format because it only takes first and last name, returns error message and stops script)
		4. Run the script
		
		WHAT THE SCRIPT DOES:
		1. Users will be created with the following format:
			- User Principal Name (UPN):
				- First initial + Last name + 0 + number (if needed) + @domain.com
				- Example:
					jdoe01@domain.com
		2. Default password for all users will be 'Password1!' and will require a change at next logon
		3. If a user with the same first initial and last name already exists, a number will be incremented until a unique UPN is found
			- Example:
				- If John Doe already exists as jdoe01@domain.com, the next user will be jdoe02@domain.com

		NOTES: 
		1. Script will wait indefinitely until users.txt is found in the script root
		2. Ensure you have the necessary permissions to create users in Active Directory
		3. Make sure to run this script in a secure environment as it handles user credentials
		4. Modify the default password in the script if needed for your security policies
		5. This script assumes you have the Active Directory module for PowerShell installed and imported

		KNOWN ISSUES: If someone with the first initial and last name but not the same full name exists, the script will still increment the number
			- Example:
				- If John Doe exists, and you try to create Jane Doe, it will create Jane Doe with a number appended (e.g., "Jane Doe 02")
			- How to remediate: Manually change the full name of the user in ADUC or PowerShell
	#>

	Write-Host -ForegroundColor Yellow "Looking for users.txt"
	if (!(Test-Path -Path "$PSScriptRoot\users.txt")) {
		Write-Host -ForegroundColor Red "`nPlease insert users.txt"
		Write-Host -ForegroundColor Yellow "`nScript will start automatically once the file is found within the script root"
		while (!(Test-Path -Path "$PSScriptRoot\users.txt")) {
		}
	}
	
	$secureStr = ConvertTo-SecureString -AsPlainText 'Password1!'
	$domainName = Get-ADDomain | Select-Object -ExpandProperty DNSRoot
	
	Write-Host -ForegroundColor Cyan "`nFound!"
	
	$users = Get-Content users.txt
	
	foreach ($user in $users) {
		
		$build = $user -Split " "
		
		if (!($build.Length -eq 2)) {
			Write-Host -ForegroundColor Red "Error occured with formatting. Please check your txt file"
			return
		}
		
		$fName = $build[0]
		$lName = $build[1]
		$fInit = $fName[0]
		
		$sameNameFlag = $true
		$count = 1
		
		try {
			New-ADUser -Name "$fName $lName" -AccountPassword $secureStr -ChangePasswordAtLogon $true -Credential $credential -DisplayName "$fName $lName" -Enabled $true -GivenName "$fName" -Surname "$lName" -UserPrincipalName ("$fInit" + "$lName" + "@$domainName") -EmailAddress ("$fInit" + "$lName" + "@$domainName") -ErrorAction Stop
			Set-ADUser -Identity "$fName $lName" -SamAccountName ("$fInit" + "$lName")
			Write-Host -ForegroundColor Cyan "Great!"
		}
		catch {
			while ($sameNameFlag -eq $true) {
				try {
					$count++
					New-ADUser -Name "$fName $lName 0$count" -AccountPassword $secureStr -ChangePasswordAtLogon $true -Credential $credential -DisplayName "$fName $lName" -Enabled $true -GivenName "$fName" -Surname "$lName" -UserPrincipalName ("$fInit" + "$lName" + "0$count" + "@$domainName") -EmailAddress ("$fInit" + "$lName" + "0$count" + "@$domainName") -ErrorAction Stop
					Set-ADUser -Identity "$fName $lName 0$count" -SamAccountName ("$fInit" + "$lName" + "0$count")
					Write-Host -ForegroundColor Cyan "Great!"
					if (!(Get-ADUser -Identity ("$fInit" + "$lName" + "0$count")) -eq $false) {
						$sameNameFlag = $false
					}
				}
				catch {
					continue
				}
			}
		}
	}
	
}

#66a
function Add-TrustedHosts {
	#Adds trusted hosts
	$addTH = Read-Host "Add trusted hosts"
	Set-Item WSMan:\localhost\Client\TrustedHosts -Value "$addTH" -Force
	
}

#100
function New-PSSessions {
	New-Item "$PSScriptRoot\PSSessions.txt" -ErrorAction SilentlyContinue
	
	if (Test-Path -Path "$PSScriptRoot\PSSessions.txt") {
		Clear-Content -Path "$PSScriptRoot\PSSessions.txt"
	}
	
	Write-Host -ForegroundColor Yellow "Looking for 'input.csv' in script root folder"
	while (!(Test-Path -Path "$PSScriptRoot\input.csv")) {
	}
	
	Write-Host -ForegroundColor Cyan "Found!"
	
	$split = Import-CSV "$PSScriptRoot\input.csv" | Select-Object -ExpandProperty "Host Name"
	
	foreach ($hostname in $split) {
		$hostname | Sort-Object | Out-File -FilePath "$PSScriptRoot\PSSessions.txt" -Append
	}
}

#100a
function Enable-PSRemotingInDomain {
	$location = (Get-Location).Path
	$distN = Get-ADDomain | Select-Object -ExpandProperty DistinguishedName
	Import-GPO -BackupGpoName 'Essentials' -TargetName 'Essentials' -Path "$location\Group Policy\Essentials" -CreateifNeeded
	New-GPLink -Name "Essentials" -Target "$distN" -LinkEnabled Yes
	gpupdate /force

}

#100ab (rushed)
function Disable-PSRemotingInDomain {
	$count = 1
	Remove-GPO "WinRM"
	Remove-GPO "RDP"
	Remove-GPO "Essentials"
	Get-ADComputer -Filter * | Select-Object -ExpandProperty Name | ForEach-Object {
		Invoke-Command -ScriptBlock { gpupdate /force } -ComputerName $_ -JobName "GPU$count" -AsJob
		$count++
	}

	gpupdate /force
}

#100b
function Install-ChocolateyInDomain {
	$newPSSessions = Get-Content "$PSScriptRoot\PSSessions.txt"
	Invoke-Command -ScriptBlock { Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) } -ComputerName $newPSSessions
}

#101a
function Get-InventoryDomainLocal {
		
	Write-Host -ForegroundColor Yellow "Script runs in background."
	
	Start-Job -Name "Get-InventoryDomainLocal" -ScriptBlock {
	
		$t = get-date -format yyyymmdd_HHmm
		$fileName = "invFile"
		
		if ((Test-Path -Path "C:\output\invFile.txt") -eq ($true)) {
			Clear-Content -Path "C:\output\invFile.txt"
		}
			
		$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
		
		foreach ($computer in $computers) {
			if ($computer -eq (Get-ComputerInfo | select-Object -ExpandProperty CsName)) {
				
				$ipAddress = Get-NetIPAddress | Select-Object -ExpandProperty IPv4Address | Where-Object { $_ -notlike "127.*" }
				$macAddress = Get-NetAdapter | select-Object -ExpandProperty MacAddress
				$osName = Get-ComputerInfo | Select-Object -ExpandProperty osname
						
			}
			else {
				try {
					$ipAddress = Invoke-Command -ComputerName $computer -ScriptBlock { Get-NetIPAddress | Select-Object -ExpandProperty IPv4Address | Where-Object { $_ -notlike "127.*" } } -ErrorAction Stop 
					$macAddress = Invoke-Command -ComputerName $computer -ScriptBlock { Get-NetAdapter | select-Object -ExpandProperty MacAddress } -ErrorAction Stop 
					$osName = Invoke-Command -ComputerName $computer -ScriptBlock { Get-ComputerInfo | Select-Object -ExpandProperty osname } -ErrorAction Stop 
				}
				catch {
					Write-Host -ForegroundColor Red "Something went wrong...is WinRM configured correctly on all machines/are the machines online?"	
					continue				
				}
			}
			
			$output = @($computer + ": " + $macAddress + ", " + $ipAddress + ", " + $osName)
			$dynamicFile += $output
			# Writing current user's PW to the PW file and loop to get the next user.
			$output | Out-File -FilePath "C:\output\$fileName.txt" -Append
		}

		# Writing out the dynamic file	
		$fileName = "invFile_$t"
		$dynamicFile | Out-File -FilePath "C:\output\$fileName.txt"
		Invoke-Item -Path "C:\output\"
	}	
}

#101b
function Get-InventoryDomainRemote {
	
	$newPSSessions = Get-Content "$PSScriptRoot\PSSessions.txt"
	Invoke-Command -ScriptBlock {
	
		Write-Host -ForegroundColor Yellow "Script runs in background."
	
		Start-Job -Name "Get-InventoryDomainLocal" -ScriptBlock {
	
			$t = get-date -format yyyymmdd_HHmm
			$fileName = "invFile"
		
			if ((Test-Path -Path "C:\output\invFile.txt") -eq ($true)) {
				Clear-Content -Path "C:\output\invFile.txt"
			}
			
			$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
		
			foreach ($computer in $computers) {
				if ($computer -eq (Get-ComputerInfo | select-Object -ExpandProperty CsName)) {
				
					$ipAddress = Get-NetIPAddress | Select-Object -ExpandProperty IPv4Address | Where-Object { $_ -notlike "127.*" }
					$macAddress = Get-NetAdapter | select-Object -ExpandProperty MacAddress
					$osName = Get-ComputerInfo | Select-Object -ExpandProperty osname
						
				}
				else {
					try {
						$ipAddress = Invoke-Command -ComputerName $computer -ScriptBlock { Get-NetIPAddress | Select-Object -ExpandProperty IPv4Address | Where-Object { $_ -notlike "127.*" } } -ErrorAction Stop 
						$macAddress = Invoke-Command -ComputerName $computer -ScriptBlock { Get-NetAdapter | select-Object -ExpandProperty MacAddress } -ErrorAction Stop 
						$osName = Invoke-Command -ComputerName $computer -ScriptBlock { Get-ComputerInfo | Select-Object -ExpandProperty osname } -ErrorAction Stop 
					}
					catch {
						Write-Host -ForegroundColor Red "Something went wrong...is WinRM configured correctly on all machines/are the machines online?"	
						continue				
					}
				}
			
				$output = @($computer + ": " + $macAddress + ", " + $ipAddress + ", " + $osName)
				$dynamicFile += $output
				# Writing current user's PW to the PW file and loop to get the next user.
				$output | Out-File -FilePath "C:\output\$fileName.txt" -Append
			}

			# Writing out the dynamic file	
			$fileName = "invFile_$t"
			$dynamicFile | Out-File -FilePath "C:\output\$fileName.txt"
			Invoke-Item -Path "C:\output\"
		}
	} -ComputerName $newPSSessions
}

#102a
function Set-RandomADPasswords {
	#add random characters

	do {
		$key = Read-Host "Insert key (will append to final passphrase) WILL PROMPT AGAIN IF NOT 8 CHARACTERS OR GREATER"
	}
	until($key.Length -gt 7)
	
	if (!(Test-Path -Path "C:\output")) {
		New-Item -ItemType Directory -Path "C:\output"
	} 
		
	$t = get-date -format yyyymmdd_HHmm
	$fileName = "pwFile"
		
	if ((Test-Path -Path "C:\output\pwFile.txt") -eq ($true)) {
		Clear-Content -Path "C:\output\pwFile.txt"
	}
		
	$Users = Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName
	foreach ($User in $Users) {
		$passphrase = $null
		$count = 0
		$noun = $null
		$verb = $null
		$adjective = $null
		# 3 words per passphrase logic
		while ($count -ne 3) {
			$txtFile = Get-Random -Max 4 -Min 1
			switch ($txtFile) {
				1 {
					# We don't want repeats of words
					if ($null -ne $noun) {
						break
					}
					$noun = Get-Random -InputObject (Get-Content "$PSScriptRoot\Passphrases\Nouns.txt")
					$count++
					$passphrase += $noun + "-"
				}

				2 {
					if ($null -ne $verb) {
						break
					} 
					$verb = Get-Random -InputObject (Get-Content "$PSScriptRoot\Passphrases\Verbs.txt")
					$count++
					$passphrase += $verb + "-"
			   
				}

				3 {
					if ($null -ne $adjective) {
						break
					}
					$adjective = Get-Random -InputObject (Get-Content "$PSScriptRoot\Passphrases\Adjectives.txt")
					$count++
					$passphrase += $adjective + "-"
				}

			}
		}
	
		#Builds the final passphrase and sets it
		if ($User -ne "layer8rules") {
			$passphrase += $key
			$securePassword = ConvertTo-SecureString -String $passphrase -AsPlainText -Force
			Set-ADAccountPassword -Identity $User -NewPassword $securePassword -Credential $credential
			$output = @("$User," + "$passphrase")
			$dynamicFile += $output
			# Writing current user's PW to the PW file and loop to get the next user.
			$output | Out-File -FilePath "C:\output\$fileName.txt" -Append
			Invoke-Item -Path "C:\output\"
		}
	}

	# Writing out the dynamic file
		
	$fileName = "pwFile_$t"
	$dynamicFile | Out-File -FilePath "C:\output\$fileName.txt"
	$dynamicFile | Out-File -FilePath "C:\output\$fileName.csv"

}

#103a
function Stop-SMBv1 {
	#Turns SMB1 off
	Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

	#Checks if SMB1 if off
	$test = (Get-SmbServerConfiguration).EnableSMB1Protocol 

	if ($test -eq $false) {
		Write-Host "Success"
	}
	else {
		Write-Host "Failure"
	}

}

#103b
function Stop-SMBv1Remote {
	$newPSSessions = Get-Content "$PSScriptRoot\PSSessions.txt"
	Invoke-Command -ScriptBlock {
		#Turns SMB1 off
		Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force

		#Checks if SMB1 if off
		$test = (Get-SmbServerConfiguration).EnableSMB1Protocol 

		if ($test -eq $false) {
			Write-Host "Success"
		}
		else {
			Write-Host "Failure"
		}
	} -ComputerName $newPSSessions -Credential $credential
	
}

#105a
function Install-Sysmon {
	#ADD PSSESIONS
	$SysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
	$CUrl = "https://github.com/SwiftOnSecurity/sysmon-config/archive/refs/heads/master.zip"
	$DownloadPath = "$env:TEMP\Sysmon.zip"
	$ExtractPath = "$env:TEMP\Sysmon"
	$CDownloadPath = "$env:TEMP\sysmon-config-master.zip"
	$CExtractPath = "$env:TEMP\sysmon-config-master"

	Invoke-WebRequest -Uri $SysmonUrl -OutFile $DownloadPath
	Expand-Archive -Path $DownloadPath -DestinationPath $ExtractPath -Force
	Invoke-WebRequest -Uri $CUrl -OutFile $CDownloadPath
	Expand-Archive -Path $CDownloadPath -DestinationPath $CExtractPath -force

     
	& "$ExtractPath\Sysmon64.exe" -i "$CExtractPath\sysmon-config-master\sysmonconfig-export.xml"

}

#108a
function Add-UsefulAccounts {

	$accountPss = Read-Host "Enter Jargin" -AsSecureString 
	New-ADUser -Name "layer8rules" -AccountPassword $accountPss -Credential $credential -Enabled 1
	New-ADUser -Name "Kevin" -AccountPassword $accountPss -Credential $credential -Enabled 1
	New-ADUser -Name "Jack" -AccountPassword $accountPss -Credential $credential -Enabled 1
	New-ADUser -Name "Roark" -AccountPassword $accountPss -Credential $credential -Enabled 1
	New-ADUser -Name "Roel" -AccountPassword $accountPss -Credential $credential -Enabled 1
	New-ADUser -Name "Jeffrey" -AccountPassword $accountPss -Credential $credential -Enabled 1
	New-ADUser -Name "Calvin" -AccountPassword $accountPss -Credential $credential -Enabled 1
	New-ADUser -Name "Alexander" -AccountPassword $accountPss -Credential $credential -Enabled 1
	New-ADUser -Name "Riley" -AccountPassword $accountPss -Credential $credential -Enabled 1
	Add-ADGroupMember -Identity "Administrators" -Members 'Kevin', 'Jack', 'Roark', 'Roel', 'Jeffrey', 'Calvin', 'Alexander', 'Riley' -Credential $credential
	Add-ADGroupMember -Identity "Domain Admins" -Members 'Kevin', 'Jack', 'Roark', 'Roel', 'Jeffrey', 'Calvin', 'Alexander', 'Riley' -Credential $credential
	Add-ADGroupMember -Identity "Enterprise Admins" -Members 'Kevin', 'Jack', 'Roark', 'Roel', 'Jeffrey', 'Calvin', 'Alexander', 'Riley' -Credential $credential
	Add-ADGroupMember -Identity "Schema Admins" -Members 'Kevin', 'Jack', 'Roark', 'Roel', 'Jeffrey', 'Calvin', 'Alexander', 'Riley' -Credential $credential
	Add-ADGroupMember -Identity "Group Policy Creator Owners" -Members 'Kevin', 'Jack', 'Roark', 'Roel', 'Jeffrey', 'Calvin', 'Alexander', 'Riley' -Credential $credential
	Add-ADGroupMember -Identity "Administrators" -Members 'layer8rules' -Credential $credential

	# 3 words per passphrase logic
	$numOfNames = 0

	do {
		$key = Read-Host "Insert key (will append to final passphrase) WILL PROMPT AGAIN IF NOT 8 CHARACTERS OR GREATER"
	}
	until($key.Length -gt 7)

	while ($numOfNames -lt 10) {
		$count = 0
		$passphrase = $null
		$noun = $null
		$verb = $null
		$adjective = $null
		while ($count -lt 3) {
			$txtFile = Get-Random -Max 4 -Min 1
			switch ($txtFile) {
				1 {
					# We don't want repeats of words
					if ($null -ne $noun) {
						break
					}
					$noun = Get-Random -InputObject (Get-Content "$PSScriptRoot\Passphrases\Nouns.txt")
					$count++
					$passphrase += $noun + "-"
				}

				2 {
					if ($null -ne $verb) {
						break
					} 
					$verb = Get-Random -InputObject (Get-Content "$PSScriptRoot\Passphrases\Verbs.txt")
					$count++
					$passphrase += $verb + "-"
			   
				}

				3 {
					if ($null -ne $adjective) {
						break
					}
					$adjective = Get-Random -InputObject (Get-Content "$PSScriptRoot\Passphrases\Adjectives.txt")
					$count++
					$passphrase += $adjective + "-"
				}

			}
	
		}
	
		#Builds the final passphrase and sets it
	
		$passphrase += $key
		$securePassword = ConvertTo-SecureString -String $passphrase -AsPlainText -Force
		$numOfNames++
		switch ($numOfNames) {
			1 {

				Set-ADAccountPassword -Identity "layer8rules" -NewPassword $securePassword -Credential $credential
				$output = @("layer8rules," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}

			2 {

				Set-ADAccountPassword -Identity "Kevin" -NewPassword $securePassword -Credential $credential
				$output = @("Kevin," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}

			3 {

				Set-ADAccountPassword -Identity "Jack" -NewPassword $securePassword -Credential $credential
				$output = @("Jack," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}

			4 {

				Set-ADAccountPassword -Identity "Roark" -NewPassword $securePassword -Credential $credential
				$output = @("Roark," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}

			5 {

				Set-ADAccountPassword -Identity "Roel" -NewPassword $securePassword -Credential $credential
				$output = @("Roel," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}

			6 {

				Set-ADAccountPassword -Identity "Jeffrey" -NewPassword $securePassword -Credential $credential
				$output = @("Jeffrey," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}

			7 {

				Set-ADAccountPassword -Identity "Calvin" -NewPassword $securePassword -Credential $credential
				$output = @("Calvin," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}

			8 {

				Set-ADAccountPassword -Identity "Alexander" -NewPassword $securePassword -Credential $credential
				$output = @("Alexander," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}

			9 {

				Set-ADAccountPassword -Identity "Riley" -NewPassword $securePassword -Credential $credential
				$output = @("Riley," + "$passphrase")
				$output | Out-File -FilePath "C:\output\AdminUsers.txt" -Append

			}
		}

	}

}


#111 
function Receive-Jobs {
	Receive-Job -Name *

}

<#

	Functions for commands end above

#>

Write-Host -ForegroundColor Red @"
                                                                                
                                       ,,,                                      
                                    ,,,,,,,,,                                   
                               ,,,,,,,,,,,,,,,,,,,                              
                       ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,                      
       ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,         ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,      
       ,,,,,,,,,,,,,,,,,,,,,,,       ,,,,,,.       ,,,,,,,,,,,,,,,,,,,,,,,      
       ,,,,,,,,,,,            ,,,,,,,,,,,,,,,,,,,,,            ,,,,,,,,,,,      
       ,,,,,,,    ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.    ,,,,,,,      
       .,,,,,,  ,,,,,,,,,,,,,,,,,@@@@@@@@@@@@@@@,,,,,,,,,,,,,,,,,  ,,,,,,       
        ,,,,,,  .,,,,,,,,,,,,,%@@@@@@@@@@@@@@@@@@@(,,,,,,,,,,,,,   ,,,,,,       
                 ,,,,,,,,,,,,@@@@@@@@*,,,,,/@@@@@@@@,,,,,,,,,,,,                
         ,,,,,,  ,,,,,,,,,,,,@@@@@@@,,,,,,,,,@@@@@@@,,,,,,,,,,,,  ,,,,,,        
        .,,,,,,   ,,,,,,,,,,,@@@@@@@,,,,,,,,*@@@@@@&,,,,,,,,,,,   ,,,,,,        
         ,,,,,,,  ,,,,,,,,,,,,,@@@@@@@@@@@@@@@@@@@,,,,,,,,,,,,,  ,,,,,,,        
         ,,,,,,,   ,,,,,,,,,,,,,@@@@@@@@@@@@@@@@@,,,,,,,,,,,,,   ,,,,,,.        
          ,,,,,,,  ,,,,,,,,,,@@@@@@@@@@@@@@@@@@@@@@@,,,,,,,,,,  ,,,,,,,         
          .,,,,,,.  ,,,,,,,,@@@@@@@,,,,,,,,,,,@@@@@@@,,,,,,,,  ,,,,,,,          
           ,,,,,,,   ,,,,,,,@@@@@@@,,,,,,,,,,,@@@@@@@,,,,,,,   ,,,,,,,          
            ,,,,,,,   ,,,,,,@@@@@@@@@,,,,,,,@@@@@@@@@,,,,,,   ,,,,,,,           
             ,,,,,,,   ,,,,,,/@@@@@@@@@@@@@@@@@@@@@*,,,,,,   ,,,,,,,            
              ,,,,,,,   ,,,,,,,,/@@@@@@@@@@@@@@@/,,,,,,,,   ,,,,,,,             
               ,,,,,,,,  ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,.  ,,,,,,,,              
                .,,,,,,,   ,,,,,,,,,,,,,,,,,,,,,,,,,,,   ,,,,,,,                
                  ,,,,,,,,   ,,,,,,,,,,,,,,,,,,,,,,,   ,,,,,,,,                 
                    ,,,,,,,,   .,,,,,,,,,,,,,,,,,    ,,,,,,,,                   
                     .,,,,,,,,,   ,,,,,,,,,,,,.   ,,,,,,,,,                     
                        ,,,,,,,,,,    ,,,,,    ,,,,,,,,,,                       
                          ,,,,,,,,,,,,     ,,,,,,,,,,,,                         
                             ,,,,,,,,,,,,,,,,,,,,,,,                            
                                 ,,,,,,,,,,,,,,,                                
                                      ,,,,,                                     
"@

<#

	Script execution starts below

#>

try {
	$credential = Get-Credential -Message "Enter Domain Admin credentials"
}
catch {
	Write-Host -ForegroundColor Yellow "No initial credential provided. This is fine."
}
powershell -file Help.ps1 -path $PSScriptRoot
$start = $true
while ($start -eq $true) {
	$num = Read-Host "Enter a command"
	switch ($num) {
		0a {
			
			Unblock-Scripts
			break
			
		}
		
		1a {
		
			Ping-LocalADMachines
			break

		}

		1b {

			Use-PingInfoView
			break

		}

	
		2a {
				
			Reset-LocalADUserPassword
			break

		}
	
		3a {
	
			Invoke-PodGPUpdate
			break

		}
		
		4a {
	
			Restart-Pods
			break

		}
	
		5a {
	
			Set-ADUserAccountExpiration
			break

		}
	
		6a {
			
			Remove-ADAccountExpiration
			break

		}
	
		7a {
	
			Set-ADAccountEmails
			break

		}

		8a {
			
			New-ADUsers
			break
		
		}
		
		<#
		
		Below are CCDC Scripts
		
		#>

		66a {

			Add-TrustedHosts
			break

		}
		
		100 {

			New-PSSessions
			break

		}
		
		100a {
		
			Enable-PSRemotingInDomain
			break
		
		}

		100ab {
			
			Disable-PSRemotingInDomain
			break

		}

		100b {

			Install-ChocolateyInDomain
			break
		}
		
		101a {
			
			Get-InventoryDomainLocal
			break
	
		}

		101b {

			Get-InventoryDomainRemote
			break

		}

		102a {
			
			Set-RandomADPasswords
			break

		}
		
		103a {

			Stop-SMBv1
			break

		}

		103b {

			Stop-SMBv1Remote
			break

		}

		104a {

			Start-Process -FilePath "powershell" -ArgumentList $PSScriptRoot\Scripts\userPasswordMonitor.ps1
			Start-Process -FilePath "powershell" -ArgumentList $PSScriptRoot\Scripts\userLogonMonitor.ps1
			break

		}

		105a {

			Install-Sysmon
			break

		}
		
		108a {
			
			Add-UsefulAccounts
			Invoke-Item -Path "C:\output\"
			break
			
		}

		111 {
        
			Receive-Jobs
			break
        
		}

		200a {

			netsh advfirewall set allprofiles state on
			netsh advfirewall reset
			Add-UsefulAccounts
			Stop-SMBv1
			Enable-PSRemotingInDomain

		}

		1000a {

			$sessions = Get-Content "$PSScriptRoot\PSSessions.txt"
			$credPath = "$env:TEMP\session-cred.xml"
			$credential | Export-Clixml -Path $credPath

			foreach ($session in $sessions) {
				Start-Process pwsh -ArgumentList "-NoExit", "-Command", "`$cred = Import-Clixml -Path '$credPath'; Enter-PSSession -ComputerName '$session' -Credential `$cred"
			}
			
			break

		}

		1000b {
			
			Set-Location ..
			$Session = New-PSSession -ComputerName (Get-Content "$PSScriptRoot\PSSessions.txt") -Credential $credential
			Copy-Item ".\Layer-8-PowerShell-Administration-main\" -Destination "C:\" -ToSession $Session -Recurse
			Set-Location ".\Layer-8-PowerShell-Administration-main\"

			break

		}

		#Help
		? {
	
			powershell -file Help.ps1 -path $PSScriptRoot
			break

		}
	
		?? {
		
			Write-Host -ForegroundColor Yellow "Local: Can only be run on computer connected to domain."
			Write-Host -ForegroundColor Yellow "Remote: Can be run on any machine connected to a network (Uses WinRM)"
			Write-Host -ForegroundColor Yellow "(UF): Unfinished"
			Write-Host -ForegroundColor Yellow "(NT): Not implemented"

		}

		<#
		??? {
			Get-Content "$PSScriptRoot\Functions.txt"
		}
		#>
		
		#Exit
		quit {
			
			$start = $false
			Remove-Item "$env:TEMP\session-cred.xml"
			break

		}
		
		#test switch
		#Function currently working on: 8a
		999 {
	
			$cidrN = Get-NetIPAddress -InterfaceAlias "Wi-Fi" -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress
			$cidrN = $cidrN -split "\."
			$cidrN | Where-Object { $_ -notlike $cidrN[3] }
			
		}
	
		default {
			Read-Host "Relaunch script: Invalid Number/Command (Press Enter)"
		}
	}

	<#

	Script execution ends above

#>


}
