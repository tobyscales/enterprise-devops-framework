# enterprise-devops-framework
Enterprise DevOps Framework for Infrastructure-as-Code using Terraform

The goal of this project is to allow for a more natural interface between Terraform and Azure.

Building on the framework established by [Gruntwork/terragrunt](https://www.gruntwork.io), we utilize a blended file structure that supports the use of Terraform modules (https://www.terraform.io/docs/modules/index.html) as well as “direct” Terraform configurations. 

Each subscription is represented by a single folder, which holds all resource groups underneath it as additional folders.

The *live* folder contains the currently deployed infrastructure code, while the *modules* folder contains generalized templates for use in multiple configurations.

Each pair-deployed Azure Subscription (prod/dev) has its own folder structure. This allows development to take place in the _dev folder without impacting production:

    live
    ├── 123de_This_Great_Subscription_dev 
    │   └── resource_group
    │   │      └── main.tf
    │   │      └── required.tf
    │   │      └── terraform.tfvars
    │   │      └── variables.tf
    ├── abc45_This_Great_Subscription_prod 
    │   └── resource_group
    │          └── main.tf
    │          └── required.tf
    │          └── terraform.tfvars
    │          └── variables.tf
    │   └── global.tfvars
    modules
    └── module_name
            └── main.tf
            └── variables.tf

Additionally, each subscription folder is prefixed with a 5-digit code based on the subscription GUID, which is referred to in this documentation as the "Subscription Alias." The Subscription Alias is used as a lookup value in the Terraform provider file, and generally as a lookup key for Key Vault access.

A separate directory contains configuration and secret files for managing all Azure subscriptions:

    config
    ├── tools 
    ├── certs
    │   └── s123de.pfx
    │   └── abc45.pf
    └── provider.tf
    └── secrets.tfvars
    └── globals.tfvars

A single, generic *provider.tf* file is used to provide access across all subscriptions. 

Subscription-specific secrets (such as client_id, tenant_id and subscription_id) are stored in *secrets.tfvars*. Terraform [backend configuration](https://www.terraform.io/docs/backends/types/azurerm.html) is stored in Key Vault, and *globals.tfvars* holds various global variables such as username and env.

All service authentication uses service principals and password-protected certificates, which are stored in the certs folder. The *tools* folder contains the shell scripts and cross-platform PowerShell that power the solution.

As such the ONLY information which needs to be secured on a developer machine is the /certs folder and the secrets.tfvars file. All other information may be safely checked into source control. Additionally, the information stored in secrets.tfvars is single-factor by design -- so in the event that it somehow(!) ended up in source control anyway, an attacker would not be able to gain access to the subscription without also securing the additional factor. 

This approach delivers solid MFA for developer deployments, without being a nuisance.


To set up the Enterprise DevOps Framework, simply git clone to your development server/repo, cd to the /config/tools folder and run "Initialize-EDOSubscription.ps1"

This script will perform the following actions:
 * Create a deployment Service Principal and grant it Contributor access to the selected Subscription. The deployment SP will be created with the following naming convention: deployer.subalias.username.
 * Store the accesskey and location of a Storage Account in a selected Key Vault, then grant the SP access to read those secrets.

 (These actions will be performed under the context of the logged-in user; so it is assumed they will be run by a user with User Administration Rights on the Subscription, Reader rights on the Storage Account and Owner permissions on the Key Vault.)

 Once the Initialize-EDOSubscription script has been run, the secrets.tfvars file and associated certificates can be distributed to developers *without granting them further access to the Azure subscription*. In other words, a central Azure Administrators team with "Ring 0" access can now delegate access to Ring 1 Terraform developers with ease.

!! To maintain full separation between authentication factors, never provide the certificates AND the certificate passwords in the same channel! Like, don't email them around, okay?

