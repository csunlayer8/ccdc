# MAKE YOU SET PASSWORDS FOR ALL USERS IN ORDER FOR THIS TO WORK PROPERLY
# I think I'll change to ToString instead of Second

$inilastPassR = Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName | Sort-Object | ForEach-Object {(Get-ADUser -Identity $_ -Properties PasswordLastSet | Select-Object -ExpandProperty PasswordLastSet).Second}
$index = 0

while ($true) {
    $adUsers = Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName | Sort-Object
    Write-Host -ForegroundColor Green "`nUSER PASSWORD MONITOR:"
	$getDate = Get-Date -Format "HH:mm:ss"
	Write-Host -ForegroundColor Yellow $getDate
    foreach ($adUser in $adUsers) {
		
        $lastPassR = (Get-ADUser -Identity $adUser -Properties PasswordLastSet | Select-Object -ExpandProperty PasswordLastSet).Second
		if($inilastPassR[$index] -ne $lastPassR){
			Write-Host -ForegroundColor Red $adUser"`a: $lastPassR"
		}
			
		if($inilastPassR[$index] -eq $lastPassR) {	
			Write-Host $adUser": $lastPassR"
		}
		
		$index++

    }

	$index = 0
    
    Start-Sleep -Seconds 10

}
