<#PSScriptInfo

.VERSION 2.0

.GUID a943aa07-9e93-4f96-9d53-2c8654b65786

.AUTHOR Nate Cohen

#>

<#

.DESCRIPTION
 Restrict access to common administrative PowerShell/CLI tools for Microsoft cloud environments

#>

#Requires -Modules Microsoft.Graph.Applications
#Requires -Modules Microsoft.Graph.Authentication
#Requires -Modules Microsoft.Graph.Users

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
    [pscustomobject]@{AppName = "Aadrm Admin PowerShell"; AppId = "90f610bf-206d-4950-b61d-37fa6fd1b224" }
    [pscustomobject]@{AppName = "Azure CLI"; AppId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46" }
    [pscustomobject]@{AppName = "Azure Management Portal"; AppId = "797f4846-ba00-4fd7-ba43-dac1f8f63013" }
    [pscustomobject]@{AppName = "Azure PowerShell Module"; AppId = "1950a258-227b-4e31-a9cf-717495945fc2" }
    [pscustomobject]@{AppName = "Exchange Online PowerShell"; AppId = "fb78d390-0c51-40cd-8e17-fdbfab77341b" }
    [pscustomobject]@{AppName = "Graph Explorer (secondary)"; AppId = "d3ce4cf8-6810-442d-b42e-375e14710095" }
    [pscustomobject]@{AppName = "Graph Explorer"; AppId = "de8bc8b5-d9f9-48b1-a8ad-b748da725064" }
    [pscustomobject]@{AppName = "Microsoft Graph PowerShell"; AppId = "14d82eec-204b-4c2f-b7e8-296a70dab67e" }
    [pscustomobject]@{AppName = "Microsoft Intune PowerShell"; AppId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547" } # Deprecated
    [pscustomobject]@{AppName = "Microsoft SharePoint Online Management Shell"; AppId = "9bc3ab49-b65d-410a-85ad-de819febfddc" }
    [pscustomobject]@{AppName = "MS Teams Powershell Cmdlets"; AppId = "12128f48-ec9e-42f0-b203-ea49fb6af367" }
    [pscustomobject]@{AppName = "MSCommerce Module"; AppId = "3d5cffa9-04da-4657-8cab-c7f074657cad" }
    [pscustomobject]@{AppName = "MSOL and Azure AD PowerShell Modules"; AppId = "1b730954-1685-4b74-9bfd-dac224a7b894" } # Deprecated
    [pscustomobject]@{AppName = "Office Management API Editor"; AppId = "389b1b32-b5d5-43b2-bddc-84ce938d6737" }
    [pscustomobject]@{AppName = "PnP Management Shell"; AppId = "31359c7f-bd7e-475c-86db-fdb8c937548e" }
)

Connect-MgGraph -Scopes Directory.ReadWrite.All, Application.ReadWrite.All, User.Read

$ObjectIdList = if ($AllowSelf) {
    (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me").id
} else {
    @()
}

if ($AllowedObjectIds) {
    $ObjectIdList += $AllowedObjectIds
}

foreach ($App in $AppList) {
    $AppID = $App.AppId
    $sp = Get-MgServicePrincipal -Filter "appId eq '$AppID'"
    if (-not $sp) {
        $sp = New-MgServicePrincipal -AppId $appId
    }
    $ExistingPid = (Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $sp.Id).PrincipalId
    Update-MgServicePrincipal -ServicePrincipalId $sp.Id -AppRoleAssignmentRequired:$True
    $ObjectIdList | ForEach-Object {
        if ($ExistingPid -contains $_) {
            Write-Host "$($_) was already assigned to $($App.AppName)"
            continue
        }
        Write-Host "Assigning $($_) to $($App.AppName)"
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ResourceId $sp.Id -AppRoleId ([Guid]::Empty.ToString()) -PrincipalId $_
    }
}
