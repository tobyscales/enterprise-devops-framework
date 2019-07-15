#region functions
Function Get-UserInputWithConfirmation($message) {
    $useThis = "N"
    $userinput = ""
    while ("Y" -inotmatch $useThis) {
        clear-host
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

$rootPath = (get-item $PSScriptRoot).Parent.FullName
$bootstrapPath = (join-path $rootPath "bootstrap")
$configPath    = (join-path $rootPath "config")
$certPath      = (join-path $rootPath "certs")
$livePath      = (join-path $rootPath "live")
$scriptPath    = (join-path $rootPath "scripts")

new-item -ItemType Directory -Path $configPath -force | Out-Null
new-item -ItemType Directory -Path $certPath -force | Out-Null
new-item -ItemType Directory -Path $livePath -force | Out-Null

#deploy Ring0 resources
$ring0ctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select your Ring 0 Subscription"
Set-AzContext -Context $ring0ctx[-1]

$ring0loc = Get-UserInputList (Get-AzLocation) -message "Select an Azure Region to deploy Ring0 Resources"
$ring0rg = Get-UserInputWithConfirmation -message "Enter a name for your Ring 0 resource group"
New-AzResourceGroup -Name $ring0rg[-1] -Location $($ring0loc[-1].Location)
New-AzResourceGroupDeployment -TemplateFile (join-path $bootstrapPath ring0.json) -TemplateParameterFile (join-path $bootstrapPath ring0.parameters.json) -ResourceGroupName $ring0rg[-1] #-AsJob

#deploy Ring1 resources
$ring1ctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select your Ring 1 Subscription"

$ring1Subscription = $ring1ctx[-1].Subscription 
if (-not $ring1Subscription) { write-error "No Subscriptions found." -ErrorAction Stop }
write-host -ForegroundColor yellow "Connecting to subscription $($ring1Subscription.name)..."
Set-AzContext -Context $ring1ctx[-1]

$storage_accts = Get-AzStorageAccount | sort-object -Property ResourceGroupName

$ring1loc = Get-UserInputList (Get-AzLocation) -message "Select an Azure Region to deploy Ring1 Resources"
$ring1rg = Get-UserInputWithConfirmation -message "Enter a name for your Ring 1 resource group"
New-AzResourceGroup -Name $ring1rg[-1] -Location $($ring1loc[-1].Location)
New-AzResourceGroupDeployment -TemplateFile (join-path $bootstrapPath ring1.json) -TemplateParameterFile (join-path $bootstrapPath ring1.parameters.json) -ResourceGroupName $ring1rg[-1] #-AsJob

$ring0json = Get-content -raw (join-path $bootstrapPath ring0.parameters.json) | ConvertFrom-Json
$ring1json = Get-content -raw (join-path $bootstrapPath ring1.parameters.json) | ConvertFrom-Json

$ring0KeyVaultName = $ring0json.parameters.keyVaultName.value
$ring1KeyVaultName = $ring1json.parameters.keyVaultName.value

Set-AzKeyVaultAccessPolicy -VaultName $ring0KeyVaultName -UserPrincipalName $ring0ctx[-1].Account.Id -PermissionsToSecrets get,list,set,delete -PermissionsToKeys get,list,update,create,import,delete -PermissionsToCertificates get,list,update,create,import,delete

#TODO: add ability to select multiple subscriptions at once?
#TODO: add subscription creation option?
#TODO: use pure Terraform for cert creation?

$tfStorageAccount = Get-UserInputList $storage_accts "Choose the Terraform State file Storage Account for $($ring1Subscription.name)"
if (-not $tfStorageAccount) { write-error "No Storage Accounts found." -ErrorAction Stop }

$userName = Get-UserInputWithConfirmation "Enter the username to configure for $($ring1Subscription.name)"

$targetSubscriptionId = $ring1Subscription.SubscriptionId
$TFStorageAccountName = $tfStorageAccount[-1].StorageAccountName

$EDOFargs= @{
    Username = $userName[-1]
    Ring0KeyVaultName = $ring0KeyVaultName
    Ring1KeyVaultName = $Ring1KeyVaultName
    targetSubscriptionId = $targetSubscriptionId
    TFStorageAccountName = $TFStorageAccountName
}

& (join-path $scriptPath "New-EDOFUser.ps1") @EDOFargs
