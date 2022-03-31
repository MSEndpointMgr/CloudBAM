# CloudBAM
CloudBAM is an Azure based cloud solution providing MBAM style functionality. The solution is aimed to be used as a suplementary solution for ensuring BitLocker recovery keys are available outside of Active / Azure Active Directory, while also ensuring that you can securely deliver BitLocker keys through limitation of access to users, and the use of multi-factor authentication.

> :warning: This code is very early alpha release - documentation and features are incomplete - PR's welcome.

From an architecture point of view, CloudBAM consists of;

- Azure KeyVault
- Azure Function App
- Azure Log Analytics Workspace
- Azure Automation

![alt text](https://github.com/MSEndpointMgr/CloudBAM/blob/main/Screenshots/CloudBAMArchitecture.jpg)

## Reporting ## 
As CloudBAM is based in Azure, reporting is done via integration with Log Analytics. Below is a screenshot of the reporting dashboad for CloudBAM, providing the following details

- Portal usage over time
- CloudBAM key retreivals 
- Recovery reasons used
- Recovery reasons over time
- Detailed actions

![alt text](https://github.com/MSEndpointMgr/CloudBAM/blob/main/Screenshots/Screenshot.jpg)

You can find the dashboard JSON code in the Reporting folder - https://github.com/MSEndpointMgr/CloudBAM/tree/main/Reporting

