<#PSScriptInfo

.VERSION 1.0

.GUID acd6e464-0393-461c-8440-629c6e5e79c0

.AUTHOR Nate Cohen

#>

<#

.DESCRIPTION
 Audit account which contain built-in privileged in Entra ID

#>

Connect-MgGraph -NoWelcome -ContextScope Process -Scopes Directory.Read.All, Organization.Read.All, User.Read.All, UserAuthenticationMethod.Read.All, AuditLog.Read.All

$roleNames = @("Application Developer", "Directory Synchronization Accounts", "Directory Writers", "Global Reader", "Partner Tier1 Support", "Partner Tier2 Support", "Security Operator", "Security Reader")

$uri = "https://graph.microsoft.com/v1.0"
$uriBeta = "https://graph.microsoft.com/beta"

$directoryRoles = (Invoke-MgGraphRequest -Method GET -Uri "$uri/directoryRoles").value

foreach ($role in $directoryRoles) {
	if (($role.displayName -like "*Administrator*") -or ($roleNames -contains $role.DisplayName)) {

		$roleMembers = (Invoke-MgGraphRequest -Method GET -Uri "$uri/directoryRoles/$($role.id)/members").value

		if ($roleMembers.Count -gt 0 ) {
			Write-Host "Role: $($role.DisplayName)"
			$memberInfo = @()

			foreach ($member in $roleMembers) {
				if ($member['@odata.type'] -eq "#microsoft.graph.user") {

					$memberId = $member.id
					
					$memberBetaDetails = (Invoke-MgGraphRequest -Method GET -Uri "$uriBeta/users/$memberId")

					$rawAuthMethods = (Invoke-MgGraphRequest -Method GET -Uri "$uri/users/$memberId/authentication/methods").value.("@odata.type")
					$fmtAuthMethods = $rawAuthMethods | ForEach-Object { [regex]::Match($_, "#microsoft\.graph\.(.*?)AuthenticationMethod").Groups[1].Value }
					$fmtAuthMethods = $fmtAuthMethods | Sort-Object -Unique

					try {
						$getsignInActivity = (Invoke-MgGraphRequest -Method GET -Uri "$uriBeta/users/$memberId`?`$select=signInActivity")
						$lastSigninUTC = $memberBetaDetails.signInActivity.lastSuccessfulSignInDateTime
						$lastSigninLocal = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($lastSigninUTC, (Get-TimeZone).id)
					} Catch {
						$lastSigninLocal = "Not Retrievable"
					}

					$skuParts = (Invoke-MgGraphRequest -Method GET -Uri "$uri/users/$memberId/licenseDetails").value.skuPartNumber

					$userData = [PSCustomObject]@{
						UPN         = $member.userPrincipalName
						DisplayName = $member.displayName
						LastSignIn  = $lastSigninLocal
						OnPremSync  = $memberBetaDetails.onPremisesSyncEnabled
						Licenses    = $skuParts
						AuthMethods = $fmtAuthMethods
					}
					$memberInfo += $userData
				}
			}
			$memberInfo | Format-Table -AutoSize
		}
	}
}
