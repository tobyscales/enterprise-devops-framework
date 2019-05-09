
# Enterprise DevOps Framework for Infrastructure-as-Code using Terraform and Azure

The goal of this project is to allow for a more natural interface between Terraform and Azure.

This solution adapts the familiar concept of [Protection Rings](https://en.wikipedia.org/wiki/Protection_ring) to the cloud. At the center of the solution is a "ring0" Key Vault which stores the deployment secrets necessary for proper Terraform operation (in this case the backend.tf configuration) but limits access to named service prinipals, allowing for easy auditing of deployment operations.

![Solution Design](/media/Enterprise-Devops-Framework-Azure.png)

## Installing & Configuring
### Bootstrap Configuration: Ring0 Resources

The ring0 resource and associated logging can be deployed by clicking the button below, which utilizes sensible defaults to install the ring0 key vault in the subscription and region of your choice. Alternatively, you can download the templates directly and modify them as you like.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftescales%2Fenterprise-devops-framework%2Fmaster%2Fbootstrap%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

### Developer PC Prerequisite: Install PowerShell Core
If you haven't already (and why haven't you??), install Powershell Core for your OS following [these instructions](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-6#powershell-core).

(Obviously you're also going to need [terraform](https://www.terraform.io/downloads.html) installed in your path somewhere.)

Once that's done, simply 
`git clone https://github.com/tescales/enterprise-devops-framework.git` on your development machine, cd to the /bootstrap folder and run 

```
./Set-EDOFSubscription.ps1
```

This script will perform the following actions:
 * Deploy a "Ring0" Key Vault and Storage Account for storing secrets and tfstate files, respectively.
 * Create the /live folder structure described above for selected Subscriptions.
 * Create a deployment Service Principal and grant it Contributor access to selected Subscriptions. The deployment SP will be created with the following naming convention: deployer.subalias.username.
 * Store the accesskey for the Storage Account in the Ring0 Key Vault, then grant the SP access to read those secrets.
 * Create a self-signed certificate in /certs/subalias.username.pfx which can be used to securely access the configuration information.

 (NOTE: These actions will be performed under the context of the logged-in user; so it is assumed they will be run by a user with User Administration Rights on the Subscription, Reader rights on the Storage Account and Owner permissions on the Key Vault.)

 Once the Initialize-EDOSubscription script has been run, the secrets.tfvars file and associated certificates can be distributed to developers *without granting them further access to the Azure subscription*. In other words, a central Azure Administrators team with "Ring 0" access can now delegate access to Ring 1 Terraform developers with ease.

> !!! NOTE !!!
>To maintain full separation between authentication factors, never share the certificates AND the certificate passwords in the same communication channel! 
>
>Like-- don't email them around together, okay?

## File System Layout
Building on the framework established by [Gruntwork/terragrunt](https://www.gruntwork.io), we utilize a blended file structure that supports the use of Terraform modules (https://www.terraform.io/docs/modules/index.html) as well as “direct” Terraform configurations. 

Each subscription is represented by a single folder, which holds all resource groups underneath it as additional folders.

The *live* folder contains the currently deployed infrastructure code, while the *modules* folder contains generalized templates for use in multiple configurations.

Each pair-deployed Azure Subscription (prod/dev) has its own folder structure. This allows development to take place in the _dev folder without impacting production:

    live
    ├── s123de_This_Great_Subscription_dev 
    │   └── resource_group
    │   │      └── main.tf
    │   │      └── required.tf
    │   │      └── terraform.tfvars
    │   │      └── variables.tf
    ├── sabc45_This_Great_Subscription_prod 
    │   └── resource_group
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

The Subscription Alias is used as a lookup value in the Terraform provider file, and generally as a lookup key for secrets stored in Key Vault.

## Configuration Files
A separate directory contains configuration and secret files for managing all Azure subscriptions:

    config
    ├── tools 
    ├── certs
    │   └── s123de.username.pfx
    │   └── sabc12.username.pfx
    └── provider.tf
    └── secrets.tfvars
    └── globals.tfvars


The *certs* folder contains [authentication certificates](#service-authentication--security) and the *tools* folder contains the shell scripts and cross-platform PowerShell that power the solution.

Subscription-specific secrets (such as client_id, tenant_id and subscription_id) are stored in *secrets.tfvars*. Terraform [backend configuration](https://www.terraform.io/docs/backends/types/azurerm.html) is stored in Key Vault, and *globals.tfvars* holds various global variables such as username and env.

A single, generic *provider.tf* file provides access to all subscriptions. 

## Service Authentication & Security
The ONLY files which need to be secured on a developer machine are the pfx files in the /certs folder and the single secrets.tfvars file. All other files may be safely checked into source control.

All service authentication uses service principals and password-protected certificates, which are stored in the certs folder. 

Additionally, the information stored in secrets.tfvars is single-factor by design -- so in the event that it somehow(!) ended up in source control anyway, an attacker would not be able to gain access to the subscription without also securing the additional factor-- in this case, the certificate password. 

This approach delivers solid MFA for developer machines without being a nuisance.

## TODO:
 * Add support for ARM templates
 * Move Get-Backend logic into an Azure Function so the whole shebang can be run with shell/batch scripts and not require PSCore installed locally.
 * Update with Bootstrap deployer
 * Set- or Grant- script with optional parameters for: ring0 KV, Deployer ManagementGroup, TFstate-per-sub, etc.
 * Initialize- script with subscription creation & MG assignment