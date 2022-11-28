#Requires -RunAsAdministrator
# Uninstall Dell Optimizer MSI
$Apps = @()
$Apps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
$Apps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$MSIRemove = $Apps | Where-Object { $_.Displayname -Match "Dell\s?Optimizer" -and $_.uninstallstring -match "msiexec" }
$MSIRemove | ForEach-Object { 
    $RemoveString = "/X $($_.PSChildName) REBOOT=ReallySuppress /QN"
    Write-Host "Starting removal of MSI $($_.PSChildName)"
    Start-Process "msiexec.exe" -ArgumentList $RemoveString -Wait
    Write-Host "Removed MSI $($_.PSChildName)"
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
    Write-Host "Starting removal of service"
    Start-Process -FilePath $UninstallEXE -ArgumentList $UninstallArg -Wait
    Write-Host "Removed service"
}

# Uninstall ExpressConnect
$ECRemove = $Apps | Where-Object { $_.Displayname -Match "ExpressConnect" -and $_.uninstallstring -match "msiexec" }
$ECRemove | ForEach-Object { 
    $RemoveString = "/X $($_.PSChildName) REBOOT=ReallySuppress /QN"
    Write-Host "Starting removal of ExpressConnect MSI $($_.PSChildName)"
    Start-Process "msiexec.exe" -ArgumentList $RemoveString -Wait
    Write-Host "Removed ExpressConnect MSI $($_.PSChildName)"
}
