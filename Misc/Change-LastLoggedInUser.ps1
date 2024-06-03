<#PSScriptInfo

.VERSION 1.0

.GUID ed665977-a2c8-40dd-8b79-670c61ce1c15

.AUTHOR Nate Cohen

#>

<#

.DESCRIPTION
 Change the last logged in user on the login screen

#>

$LastLoggedOnDisplayName = Read-Host "Enter the display name (typically first and last name)"
$LastLoggedOnSAMUser = Read-Host "Enter the username with domain like this syntax: domain\username"
try {
    $LastLoggedOnUserSID = (New-Object System.Security.Principal.NTAccount($LastLoggedOnSAMUser)).Translate([System.Security.Principal.SecurityIdentifier]).value
}
catch {
    Write-Host -ForegroundColor Red "Could not get the SID - domain trust potentially broken"
    $LastLoggedOnUserSID = Read-Host "Enter the SID manually"
}


write-host "[INFO] Changing the last logged on user to: " $LastLoggedOnDisplayName " | " $LastLoggedOnSAMUser
write-host "[INFO] Changing LastLoggedOnDisplayName registry key -> " -NoNewline
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnDisplayName /t REG_SZ /d $LastLoggedOnDisplayName /f
write-host "[INFO] Changing LastLoggedOnSAMUser registry key -> " -NoNewline
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnSAMUser /t REG_SZ /d $LastLoggedOnSAMUser /f
write-host "[INFO] Changing LastLoggedOnUser registry key -> " -NoNewline
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnUser /t REG_SZ /d $LastLoggedOnSAMUser /f
write-host "[INFO] Changing LastLoggedOnUserSID registry key -> " -NoNewline
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v LastLoggedOnUserSID /t REG_SZ /d $LastLoggedOnUserSID /f
