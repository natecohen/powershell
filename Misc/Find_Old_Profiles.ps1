<#PSScriptInfo

.VERSION 1.0

.GUID bc3fc940-7b28-4243-8bcc-23d20d62730f

.AUTHOR Nate Cohen

#>

<#

.DESCRIPTION
 Find FSLogix disks and folder redirect location held by disabled or deleted user accounts

#>

# Check if the script is running as administrator
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Relaunch as an elevated process:
    Start-Process powershell.exe "-File", ('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
    exit
}

$CurrentAuthDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()
$CurrentAuthDC = $CurrentAuthDomain.PdcRoleOwner.Name

try {
    Test-WSMan $CurrentAuthDC -ErrorAction Stop
}
catch {
    Write-Host "Could not remote into $($CurrentAuthDC)"
    Write-Host "Available domain controllers: $(($CurrentAuthDomain.DomainControllers.Name) -join ", ")"
    $CurrentAuthDC = Read-Host "Enter the hostname of another domain controller which has the WinRM service running"
}

$BaseDomain = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).Split("\")[0]

$AllADUsers = Invoke-Command -ComputerName $CurrentAuthDC -ScriptBlock { Get-ADUser -Filter * -Properties SamAccountName, SID, enabled, LastLogonDate }
$DisabledADUsers = $AllADUsers | Where-Object { $_.enabled -eq $false }
$EnabledADUsers = $AllADUsers | Where-Object { $_.enabled -eq $true }

# Run this script from the server where the disks are local to for best performance - avoid network share paths, use only local paths
$TopLevelFolders = @()

Write-Host "You will need to enter the path of each folder that contains subfolders for user profiles or folders containing VHD files."
Write-Host "Examples: F:\Shares\FolderRedirects or G:\Shares\ProfileDisks"
Write-Host "Press enter for empty input once finished."

while (1) {
    $PathInput = Read-Host "Enter path"
    if ( [string]::IsNullOrEmpty($PathInput) ) {
        break
    }
    else {
        $TopLevelFolders += $PathInput
    }
}

$TotalFolders = (Get-ChildItem $TopLevelFolders -Directory | Measure-Object).Count
$ProgressCounter = 0
$FoldersPotentialClean = @()
$RunningTotalBytes = 0

Function Format-FileSize() {
    Param ([uint64]$size)
    If ($size -gt 1TB) { [string]::Format("{0:0.00} TB", $size / 1TB) }
    ElseIf ($size -gt 1GB) { [string]::Format("{0:0.00} GB", $size / 1GB) }
    ElseIf ($size -gt 1MB) { [string]::Format("{0:0.00} MB", $size / 1MB) }
    ElseIf ($size -gt 1KB) { [string]::Format("{0:0.00} kB", $size / 1KB) }
    ElseIf ($size -gt 0) { [string]::Format("{0:0.00} B", $size) }
    Else { "" }
}


foreach ($Folder in $TopLevelFolders) {

    $UserDirs = Get-ChildItem -Path $Folder -Directory

    foreach ($UserDir in $UserDirs) {

        $ProgressPercent = ($ProgressCounter / $TotalFolders) * 100

        Write-Progress -Activity "Scanning $($UserDir.FullName)" -Status "$([math]::Round($ProgressPercent))% Complete:" -PercentComplete $ProgressPercent

        $UserFolderName = $UserDir.BaseName
        $SID = $null
        $MatchedUser = $null

        # Get only the part before the SID in the case of VHD folders
        if ($UserFolderName -match '(\S+)_(S-1.*)') {
            $UserFolderName = $Matches[1]
            $SID = $Matches[2]
        }

        # Prefer SID matching if it exists as it is more accurate on VHD
        if ($SID) {
            $MatchedUser = $EnabledADUsers | Where-Object { $_.SID -eq $SID }
        }
        else {
            $MatchedUser = $EnabledADUsers | Where-Object { ($_.samaccountname).ToLower() -eq $UserFolderName }
            $SID = ""
        }

        if (!($MatchedUser)) {

            if ($DisabledADUsers | Where-Object { ($_.samaccountname).ToLower() -eq $UserFolderName }) {
                $UserStatus = "Disabled"
                $LastLogon = ($DisabledADUsers | Where-Object { ($_.samaccountname).ToLower() -eq $UserFolderName }).LastLogonDate
            }
            elseif ($DisabledADUsers | Where-Object { $_.SID -eq $SID }) {
                $UserStatus = "Disabled"                
                $LastLogon = ($DisabledADUsers | Where-Object { $_.SID -eq $SID }).LastLogonDate
            }
            else {
                $UserStatus = "DoesNotExist"
                $LastLogon = $null
            }

            # Certain file types are excluded to reduce false positives
            $SubFileMostRecentAccessTime = (Get-ChildItem -Force $UserDir.fullname -file -depth 1 -Exclude desktop.ini, thumbs.db, *.bak, *.tmp, *.dll, *.lnk, *.url -ErrorAction SilentlyContinue | Sort-Object -Property lastaccesstime | Select-Object -Last 1).lastaccesstime
            $UserDirRootLastModifiedTime = (Get-Item -Force $UserDir.FullName).LastWriteTime

            $FolderCustomACLs = ((get-acl $UserDir.FullName).Access | Where-Object { $_.identityreference -notmatch "^(NT|BUILTIN|CREATOR|Everyone|S-1-5-21-\d|$([regex]::escape($BaseDomain))\\(Domain|Admin|$([regex]::escape($UserFolderName)))).*$" } | Select-Object -ExpandProperty identityreference) -join ";"

            $FolderTotalSize = (Get-ChildItem -Force $UserDir.fullname -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Sum Length).Sum

            $folder_details = [PSCustomObject]@{ 
                Path           = $UserDir.FullName
                LastFileAccess = $SubFileMostRecentAccessTime
                RootLastModify = $UserDirRootLastModifiedTime
                Size           = $FolderTotalSize
                UserState      = $UserStatus
                CustomACLs     = $FolderCustomACLs
                LastLogon = $LastLogon
            }

            $FoldersPotentialClean += $folder_details
            $RunningTotalBytes += $FolderTotalSize
        }

        $ProgressCounter += 1

    }

}
Write-Progress -Completed -Activity "Completed"

$DefaultOutputPath = split-path ($MyInvocation.MyCommand.Path) -Parent

$OutputPathInput = Read-Host "Enter path to save CSV file to or blank for same path as the script"
if ( [string]::IsNullOrEmpty($OutputPathInput) ) {
    $CSVOutputPath = $DefaultOutputPath
}
else {
    $CSVOutputPath = $OutputPathInput
    New-Item -ItemType Directory -Force -Path $CSVOutputPath | Out-Null
}

$CSVOutputFile = Join-Path -Path $CSVOutputPath -ChildPath "Old_User_Profiles.csv"

$FoldersPotentialClean | Export-Csv -NoTypeInformation -Encoding UTF8 $CSVOutputFile
$FoldersPotentialClean | Select-Object Path, LastFileAccess, RootLastModify, @{N = "Size"; E = { Format-FileSize($_.Size) } }, UserState, LastLogon, CustomACLs   | Format-Table -AutoSize
Write-Host "Potential savings:" $(Format-FileSize($RunningTotalBytes))
Write-Host "CSV was written to $($CSVOutputFile)"

Read-Host -Prompt "Press enter to continue"