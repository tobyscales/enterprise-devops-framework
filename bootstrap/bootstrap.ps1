#region functions
Function Get-UserInputWithConfirmation($message) {
    $useThis = "N"
    while ("Y" -inotmatch $useThis) {
        clear-host
        $input = Read-Host $message
        $useThis = Read-Host "$input, is that correct?"
        switch ($useThis) {
            "Y" { }
            "N" { }
            default { $useThis = Read-Host "Please enter Y or N" }
        }
    }
    return $input
}
Function Get-UserInputList { 
    param (
        [Parameter(Mandatory,
            Position = 0)]
        [System.Object[]]$objects, 

        [Parameter(Mandatory,
            Position = 1)]
        [string[]]$message)

    #write-host $message
    if ($objects.count -lt 1) { Write-Error "None found." -ErrorAction Stop; return $false }
    #write-host $PSBoundParameters.Values
    #Format-Table $objects -AutoSize

    do {
        clear-host
        $i = 1
        $objects | ForEach-Object { $_ | Add-Member -NotePropertyName Choice -NotePropertyValue $i -Force -PassThru; $i++ } | select Choice, *Name | Out-Host
        $i = read-host -prompt $message
        $selected_object = $objects[$i - 1]

    } until ($selected_object)
    return $selected_object
}
#endregion functions

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted 

write-host "Checking Prerequisites..."
if (-not (get-module Az.Accounts)) { Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser }
if (-not (get-module Az.Keyvault)) { Install-Module -Name Az.Keyvault -AllowClobber -Scope CurrentUser } 
if (-not (get-module Az.Storage))  { Install-Module -Name Az.Storage -AllowClobber -Scope CurrentUser } 

import-module az.accounts
import-module az.keyvault
import-module az.storage

$startPath = (get-item $PSScriptRoot).Parent.FullName
$configPath = (join-path $startPath "config")
$scriptPath = (join-path $startPath "scripts")
$bootstrapPath = (join-path $startPath "bootstrap")

#deploy Ring0 resources
$ring0ctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select your Ring 0 Subscription"
Set-AzContext $ring0ctx
$ring0loc = Get-UserInputList (Get-AzLocation) -message "Select an Azure Region to deploy Ring0 Resources"
$ring0rg = Get-UserInputWithConfirmation -message "Enter a name for your Ring 0 resource group"
New-AzResourceGroup -Name $ring0rg -Location $ring0loc.Location
New-AzResourceGroupDeployment -TemplateFile (join-path $bootstrapPath ring0.json) -TemplateParameterFile (join-path $bootstrapPath ring0.parameters.json) -ResourceGroupName $ring0rg -AsJob

#deploy Ring1 resources
$ring1ctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select your Ring 1 Subscription"
Set-AzContext $ring1ctx
$ring1loc = Get-UserInputList (Get-AzLocation) -message "Select an Azure Region to deploy Ring1 Resources"
$ring1rg = Get-UserInputWithConfirmation -message "Enter a name for your Ring 1 resource group"
New-AzResourceGroup -Name $ring1rg -Location $ring1loc.Location
New-AzResourceGroupDeployment -TemplateFile (join-path $bootstrapPath ring1.json) -TemplateParameterFile (join-path $bootstrapPath ring1.parameters.json) -ResourceGroupName $ring1rg -AsJob

$ring0json = Get-content -raw (join-path $bootstrapPath ring0.parameters.json) | ConvertFrom-Json
$ring1json = Get-content -raw (join-path $bootstrapPath ring1.json) | ConvertFrom-Json

$ring0KeyVaultName = $ring0json.parameters.keyVaultName
$ring1KeyVaultName = $ring1json.parameters.keyVaultName

Set-AzKeyVaultAccessPolicy -VaultName $ring0KeyVaultName -UserPrincipalName $ring0ctx.Account.Id -PermissionsToCertificates get,list,delete,create,import,update 
#TODO: add ability to select multiple subscriptions at once?
#TODO: add subscription creation option?
#TODO: use pure Terraform for cert creation?
#$subs = Get-AzSubscription
#$vaults = Get-AzKeyVault
$storage_accts = Get-AzStorageAccount

#$ring0Subscription = $ring0ctx.Subscription ##Get-UserInputList $subs "Choose the Ring 0 Subscription"
#if (-not $ring0Subscription) { write-error "No Subscriptions found." -ErrorAction Stop }
#write-host -ForegroundColor yellow "Connecting to subscription $($ring0Subscription.name)..."

#set-azcontext -SubscriptionObject $ring0Subscription > $null

#$ring0KeyVault = Get-UserInputList $vaults "Choose the Ring 0 Key Vault"
#if (-not $ring0KeyVault) { write-error "No Keyvaults found." -ErrorAction Stop }

$targetSubscription =  $ring1ctx.Subscription ##Get-UserInputList $subs "Choose the Target Subscription"
if (-not $targetSubscription) { write-error "No Subscriptions found." -ErrorAction Stop }
write-host -ForegroundColor yellow "Connecting to subscription $($targetSubscription.name)..."

#$ring1KeyVault = Get-UserInputList $vaults "Choose the Ring 1 Key Vault for $($targetSubscription.name)"
#if (-not $ring1KeyVault) { write-error "No Keyvaults found." -ErrorAction Stop }

$tfStorageAccount = Get-UserInputList $storage_accts "Choose the Terraform State file Storage Account for $($targetSubscription.name)"
if (-not $tfStorageAccount) { write-error "No Storage Accounts found." -ErrorAction Stop }

$userName = Get-UserInputWithConfirmation "Enter the username to configure for $($targetSubscription.name)"

[string]$targetSubscriptionId = $targetSubscription.SubscriptionId
[string]$TFStorageAccountName = $tfStorageAccount.StorageAccountName

$EDOFargs= @{
    Username = $userName
    Ring0KeyVaultName = $ring0KeyVaultName
    Ring1KeyVaultName = $Ring1KeyVaultName
    targetSubscriptionId = $targetSubscriptionId
    TFStorageAccountName = $TFStorageAccountName
}

& (join-path $scriptPath "New-EDOFUser.ps1") @EDOFargs
