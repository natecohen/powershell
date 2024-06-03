<#PSScriptInfo

.VERSION 1.0

.GUID 9fdbba42-0eff-4838-a2fb-5c396f783906

.AUTHOR Nate Cohen

#>

<#

.DESCRIPTION
 Clear Teams cache without removing custom backgrounds

#>

Get-Process -name teams, ms-teams | Stop-Process
Get-ChildItem -Path "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams" -Recurse | Where-Object { $_.FullName -notlike "*\Background*" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:LOCALAPPDATA\Packages\Microsoft.Win32WebViewHost_*\AC" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Office\16.0\WEF\webview2" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:APPDATA\Microsoft\Teams\IndexedDB\*" -Force -Recurse