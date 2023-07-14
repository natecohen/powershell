<#PSScriptInfo

.VERSION 1.0

.GUID a943aa07-9e93-4f96-9d53-2c8654b65786

.AUTHOR Nate Cohen

#>

<#

.DESCRIPTION
 Restrict access to common administrative PowerShell/CLI tools for Microsoft cloud environments

#>

#Requires -Modules AzureAD

[CmdletBinding()]
param(

    [Parameter()]
    [switch]$AllowSelf,

    [Parameter()]
    [String[]] $AllowedObjectIds

)

if (-not ($AllowSelf -or $AllowedObjectIds)) {
    throw "At least one parameter must be specified"
}

$AppList = @(
    [pscustomobject]@{AppName = "MSOL and Azure AD PowerShell Modules"; AppId = "1b730954-1685-4b74-9bfd-dac224a7b894" }
    [pscustomobject]@{AppName = "Microsoft Graph PowerShell"; AppId = "14d82eec-204b-4c2f-b7e8-296a70dab67e" }
    [pscustomobject]@{AppName = "Graph Explorer"; AppId = "de8bc8b5-d9f9-48b1-a8ad-b748da725064" }
    [pscustomobject]@{AppName = "Graph Explorer (secondary)"; AppId = "d3ce4cf8-6810-442d-b42e-375e14710095" }
    [pscustomobject]@{AppName = "Microsoft Intune PowerShell"; AppId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547" }
    [pscustomobject]@{AppName = "Azure CLI"; AppId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46" }
    [pscustomobject]@{AppName = "Azure PowerShell Module"; AppId = "1950a258-227b-4e31-a9cf-717495945fc2" }
    [pscustomobject]@{AppName = "Azure Management Portal"; AppId = "797f4846-ba00-4fd7-ba43-dac1f8f63013" }
    [pscustomobject]@{AppName = "Exchange Online PowerShell"; AppId = "fb78d390-0c51-40cd-8e17-fdbfab77341b" }      
)

$Session = Connect-AzureAD

$ObjectIdList = if ($AllowSelf) {
    (Get-AzureADUser -ObjectId $session.Account.Id).ObjectId
}
else {
    @()
}

if ($AllowedObjectIds) {
    $ObjectIdList += $AllowedObjectIds
}

foreach ($App in $AppList) {
    $AppID = $App.AppId
    $sp = Get-AzureADServicePrincipal -Filter "appId eq '$AppID'"
    if (-not $sp) {
        $sp = New-AzureADServicePrincipal -AppId $appId
    }
    $ExistingPid = (Get-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -all $true).principalid
    Set-AzureADServicePrincipal -ObjectId $sp.ObjectId -AppRoleAssignmentRequired $true
    $ObjectIdList | ForEach-Object {
        if ($ExistingPid -contains $_) {
            Write-Host "$($_) was already assigned to $($App.AppName)"
            continue
        }
        Write-Host "Assigning $($_) to $($App.AppName)"
        New-AzureADServiceAppRoleAssignment -ObjectId $sp.ObjectId -ResourceId $sp.ObjectId -Id ([Guid]::Empty.ToString()) -PrincipalId $_ 
    }
}
