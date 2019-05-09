<#PSScriptInfo
.VERSION .1
.AUTHOR Toby Scales
.COMPANYNAME Microsoft Corporation
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES

    Initial release.

#>
<#

.SYNOPSIS
    Configures a Subscription for use with the Azure/Terraform Enterprise DevOps Framework.

.DESCRIPTION

.PARAMETER AdditionalExtensions

.PARAMETER LaunchWhenDone

.EXAMPLE

.EXAMPLE

#>

$ErrorActionPreference='SilentlyContinue'

write-host "Checking Prerequisites..."
if (-not (get-module Az.Accounts)) { Install-Module -Name Az.Accounts -AllowClobber -Scope CurrentUser -repository PSGallery }
if (-not (get-module Az.Keyvault)) { Install-Module -Name Az.Keyvault -AllowClobber -Scope CurrentUser -repository PSGallery }
if (-not (get-module Az.Storage)) { Install-Module -Name Az.Storage -AllowClobber -Scope CurrentUser -repository PSGallery }
if (-not (get-module ASelfSignedCertificate)) { Install-Module -Name SelfSignedCertificate -AllowClobber -Scope CurrentUser -Repository PSGallery }

import-module az.accounts
import-module az.keyvault
import-module az.storage
import-module SelfSignedCertificate 

$startPath = $pwd.path
$configPath = "$($startPath.Substring(0, $startPath.indexof("live")))config"
#$subId = [regex]::Match($startPath, 's[0-9a-fA-F]{5}') #regex match the subscription ID in the path


if (-not (get-azsubscription)) {  
    Connect-AzAccount
}

$username = ((Get-Content -path "$configPath\globals.tfvars").ToLower() | Where-Object { ( (($_.StartsWith('user'))) ) }).split('=')[1].trim('"', ' ')
$password = Read-Host -Prompt "Please enter a password for the certificate." -AsSecureString

$subscriptions = Get-AzSubscription 

#TODO: add subscription creation option
do {
    $i = 1
    foreach ($sub in $subscriptions) {
        write-host "$($i) - $($sub.name)" 
        $i++
    }
    write-host -ForegroundColor Yellow "Please select the target subscription to configure"
    $i = read-host
    $selected_subscription = $subscriptions[$i-1]
    write-host -ForegroundColor yellow "Connecting to subscription $($selected_subscription.name)..."

} until ($selected_subscription)

set-azcontext -SubscriptionObject $selected_subscription > $null
$subalias = "s" + $selected_subscription.SubscriptionId.Substring(0,5)

#TODO: add key vault creation option
#TODO: show resource group next to key vault name
$keyvaults = get-azkeyvault | sort -Property VaultName
do {

    $i = 1
    foreach ($kv in $keyvaults | sort) {
        write-host "$($i) - $($kv.VaultName)" 
        $i++
    }
    write-host -ForegroundColor Yellow "Please select the deployment Key Vault"
    $i = read-host
    $selected_kv = $keyvaults[$i-1]
    write-host -ForegroundColor yellow "Connecting to Key Vault $($selected_kv.VaultName)..."

} until ($selected_kv)

#TODO: add storage account creation option
$storageaccts = Get-AzStorageAccount | sort -Property StorageAccountName
do {
    
    $i = 1
    foreach ($sa in $storageaccts) {
        write-host "$($i) - $($sa.StorageAccountName)" 
        $i++
    }
    write-host -ForegroundColor Yellow "Please select the storage account for tfstate files."
    $i = read-host
    $selected_sa = $storageaccts[$i-1]
    write-host -ForegroundColor yellow "Provisioning $($selected_sa.StorageAccountName)..."

} until ($selected_sa)

#TODO: investigate TF for certificate generation
$certificateName = "deployer.$subalias.$username.cert"
$now = [System.DateTime]::Now
$oneYearFromNow = $now.AddYears(1)

$certificateParams = @{
    StartDate = $now
    Duration = [timespan]::FromDays(365)
    Passphrase = $password
    CertificateFormat = 'Pfx' 
    KeyLength = 2048
    keyUsage = 'DigitalSignature'
    FriendlyName = "$certificateName"
}
#TODO: add error-checking to ensure cert is ACTUALLY created (false output from module)
$cert = New-SelfSignedCertificate @certificateParams -force -OutCertPath "$configPath\certs\$subalias.$username.pfx"
$certb64 = [System.Convert]::ToBase64String($cert.RawData)

#TODO: add error-checking/catching code
$mySP = Get-AzADServicePrincipal -DisplayName "deployer.$subalias.$username" 

if (-not $mySP) {
    #TODO: add SP to Management Group instead of direct assignment
    $mySP = New-AzADServicePrincipal -DisplayName "deployer.$subalias.$username" -role Contributor -scope "/subscriptions/$selected_subscription" -ErrorAction Stop 
}

write-host "Appending certificate for authentication..."
New-AzADSpCredential -ServicePrincipalName $mySP.ServicePrincipalNames[1] -CertValue $certb64 -StartDate $cert.NotBefore -EndDate $cert.NotAfter

$key1 = (Get-AzStorageAccountKey -ResourceGroupName $selected_sa.ResourceGroupName -Name $selected_sa.StorageAccountName).Value[0]

#add error-checking to ensure secrets are actually stored
write-host "Storing secrets..."
Set-AzKeyVaultSecret -VaultName $selected_kv.VaultName -name "$subalias-storageacct" -SecretValue (convertto-securestring $selected_sa.StorageAccountName -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $selected_kv.VaultName -name "$subalias-storagekey" -SecretValue (convertto-securestring $key1 -AsPlainText -Force)

Set-AzKeyVaultAccessPolicy -VaultName $selected_kv.VaultName -ServicePrincipalName $mySP.ServicePrincipalNames[1] -PermissionsToSecrets get

write-host "User deployer.$subalias.$username successfully configured to deploy to $($selected_subscription.Name) using $($selected_kv.VaultName)."

#TODO: optionally create/update secrets.tfvars