# CloudBAM
CloudBAM is an Azure based cloud solution providing MBAM style functionality. The solution is aimed to be used as a suplementary solution for ensuring BitLocker recovery keys are available outside of Active / Azure Active Directory, while also ensuring that you can securely deliver BitLocker keys through limitation of access to users, and the use of multi-factor authentication.

> :warning: This code is very early alpha release - documentation and features are incomplete - PR's welcome.
> This is a community solution, no official support is provided, but the solution is free to be used in production but not to be sold in any way.
> CloudBAM is a project run by Michael Mardahl and Maurice Daly

From an architecture point of view, CloudBAM consists of;

- ###Azure KeyVault
- ####Azure Function App
- ####Azure Log Analytics Workspace
- ####Azure Automation

![architecture overview](https://github.com/MSEndpointMgr/CloudBAM/blob/main/Screenshots/CloudBAMArchitecture.jpg)

### The solution as a whole has three parts

 - BitLockerBackup
   - Required to escrow the keys from Azure AD devices into Azure KeyVault.
 - BitLockerBackupPortal (CloudBAM Portal)
   - Optional component to search the archive and abstract access from Azure AD Roles.
 - LogAnalytics Workspace
   - A required component if you wish to have the portal, as all logging and auditing is done through LogAnalytics.

## CloudBAM Portal ##

The portal allows the user to search for a specific recovery key and/or search the entire archive using just the first few digits of a key.
> :warning: The portal is still undergoing heaby development, expect the first search to take at least 30-40 seconds.
> RBAC is currently only controllable through access to the Enterprise App created by the Function app provisioning.

![Recovery Key search in the portal](https://github.com/MSEndpointMgr/CloudBAM/blob/main/Screenshots/CloudBAM.jpg)
![Recovery Key search in the portal](https://github.com/MSEndpointMgr/CloudBAM/blob/main/Screenshots/CloudBAM2.jpg)
![Recovery Key search in the portal](https://github.com/MSEndpointMgr/CloudBAM/blob/main/Screenshots/CloudBAM3.jpg)

## Reporting ## 
As CloudBAM is based in Azure, reporting is done via integration with Log Analytics. Below is a screenshot of the reporting dashboad for CloudBAM, providing the following details

- Portal usage over time
- CloudBAM key retreivals 
- Recovery reasons used
- Recovery reasons over time
- Detailed actions

![alt text](https://github.com/MSEndpointMgr/CloudBAM/blob/main/Screenshots/Screenshot.jpg)

You can find the dashboard JSON code in the Reporting folder - https://github.com/MSEndpointMgr/CloudBAM/tree/main/Reporting

