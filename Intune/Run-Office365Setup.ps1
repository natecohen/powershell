[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Install", "Uninstall")]
    [string]$Mode
)

$Mode = $Mode.ToLower()

# Try to remove the built-in versions of Office
$OfficeUninstallStrings = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -Match "Microsoft 365" } | Select-Object UninstallString).UninstallString
if ($OfficeUninstallStrings) {
    if ($Mode -eq "install") {
        ForEach ($UninstallString in $OfficeUninstallStrings) {
            $UninstallEXE = ($UninstallString -split '"')[1]
            $UninstallArg = ($UninstallString -split '"')[2] + " updatepromptuser=false forceappshutdown=true DisplayLevel=False"
            Start-Process -FilePath $UninstallEXE -ArgumentList $UninstallArg -Wait -PassThru
        }
    }
}

# Download setup.exe
Start-Process "curl.exe" -ArgumentList "-o $($PSScriptRoot)\setup.exe --retry 15 --retry-max-time 0 --silent  https://officecdn.microsoft.com/pr/wsus/setup.exe" -Wait -PassThru
$p = Start-Process "$($PSScriptRoot)\setup.exe" -ArgumentList "/configure $($PSScriptRoot)\$Mode.xml" -Wait -PassThru
exit $p.ExitCode
