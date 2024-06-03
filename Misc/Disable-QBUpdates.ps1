<#PSScriptInfo

.VERSION 1.0

.GUID 2dec1f91-2c2c-4981-8565-b707b52fe98a

.AUTHOR Nate Cohen

#>

<#

.DESCRIPTION
 Prevent QuickBooks from installing automagic updates

#>

Get-process qbupdate | stop-process
Stop-Service -Name "QBUpdateMonitorService" -Force
Set-Service -Name "QBUpdateMonitorService" -StartupType Disabled

$QBFolder = Get-ChildItem -Path "$env:programdata\Intuit\" -Directory | Where-Object { $_.Name -match "^QuickBooks.*\d{2}(?:\.\d)?$" } | Sort-Object Name -Descending | Select-Object -First 1
$QBCFolder = Join-Path -Path $QBFolder.FullName -ChildPath "Components"
$QBDFolder = (Get-ChildItem -Path $QBCFolder -Directory | Where-Object { $_.Name -match "DownloadQB\d+" } | Sort-Object Name -Descending | Select-Object -First 1).FullName

Get-ChildItem -Path $QBDFolder -Recurse | Remove-Item -Force -Recurse

$acl = Get-Acl -Path $QBDFolder
$everyone = New-Object System.Security.Principal.NTAccount("Everyone")
$system = New-Object System.Security.Principal.NTAccount("SYSTEM")
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($everyone, "Write", "Deny")
$acl.SetAccessRule($accessRule)
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($system, "Write", "Deny")
$acl.SetAccessRule($accessRule)
Set-Acl -Path $QBDFolder -AclObject $acl

$QBUpdate = Join-Path -Path $QBCFolder -ChildPath "QBUpdate"

$QBchanFile = Join-Path -Path $QBUpdate -ChildPath "QBchan.dat"

if (Test-Path -Path $QBchanFile) {
    (Get-Content -Path $QBchanFile) -replace 'BackgroundEnabled=1', 'BackgroundEnabled=0' -replace 'DownloadDirectoryShared=1', 'DownloadDirectoryShared=0' | Set-Content -Path $QBchanFile
} else {
    New-Item -Path $QBUpdate -Name "QBchan.dat" -ItemType File -Value @"
[ChannelInfo]
BackgroundEnabled=0
DownloadDirectoryShared=0
"@
}
