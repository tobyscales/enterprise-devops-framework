#region functions
Function Get-UserInputWithConfirmation($message) {
    $useThis = "N"
    $userinput = ""
    while ("Y" -inotmatch $useThis) {
        $null = clear-host #terrible bug in PS Clear-Host: https://github.com/PowerShell/PowerShell/issues/10181
        $userinput = Read-Host $message
        $useThis = Read-Host "$userinput, is that correct?"
        switch ($useThis) {
            "Y" { }
            "N" { }
            default { $useThis = Read-Host "Please enter Y or N" }
        }

    }
    return $userinput
}
Function Get-UserInputList { 
    param (
        [Parameter(Mandatory,
            Position = 0)]
        $objects, 

        [Parameter(Mandatory,
            Position = 1)]
        [string[]]$message)

    if ($objects.count -lt 1) { Write-Error "None found." -ErrorAction Stop; return $false }
    $null = clear-host #terrible bug in PS Clear-Host: https://github.com/PowerShell/PowerShell/issues/10181
    
    do {
        $i = 1
        $objects | ForEach-Object { $_ | Add-Member -NotePropertyName Choice -NotePropertyValue $i -Force -PassThru; $i++ } | Select Choice, *Name | Out-Host
        [int]$userinput = read-host -prompt $message
        if ($userinput -notmatch '\d+' ) { $userinput = read-host -prompt "Please enter a number" }

    } until (($userinput -match '\d+') -and ($userinput -lt ($i+1)))

    $selected_object = $objects[$userinput - 1] 
    
    return ($selected_object)
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

$rootPath = (get-item $PSScriptRoot).Parent.FullName
$bootstrapPath = (join-path $rootPath "bootstrap")
$configPath    = (join-path $rootPath "config")
$certPath      = (join-path $rootPath "certs")
$livePath      = (join-path $rootPath "live")
$scriptPath    = (join-path $rootPath "scripts")

new-item -ItemType Directory -Path $configPath -force | Out-Null
new-item -ItemType Directory -Path $certPath -force | Out-Null
new-item -ItemType Directory -Path $livePath -force | Out-Null

$ring0json = Get-content -raw (join-path $bootstrapPath ring0.parameters.json) | ConvertFrom-Json
$ring1json = Get-content -raw (join-path $bootstrapPath ring1.parameters.json) | ConvertFrom-Json

$ring0KeyVaultName = $ring0json.parameters.keyVaultName.value
$ring1KeyVaultName = $ring1json.parameters.keyVaultName.value

#deploy Ring0 resources
$ring0ctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select your Ring 0 Subscription"
Set-AzContext -Context $ring0ctx

$ring0loc = Get-UserInputList (Get-AzLocation) -message "Select an Azure Region to deploy Ring0 Resources"
$ring0rg = Get-UserInputWithConfirmation -message "Enter a name for your Ring 0 resource group"

New-AzResourceGroup -Name $ring0rg -Location $($ring0loc.Location)
New-AzResourceGroupDeployment -TemplateFile (join-path $bootstrapPath ring0.json) -TemplateParameterFile (join-path $bootstrapPath ring0.parameters.json) -ResourceGroupName $ring0rg #-AsJob

Set-AzKeyVaultAccessPolicy -VaultName $ring0KeyVaultName -UserPrincipalName $ring0ctx.Account.Id -PermissionsToSecrets get,list,set,delete -PermissionsToKeys get,list,update,create,import,delete -PermissionsToCertificates get,list,update,create,import,delete

#deploy Ring1 resources
$ring1ctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select your Ring 1 Subscription"
$ring1Subscription = $ring1ctx.Subscription 
if (-not $ring1Subscription) { write-error "No Subscriptions found." -ErrorAction Stop }
write-host -ForegroundColor yellow "Connecting to subscription $($ring1Subscription.name)..."
Set-AzContext -Context $ring1ctx

$ring1loc = Get-UserInputList (Get-AzLocation) -message "Select an Azure Region to deploy Ring1 Resources"
$ring1rg = Get-UserInputWithConfirmation -message "Enter a name for your Ring 1 resource group"

New-AzResourceGroup -Name $ring1rg -Location $($ring1loc[-1].Location)
New-AzResourceGroupDeployment -TemplateFile (join-path $bootstrapPath ring1.json) -TemplateParameterFile (join-path $bootstrapPath ring1.parameters.json) -ResourceGroupName $ring1rg #-AsJob

Set-AzKeyVaultAccessPolicy -VaultName $ring1KeyVaultName -UserPrincipalName $ring1ctx[-1].Account.Id -PermissionsToSecrets get,list,set,delete -PermissionsToCertificates create,list,update,delete

$storage_accts = Get-AzStorageAccount | sort-object -Property ResourceGroupName

## This code logic could also be moved to the New-EDOFUser script with a -Interactive switch...
# choose Subscription to Manage
$targetSubscriptionctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select the Subscription to be managed by Azure DevOps Framework."
$targetSubscription=$targetSubscriptionctx[-1].Subscription

$tfStorageAccount = Get-UserInputList $storage_accts "Choose the Terraform State file Storage Account for $($targetSubscription.name)"
if (-not $tfStorageAccount) { write-error "No Storage Accounts found." -ErrorAction Stop }

$userName = Get-UserInputWithConfirmation "Enter the first username to configure with deployment rights to $($targetSubscription.name)"

$targetSubscriptionId = $targetSubscription.SubscriptionId
$TFStorageAccountName = $tfStorageAccount[-1].StorageAccountName

$EDOFargs= @{
    Username = $userName
    Ring0KeyVaultName = $ring0KeyVaultName
    Ring1KeyVaultName = $Ring1KeyVaultName
    targetSubscriptionId = $targetSubscriptionId
    TFStorageAccountName = $TFStorageAccountName
}
Set-AzContext -Context $ring0ctx[-1]
& (join-path $scriptPath "New-EDOFUser.ps1") @EDOFargs
