
# Enterprise DevOps Framework for Infrastructure-as-Code using Terraform and Azure

The goal of this project is to allow for a more natural interface between Terraform and Azure.

This solution adapts the familiar concept of [Protection Rings](https://en.wikipedia.org/wiki/Protection_ring) to the cloud. At the center of the solution is a "ring0" Key Vault which stores the master credentials for less-privileged Service Principal accounts. A "ring1" Key Vault stores the configuration details necessary for proper Terraform operation (in this case the backend.tf configuration) and developers are only granted access to Azure through these Service Principal accounts.

Thus programmatic access is predictably granted and click-ops discouraged -- all without sacrificing security, auditability or ease-of-use.

![Solution Design](/media/Enterprise-Devops-Framework-Azure.png)

## Installing & Configuring
### Administrative Jumpbox Prerequisite: PowerShell Core
If you haven't already (and why haven't you??), install Powershell Core for your OS following [these instructions](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-6#powershell-core).

Your Jumpbox is used to configure new access for Terraform developers using the `New-EDOFUser.ps1` command.

For this first release, Developer PCs will also require PSCore installed. However that requirement will go away in the next release, when the Get-Config and Get-Backend logic are moved to an AAD-secured Azure Function.

### Bootstrap Configuration: Easy Button

The ring0 and ring1 resources can be deployed by clicking the buttons below. The paramter files in this repo utilize sensible defaults to install a ring0 key vault with audit logging (for storing authentication credentials), a ring1 key vault (for storing backend configuration) and a ring1 storage account for storing terraform.tfstate files. 

Ring 0: <a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftescales%2Fenterprise-devops-framework%2Fmaster%2Fbootstrap%2Fring0.json" target="_blank"> <img src="http://azuredeploy.net/deploybutton.png"/>  </a> 
Ring 1:<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftescales%2Fenterprise-devops-framework%2Fmaster%2Fbootstrap%2Fring1.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

Once you have deployed these Ring0/1 resources, you can [download](https://raw.githubusercontent.com/tescales/enterprise-devops-framework/master/scripts/New-EDOFUser.ps1) and run `New-EDOFUser.ps1` to create new users and assign them access. Additional information is available in the header of that script.

Once the process is complete and a new user is created, the secrets.tfvars file and associated certificates can be distributed to developers *without granting them further access to the Azure subscription*. In other words, a central Azure Administrators team with "Ring 0" access can now delegate access to Ring 1 Terraform developers with ease.

> !!! NOTE !!!
>To maintain full separation between authentication factors, never share the certificates AND the certificate passwords in the same communication channel! 
>
>Like-- don't email them around together, okay?

### Bootstrap Configuration: Great Power/Responsibility
For more control and/or ongoing production use, `git clone` this repo to your Administrative jumpbox and edit the parameter files in /bootstrap for your environment. Then run /scripts/bootstrap.ps1 to configure.

The bootstrap script will perform the following actions:
 * Deploy a "Ring0" and Ring1 Key Vault for storing credentials and backend configuration files, respectively.
 * Create the /live folder structure described below for selected Subscriptions.
 * Create a deployment Service Principal and grant it Contributor access to the target Subscription. 
   NOTE: The deployment SP will be created with the naming convention deployer.subalias.username.
 * Create a certificate in /certs/subalias.username.pfx with a randomized password which can be used to logon as the deployment SP.
 * Store the authentication certificate in the Ring0 KeyVault.
 * Store the accesskey for the Storage Account in the Ring1 Key Vault, and grant the SP access to read those secrets.


## File System Layout
Building on the framework established by [Gruntwork/terragrunt](https://www.gruntwork.io), the Enterprise DevOps Framework for Azure utilizes a blended file structure that supports the use of Terraform modules (https://www.terraform.io/docs/modules/index.html) as well as “direct” Terraform configurations. 

Each subscription is represented by a single folder, which holds all resource groups underneath it as additional folders.

The *live* folder contains the currently deployed infrastructure code, while the *modules* folder contains generalized templates for use in multiple configurations.

    live
    ├── s123de_This_Great_Subscription 
    │   └── resource_group_abc
    │   │      └── main.tf
    │   │      └── required.tf
    │   │      └── terraform.tfvars
    │   │      └── variables.tf
    │   └── resource_group_def
    │          └── main.tf
    │          └── required.tf
    │          └── terraform.tfvars
    │          └── variables.tf
    │   
    modules
    └── module_name
            └── main.tf
            └── variables.tf

Additionally, each subscription folder is prefixed with a 6-digit code based on the subscription GUID, which is referred to in this documentation as the "Subscription Alias." 

The Subscription Alias is used as a lookup value in the Terraform provider file, and as a lookup for secrets stored in Key Vault.

## Configuration Files
A separate directory contains configuration and secret files for managing all Azure subscriptions:

    config
    ├── scripts 
    ├── certs
    │   └── s123de.username.pfx
    │   └── sabc12.username.pfx
    └── provider.tf
    └── secrets.tfvars
    └── globals.tfvars

The *certs* folder contains [authentication certificates](#service-authentication--security) and the *scripts* folder contains the shell scripts and cross-platform PowerShell that power the solution.

Subscription-specific secrets (such as client_id, tenant_id and subscription_id) are stored in *secrets.tfvars*. Terraform [backend configuration](https://www.terraform.io/docs/backends/types/azurerm.html) is stored in the Ring1 Key Vault, and *globals.tfvars* holds various global variables such as username and env.

A single, generic *provider.tf* file provides access to all subscriptions. 

## Service Authentication & Security
The ONLY files which need to be secured on a developer machine are the pfx files in the /certs folder and the single secrets.tfvars file. All other files may be safely checked into source control.

All service authentication uses service principals and password-protected certificates, which are stored in the certs folder. 

Additionally, the information stored in secrets.tfvars is single-factor by design -- so in the event that it somehow(!) ended up in source control anyway, an attacker would not be able to gain access to the subscription without also securing the additional factor-- in this case, the certificate password. 

This approach delivers solid MFA for developer machines without being a nuisance.

## TODO:
 * Move Get-Backend logic into an Azure Function so the whole shebang can be run with shell/batch scripts and not require PSCore installed on Dev PCs.
 * Add support for deploying ARM templates
 * Add support for user access other than Contributor
 * Add support for Management Groups instead of direct assignment
 * Add certificate auto-renewal
 * Add ACME support for LetsEncrypt-signed certs
 * Initialize- script with automated subscription/ring1 resource and access creation