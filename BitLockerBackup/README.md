# CloudBAM Bitlocker Backup

Azure Automation solution for unattended archival of BitLocker keys from Azure AD to Azure KeyVault secrets.
Can be complemented by the CloudBAM Portal, but also run as a standalone archival solution if so required.

> :warning: This code is very early alpha release - documentation and features are incomplete - PR's welcome.

## Quick and dirty install guide (might be missing a few things)

- Create a Service Account (eg. SA_BitLockerBackup@tenant.onmicrosoft.com)
  - Assign the role: Cloud device administrator
- Create new Resource group
- Add Azure KeyVault to RG (Call it KV-BitlockerBackup or update the PowerShell code accordingly)
  - Configure KV to use RBAC model
- Add Azure Automation account to RG
  - Allow wizard to create RunAsAccount
    - Assign the following Graph API permissions to the App Registration of the RunAs account:
      - Delegated permission: BitlockerKey.Read.All
  - Enable System Manage Identity
    - Assign Azure role KeyVault Secrets Officer to the KeyVault you created earlier.
  - Add Credential to the Automation account
    - Call it BitlockerServiceAccount and enter the service account details into username and password
  - Add the Runbook powershell code from this repo to a RunBook using Powershell 5.1
  - Setup your desired schedule
