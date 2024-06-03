<#PSScriptInfo

.VERSION 1.0

.GUID 8a8c074c-b67e-417f-922f-1dd52ca5aaaf

.AUTHOR Nate Cohen

#>

<#

.DESCRIPTION
 Export CSV of folders used for user profile data or folder redirects which have additional permissions added

#>

$BaseDomain = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).Split("\")[0]

# Replace this value with any directory containing home directories/folder redirects/other per user custom directories
$dirs = Get-ChildItem "D:\SHARES\UserShares" -Directory

$results = foreach ($dir in $dirs ) {

    $basename = $dir.BaseName

    $acls = ((get-acl $dir.FullName).Access | Where-Object { $_.identityreference -notmatch "^(NT|BUILTIN|CREATOR|S-1-5-21-|$([regex]::escape($BaseDomain))\\(Domain|Admin|$([regex]::escape($basename)))).*$" } | Select-Object -ExpandProperty identityreference) 

    if ($acls) {
        [pscustomobject]@{
            UserDir       = $dir.FullName
            HasCustomACLs = $acls
        }
    }

}

$results | Format-Table -AutoSize

$results | Select-Object userdir, @{N = "HasCustomACLs"; E = { $_.hascustomacls -join "," } } | Export-Csv ".\CustomACLs.csv" -NoTypeInformation -Encoding UTF8