<#
.SYNOPSIS
    Azure automation script to archive BitLocker keys to Azure KeyVault secrets 
.DESCRIPTION
    Alpha release!!!
    Azure automation solution to run unattended backups on a schedule.
.NOTES
    Version:        0.1a
    Author:         Michael Mardahl
    Twitter: @michael_mardahl
    Blogging on: www.msendpointmgr.com
    Creation Date:  22th feb 2022
    Purpose/Change: Initial PoC

    Issues:
    Currently has an excessive amout of identities.
    Azure Automation RunAsAccount, Service Account and System Managed Identity.
    Uses the Az module which is terribly slow when going through tons of keys and validating on each runthrough.
    Need to convert the job to a workflow so state can be remembered.

    Script provided as-is without any warranty of any kind. Use it freely at your own risks.
    MIT License, feel free to distribute and use as you like, leave author information.
#>

#Requires -Version 3
#Requires -RunAsAdministrator

#region declarations
$connection = Get-AutomationConnection -Name AzureRunAsConnection
$Tenant = $connection.TenantID 
$AppId = $connection.ApplicationID
$graphVersion = 'v1.0'
$authenticationCredentials = Get-AutomationPSCredential -Name 'BitlockerServiceAccount'
$KeyVaultName = 'KV-BitlockerBackup'
$Expires = (Get-Date).AddYears(5).ToUniversalTime() #How long keys are stored in the vault.
$VerbosePreference = "SilentlyContinue"
#endregion declarations

#region execute


#Get delegated permissions for bitlocker key aquisition
$responseUserAuth = Get-MsalToken -ClientId $AppId -TenantId $Tenant -UserCredential $authenticationCredentials -ErrorAction Stop
$userAuthToken = @{
	"Content-Type" = "application/json"
	"Authorization" = $responseUserAuth.CreateAuthorizationHeader()
	"ExpiresOn" = $responseUserAuth.ExpiresOn.LocalDateTime
	"ocp-client-name" = "AA-BitlockerBackup-UserAuth"
    "ocp-client-version" = "1.0"
}

#Set the global script access token, for use with Invoke-MSGraphOperation
$Global:AuthenticationHeader = $userAuthToken
Write-Verbose "Got and set the authentication token" -Verbose

#Get list of all recovery key IDs
$recoveryKeysList = Invoke-MSGraphOperation -Get -APIVersion $graphVersion -Resource "/informationProtection/bitlocker/recoveryKeys" -ErrorAction Stop

#Connecting to Azure with Managed Identity
Connect-AzAccount -Identity

#Fetch all Bitlocker keys and store them in the Key Vault
$count = 0
foreach ($key in $recoveryKeysList) {
	$resource = '/informationProtection/bitlocker/recoveryKeys/{0}?$select=key' -f $key.Id
	$secret = Invoke-MSGraphOperation -Get -APIVersion $graphVersion -Resource $resource -ErrorAction Stop
	#Write-Output "$($secret.Id) : $($secret.Key)"
	$testForSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $($secret.Id)
	if(-not $testForSecret){
		Write-Verbose "New recovery key detected: Adding $($secret.Id) to vault" -Verbose
		Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "$($secret.Id)" -Expires $Expires -SecretValue $(ConvertTo-SecureString $secret.Key -AsPlainText -Force)
		$count++
	}
}
Write-Verbose "Completed operations for Bitlocker backup. $count Keys added." -Verbose
#endregion execute
