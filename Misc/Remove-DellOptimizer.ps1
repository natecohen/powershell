<#PSScriptInfo

.VERSION 1.1

.GUID 857a3e32-f3ac-404a-b00d-b6c9aebf5a1a

.AUTHOR Nate Cohen

#>

#Requires -RunAsAdministrator

# Uninstall Dell Optimizer MSI
$Apps = @()
$Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
$Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$MSIRemove = $Apps | Where-Object { $_.Displayname -Match "Dell\s?Optimizer" -and $_.uninstallstring -match "msiexec" }
$MSIRemove | ForEach-Object { 
    $RemoveString = "/X $($_.PSChildName) REBOOT=ReallySuppress /QN"
    Write-Host "Starting removal of MSI $($_.DisplayName + " " + $_.PSChildName)"
    Start-Process "msiexec.exe" -ArgumentList $RemoveString -Wait
    Write-Host "Removed MSI $($_.DisplayName + " " + $_.PSChildName)"
}

# Uninstall Dell Optimizer UWP
$InstalledPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -match "DellOptimizer" }
$ProvisionedPackages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match "DellOptimizer" }

# Remove provisioned packages first
ForEach ($ProvPackage in $ProvisionedPackages) {
    Write-Host "Starting removal of APPX Provisioned $($ProvPackage.PackageName)"
    Remove-AppxProvisionedPackage -PackageName $ProvPackage.PackageName -Online
    Write-Host "Removed APPX Provisioned $($ProvPackage.PackageName)"
}
ForEach ($AppxPackage in $InstalledPackages) {
    Write-Host "Starting removal of APPX $($AppxPackage.PackageName)"
    Remove-AppxPackage -Package $AppxPackage.PackageFullName -AllUsers
    Write-Host "Removed APPX $($AppxPackage.PackageFullName)"
}

# Uninstall Dell Optimizer Service
$ServiceRemove = ($Apps | Where-Object { $_.Displayname -Match "Dell\s?Optimizer\s?Service" })
$ServiceRemove | ForEach-Object { 
    $UninstallEXE = ($_.UninstallString -split '"')[1]
    $UninstallArg = "/silent" + ($_.UninstallString -split '"')[2]
    Write-Host "Starting removal of $($_.DisplayName)"
    Start-Process -FilePath $UninstallEXE -ArgumentList $UninstallArg -Wait
    Write-Host "Removed $($_.DisplayName)"
}

# Uninstall ExpressConnect
$ECRemove = $Apps | Where-Object { $_.Displayname -Match "ExpressConnect" -and $_.uninstallstring -match "msiexec" }
$ECRemove | ForEach-Object { 
    $RemoveString = "/X $($_.PSChildName) REBOOT=ReallySuppress /QN"
    Write-Host "Starting removal of MSI $($_.DisplayName + " " + $_.PSChildName)"
    Start-Process "msiexec.exe" -ArgumentList $RemoveString -Wait
    Write-Host "Removed MSI $($_.DisplayName + " " + $_.PSChildName)"
}

# Final cleanup
uninstall-Package -name "ExpressConnect Drivers & Services" -allversions -force -ErrorAction SilentlyContinue
uninstall-Package -name "Dell Optimizer service" -allversions -force -ErrorAction SilentlyContinue
uninstall-Package -name "DellOptimizerui" -allversions -force -ErrorAction SilentlyContinue

Write-Host "Cleaning up install folders"
$AllUninstallers = $MSIRemove + $ServiceRemove + $ECRemove
$AllUninstallers | ForEach-Object {
    if ($_.InstallLocation) {
        Remove-Item -Recurse -Force -Path $_.InstallLocation -ErrorAction SilentlyContinue
    }
    if ($_.InstallSource) {
        Remove-Item -Recurse -Force -Path $_.InstallSource -ErrorAction SilentlyContinue
    }
}
