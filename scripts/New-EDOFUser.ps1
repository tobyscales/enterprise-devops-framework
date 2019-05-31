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
    Creates a deployment user and assigns permissions to Ring1 resources as part of the Enterprise DevOps Framework for Azure.

.DESCRIPTION

.PARAMETER AdditionalExtensions

.PARAMETER LaunchWhenDone

.EXAMPLE

.EXAMPLE

#>
Function Set-TFData {
    param( [string]$filePath, [string]$masterKey, 
        [parameter(ValueFromPipeline = $true)]
        [string]$stringToAdd )

    (Get-Content -path $filepath) -replace "$masterkey.*$", "$&`n  $stringToAdd" | set-content $filepath -force
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
Function New-EDOFUser {
    #TODO: make "interactive" a switch param
    param (
        [Parameter(
            Position = 0)]
        [string[]]$targetSubscriptionId,

        [Parameter]            
        [string[]]$UserName,

        [Parameter]
        [string[]]$Ring0KeyVaultName,

        [Parameter]
        [string[]]$TFStorageAccountName,

        [Parameter]
        [string[]]$SubscriptionId,

        [Parameter]
        [switch[]]$Interactive = $false
    )
    Begin {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted 

        write-host "Checking Prerequisites..."
        if (-not (get-module Az.Accounts)) { if (-not $Dbug) { Install-Module -Name Az.Accounts -AllowClobber -Scope CurrentUser } }
        if (-not (get-module Az.Keyvault)) { if (-not $Dbug) { Install-Module -Name Az.Keyvault -AllowClobber -Scope CurrentUser } }
        if (-not (get-module Az.Storage)) { if (-not $Dbug) { Install-Module -Name Az.Storage -AllowClobber -Scope CurrentUser } }

        import-module az.accounts
        import-module az.keyvault
        import-module az.storage

        $startPath = $pwd.path
        $configPath = "$($startPath.Substring(0, $startPath.indexof("live")))config"
        #$subId = [regex]::Match($startPath, 's[0-9a-fA-F]{5}') #regex match the subscription ID in the path

        $secrets = @()
        
        if (-not $dbug) {
            try { 
                get-azsubscription | Out-Null
            }
            catch {
                Connect-AzAccount
            }
        }

        switch ($Interactive) {
            $true {
                #TODO: add ability to select multiple subscriptions at once?
                #TODO: add subscription creation option?
                #TODO: use pure Terraform for cert creation?
                $subs = Get-AzSubscription
                $vaults = Get-AzKeyVault
                $storage_accts = Get-AzStorageAccount

                $ring0Subscription = Get-UserInputList $subs "Choose the Ring 0 Subscription"
                if (-not $ring0Subscription) { write-error "No Subscriptions found." -ErrorAction Stop }
                write-host -ForegroundColor yellow "Connecting to subscription $($ring0Subscription.name)..."

                set-azcontext -SubscriptionObject $ring0Subscription > $null

                $ring0KeyVault = Get-UserInputList $vaults "Choose the Ring 0 Key Vault"
                if (-not $ring0KeyVault) { write-error "No Keyvaults found." -ErrorAction Stop }
            }
            $false { }
        }
    }

    Process {
        switch ($Interactive) {
            $true {
                #TODO: add ability to select multiple subscriptions at once?
                #TODO: add subscription creation option?
                #TODO: use pure Terraform for cert creation?

                $targetSubscription = Get-UserInputList $subs "Choose the Target Subscription"
                if (-not $targetSubscription) { write-error "No Subscriptions found." -ErrorAction Stop }
                write-host -ForegroundColor yellow "Connecting to subscription $($targetSubscription.name)..."

                $ring1KeyVault = Get-UserInputList $vaults "Choose the Ring 1 Key Vault for $($targetSubscription.name)"
                if (-not $ring1KeyVault) { write-error "No Keyvaults found." -ErrorAction Stop }

                $tfStorageAccount = Get-UserInputList $storage_accts "Choose the Terraform State file Storage Account for $($targetSubscription.name)"
                if (-not $tfStorageAccount) { write-error "No Storage Accounts found." -ErrorAction Stop }

                [string]$targetSubscriptionId = $targetSubscription.SubscriptionId
                [string]$targetTenantId = $targetSubscription.TenantId
                [string]$Ring1KeyVaultName = $ring1KeyVault.VaultName
                [string]$TFStorageAccountName = $tfStorageAccount.StorageAccountName

                $userName = Get-UserInputWithConfirmation "Enter the username to configure for $($targetSubscription.name)"
            }
            $false { $targetTenantId = (Get-AzSubscription -SubscriptionId $targetSubscriptionId).TenantId; $tfStorageAccount = (Get-AzStorageAccount | Where-Object -Property { $_.StorageAccountName -eq $TFStorageAccount }); }
        }  

        $cert = $null
        $subalias = "s" + $targetSubscriptionId.Substring(0, 5)
        $certificateName = "deployer.$subalias.$username".trim()

        $certPath = (join-path $configPath "certs")
        $pfxPath = (join-path $certPath "$subalias.$username.pfx")

        new-item -ItemType Directory -Path $certPath -force | Out-Null

        #TODO: add error-checking
        write-host "Generating certificate..."
        $policy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=$certificateName" -IssuerName Self -ValidityInMonths 12

        Add-AzKeyVaultCertificate -VaultName $Ring0KeyVaultName -Name $certificateName.replace(".", "-") -CertificatePolicy $policy | Out-Null
        do {
            $cert = Get-AzKeyVaultCertificate -VaultName $Ring0KeyVaultName -Name $certificateName.replace(".", "-")
            Start-sleep -seconds 1
        } until ($cert.Certificate)

        $now = [System.DateTime]::Now
        $certb64 = [System.Convert]::ToBase64String($cert.Certificate.RawData)

        #TODO: add error-checking/catching code
        $mySP = Get-AzADServicePrincipal -DisplayName "deployer.$subalias.$username" 

        if (-not $mySP) {
            #TODO: add SP to Management Group option instead of direct assignment
            $mySP = New-AzADServicePrincipal -DisplayName "deployer.$subalias.$username" -ErrorAction Stop 
        }
    
        write-host "Appending certificate for authentication..."
        New-AzADSpCredential -ServicePrincipalObject $mySP -CertValue $certb64 -StartDate $now -EndDate $cert.Expires | Out-Null

        #from https://stackoverflow.com/questions/43837362/keyvault-generated-certificate-with-exportable-private-key and
        #https://blogs.technet.microsoft.com/kv/2016/09/26/get-started-with-azure-key-vault-certificates/ and
        #https://blogs.technet.microsoft.com/neales/2017/06/26/getting-a-private-certificate-from-key-vault/

        write-host "Saving authentication certificate to $pfxPath..."

        #create Temporary Random Password for certificate
        $PasswordLength = 10
        $ascii = 33..126 | % { [char][byte]$_ }
        $certpass = $(0..$passwordLength | % { $ascii | get-random }) -join ""

        $pfxSecret = Get-AzKeyVaultSecret -VaultName $Ring0KeyVaultName -Name $certificateName.replace(".", "-") -Version $cert.Version
        $pfxUnprotectedBytes = [Convert]::FromBase64String($pfxSecret.SecretValueText)
        $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $certCollection.Import($pfxUnprotectedBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
        $pfxProtectedBytes = $certCollection.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $certpass)
        [System.IO.File]::WriteAllBytes($pfxPath, $pfxProtectedBytes)

        write-host "User deployer.$subalias.$username successfully created, credentials stored in $($ring0KeyVaultName)."

        write-host "Assigning to target subscription" #TODO: add RoleDefinition param
        New-AzRoleAssignment -ApplicationId $mySP.applicationId -RoleDefinitionName Contributor -scope "/subscriptions/$targetSubscriptionId" | Out-Null

        $key1 = (Get-AzStorageAccountKey -ResourceGroupName $tfStorageAccount.ResourceGroupName -Name $tfStorageAccount.StorageAccountName).Value[0]

        #add error-checking to ensure secrets are actually stored
        write-host "Storing Ring 1 secrets in $Ring1KeyVaultName..."
        $saURL = (Set-AzKeyVaultSecret -VaultName $Ring1KeyVaultName -name "$subalias-storageacct" -SecretValue (convertto-securestring $TFStorageAccount.StorageAccountName -AsPlainText -Force)).Id
        $skURL = (Set-AzKeyVaultSecret -VaultName $Ring1KeyVaultName -name "$subalias-storagekey" -SecretValue (convertto-securestring $key1 -AsPlainText -Force)).Id
        
        Set-AzKeyVaultAccessPolicy -VaultName $Ring1KeyVaultName -ObjectId $mySP.Id -PermissionsToSecrets get   
        
        write-host "Successfully configured deployer.$subalias.$username to deploy to $($targetSubscription.Name) and store Terraform state in $($TFStorageAccount.StorageAccountName)."
        write-host -ForegroundColor Green "Password for $subalias.$username.pfx is: $certpass. Please store securely!!"
        $secrets += [ordered]@{
            'subalias'        = $subalias
            'client_id'       = "$($mySP.ApplicationId)"
            'keyvault'        = $Ring1KeyVaultName
            'keyvault_rg'     = "$($ring1KeyVault.ResourceGroupName)"
            'subscription_id' = $targetSubscriptionId
            'tenant_id'       = $targetTenantId
            'storageacct'     = "$saURL"
            'storagekey'      = "$skURL"
        }
    }
    
    End {
        $secretsFile = (join-path $configPath "secrets.tfvars")

        foreach ($secret in $secrets) {
            add-content $secretsFile "`n$($secret.subalias) = {" -force
            $columnWidth = $secret.Keys.length | Sort-Object | Select-Object -Last 1
            $secret.GetEnumerator() | ForEach-Object { "{0,-$columnWidth}=`"{1}`"" -F $_.Key, $_.Value | out-file $secretsFile -Append -Force }
            add-content $secretsFile "}"
        }
    }
 
}