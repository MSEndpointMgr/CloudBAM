# BitLockerBackupPortal (CloudBAM)

Working on an automated installer - for now, if you want to test it, you need to do some very manual steps.
PErmissions and least privileged stuff is not tightend completely. Use at own risk.

### Quick and dirty install guide (parts might be missing, go fish) 

- Create a resource group in Azure to hold the components
  - Call it rg-bitlockerbackupportal (or update the FAConfig.xml accordingly)
- Create a LogAnalytics Workspace in this resource group
  - Call it la-bitlockerbackupportal (or update the FAConfig.xml accordingly)
  - Configure Azure AD diagnostics settings to send sign-in data to this workspace
  - Add the Workbook from the reports part of this repository
- Create a new Azure Function App
  - Call it something unique like fa-{yourTenantName}-cloudbam
  - Configure it for PowerShell 5.1 / Windows
  - Add a httpTrigger function and choose develop in portal
    - The name should be BitlockerPortal (unless you want to change the code).
    - Go into the new HttpTrigger and ender the "code+test" area and override the powershell code with the run.ps1 code found in the function folder of this repository.
  - Go to the function app authentication blade and enable app service authentication using redirect (Microsoft) and require authentication. 
    - Select all the defaults and let it create the required service principal for you
  - Enable a system managed identity for the function app
    - assign the Key Vault Secrets User role to the keyvault you setup for the BitLocker Backup automation KeyVault.
    - assign the Owner role for the Log Analytics workspace
  - Get the FAConfig.xml file from the repository and make sure the configured names are correct (they are if you have jsut used the names from the guides.
  - Upload the files FAConfig.xml, portal.html, profile.ps1, requirements.ps1 to the wwwroot folder of the function app - override the ones there already
    - You can use the advanced tool in the function app on the azure portal to drag and drop the files into the correct folder.
