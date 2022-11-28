<#PSScriptInfo
.VERSION 1.0
.GUID 6d6e186b-92e3-4e44-a3a6-1f91b5d0d56f
.AUTHOR Nate Cohen
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Install", "Uninstall")]
    [string]$Mode,

    [Parameter(Mandatory)]
    [string]$PackageID,

    [Parameter()]
    [string]$OverrideString,

    [Parameter()]
    [string]$ParameterPassthru
)

function Test-RunningAsSystem {
    process {
        return ($(whoami -user) -match "S-1-5-18")
    }
}

$Mode = $Mode.ToLower()

$WingetArguments = "$Mode --id=$PackageID --exact --silent --accept-source-agreements"

if (Test-RunningAsSystem) {
    $ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
    if ($ResolveWingetPath) {
        $env:Path += ";$($ResolveWingetPath[-1].Path)"
    }
    else {
        Write-Error "Cannot find winget path"
        exit 1
    }
    Write-Host -ForegroundColor Yellow "Log files are located at $env:windir\Temp\WinGet\defaultState"
    if ($Mode -eq "install") {
        $WingetArguments += " --scope machine --accept-package-agreements"
    }
}
else {
    Write-Host -ForegroundColor Yellow "Log files are located at $env:localappdata\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
    if ($Mode -eq "install") {
        $WingetArguments += " --scope user --accept-package-agreements"
    }
}

if ($Mode -eq "install") {
    if ($OverrideString) {
        $WingetArguments += " --override `"$OverrideString`""
    }
}

if ($ParameterPassthru) {
    $WingetArguments += " $ParameterPassthru"
}

Write-Host -ForegroundColor Yellow "Using arguments: $WingetArguments"

$p = Start-Process winget.exe -ArgumentList $WingetArguments -NoNewWindow -Wait -PassThru
Write-Host "Exiting with code $($p.ExitCode)"
exit $p.ExitCode
