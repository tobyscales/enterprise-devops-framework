<#PSScriptInfo
.VERSION .1
.AUTHOR Toby Scales
.COMPANYNAME Microsoft Corporation
.ICONURI
.EXTERNALMODULEDEPENDENCIES
    Requires PowerShellCore. If not found, will install the following modules into the User Scope:
    - Az.Accounts
    - Az.Storage
    - Az.KeyVault
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES

    Initial release.

#>
<#

.SYNOPSIS
    Creates a deployment user and assigns permissions to manage target resources as part of the Enterprise DevOps Framework for Azure.

.DESCRIPTION
    Requires PSCore. By default, will install required dependencies to the User Scope. Use -SkipPrereqs to skip.
    Service Principal will be created with the prefix deployer* for easy integration into other user management processes.

.PARAMETER UserName
    MANDATORY - The username of the person who will have a deployer* Service Principal assigned for their deployments. 
    This information will be stored in the Key Vault auditing logs so be sure to use clearly named users!

.PARAMETER Ring0KeyVaultName
    MANDATORY - The name of Ring 0 Key Vault, which will be used to generate and store authentication certificates for the deployer* Service Principals.

.PARAMETER Ring1KeyVaultName
    OPTIONAL - The name of the Ring 1 Key Vault. If not specified, the Ring 0 Key Vault will be used.

.PARAMETER TargetSubscriptionId
    MANDATORY - The SubscriptionId that the deployer* Service Principal will be used to manage.

.PARAMETER TFStorageAccountName
    MANDATORY - Name of the storage account to store the terraform.tfstate files. I may take this option away in v2 to make it simpler.

.PARAMETER SkipPrereqs
    OPTIONAL - Save time when running the script multiple times! Add the -SkipPrereqs switch today.

.EXAMPLE

.EXAMPLE

#>
Function Set-TFData {
    param( [string]$filePath, [string]$masterKey, 
        [parameter(ValueFromPipeline = $true)]
        [string]$stringToAdd )

    (Get-Content -path $filepath) -replace "$masterkey.*$", "$&`n  $stringToAdd" | set-content $filepath -force
}
Function New-EDOFUser {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [string]$Ring0KeyVaultName,
        [string]$Ring1KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]$TargetSubscriptionId,
        [Parameter(Mandatory = $true)]
        [string]$TFStorageAccountName,
        [switch]$SkipPrereqs
    )
    Begin {

        if (-not $SkipPrereqs) {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted 

            write-host "Checking Prerequisites..."
            if (-not (get-module Az.Accounts)) { Install-Module -Name Az.Accounts -AllowClobber -Scope CurrentUser } 
            if (-not (get-module Az.Keyvault)) { Install-Module -Name Az.Keyvault -AllowClobber -Scope CurrentUser } 
            if (-not (get-module Az.Storage)) { Install-Module -Name Az.Storage -AllowClobber -Scope CurrentUser } 

            import-module az.accounts
            import-module az.keyvault
            import-module az.storage
        }

        $rootPath   = (get-item $PSScriptRoot).Parent.FullName
        $livePath   = (join-path $rootPath "live")
        $configPath = (join-path $rootPath "config")
        $certPath   = (join-path $configPath "certs")

        new-item -ItemType Directory -Path $configPath -force | Out-Null
        new-item -ItemType Directory -Path $certPath -force | Out-Null
        new-item -ItemType Directory -Path $livePath -force | Out-Null

        $secrets = @()

        try { 
            get-azsubscription | Out-Null
        }
        catch {
            Connect-AzAccount
        }
                
    }

    Process {
        
        $cert = $null
        $subalias = "s" + $TargetSubscriptionId.Substring(0, 5)
        $certificateName = "deployer.$subalias.$username".trim()

        $pfxPath = (join-path $certPath "$subalias.$username.pfx")

        # set defaults
        if (-not $Ring1KeyVaultName) { $Ring1KeyVaultName = $Ring0KeyVaultName }

        try {
            $targetTenantId = (Get-AzSubscription -SubscriptionId $TargetSubscriptionId -ErrorAction Stop).TenantId 
            $tfStorageAccount = (Get-AzStorageAccount | Where-Object -Property StorageAccountName -eq $TFStorageAccountName ) 
        }
        catch {
            write-error "Unable to get Subscription $TargetSubscriptionId or Storage Account $tfStorageAccount."
            break
        }

        # do Ring0 stuff
        write-host "Generating certificate..."
        $policy = New-AzKeyVaultCertificatePolicy -SubjectName "CN=$certificateName" -IssuerName Self -ValidityInMonths 12

        try {
            Add-AzKeyVaultCertificate -VaultName $Ring0KeyVaultName -Name $certificateName.replace(".", "-") -CertificatePolicy $policy | Out-Null
        }
        catch {
            write-error "Unable to generate Key Vault Certificate - do you have permissions to the Ring0 Key Vault?"
            exit
        }

        do {
            write-host -nonewline ..
            $cert = Get-AzKeyVaultCertificate -VaultName $Ring0KeyVaultName -Name $certificateName.replace(".", "-")
            Start-sleep -seconds 1
        } until ($cert.Certificate)

        $now = [System.DateTime]::Now
        $certb64 = [System.Convert]::ToBase64String($cert.Certificate.RawData)

        write-host "Finding Service Principal"

        do {
            write-host -nonewline ..

            #TODO: add error-checking/catching code
            $mySP = Get-AzADServicePrincipal -DisplayName "deployer.$subalias.$username" 

            if (-not $mySP) {
                #TODO: add SP to Management Group option instead of direct assignment
                write-host "Creating Service Principal in $((get-azcontext).Tenant)"
                $mySP = New-AzADServicePrincipal -DisplayName "deployer.$subalias.$username" -ErrorAction Stop 
            }

            Start-sleep -seconds 1

        } until ($mySP.Id)

        write-host "Appending certificate for authentication..."
        New-AzADSpCredential -ServicePrincipalObject $mySP -CertValue $certb64 -StartDate $now -EndDate $cert.Expires | Out-Null

        Set-AzKeyVaultAccessPolicy -VaultName $Ring0KeyVaultName -ObjectId $mySP.Id -PermissionsToCertificates update
        Set-AzKeyVaultAccessPolicy -VaultName $Ring1KeyVaultName -ObjectId $mySP.Id -PermissionsToSecrets get

        #from https://stackoverflow.com/questions/43837362/keyvault-generated-certificate-with-exportable-private-key and
        #https://blogs.technet.microsoft.com/kv/2016/09/26/get-started-with-azure-key-vault-certificates/ and
        #https://blogs.technet.microsoft.com/neales/2017/06/26/getting-a-private-certificate-from-key-vault/

        write-host "Saving authentication certificate to $pfxPath..."

        #create Temporary Random Password for certificate
        $PasswordLength = 10
        $ascii = 33..126 | ForEach-Object { [char][byte]$_ }
        $certpass = $(0..$passwordLength | ForEach-Object { $ascii | get-random }) -join ""

        $pfxSecret = Get-AzKeyVaultSecret -VaultName $Ring0KeyVaultName -Name $certificateName.replace(".", "-") -Version $cert.Version
        $pfxUnprotectedBytes = [Convert]::FromBase64String($pfxSecret.SecretValueText)
        $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $certCollection.Import($pfxUnprotectedBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
        $pfxProtectedBytes = $certCollection.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $certpass)
        [System.IO.File]::WriteAllBytes($pfxPath, $pfxProtectedBytes)

        write-host "User deployer.$subalias.$username successfully created, credentials stored in $($ring0KeyVaultName)."

        # switch context to Ring1
        $targetSubscription = Get-AzSubscription -SubscriptionId $TargetSubscriptionId
        Select-AzSubscription -Subscription $TargetSubscriptionId

        #TODO: add error-checking to ensure we get the storage acct key
        $key1 = (Get-AzStorageAccountKey -ResourceGroupName $tfStorageAccount.ResourceGroupName -Name $tfStorageAccount.StorageAccountName).Value[0]

        #TODO: add error-checking to ensure secrets are actually stored
        write-host "Storing Ring 1 secrets in $Ring1KeyVaultName..."
        $saURL = (Set-AzKeyVaultSecret -VaultName $Ring1KeyVaultName -name "$subalias-storageacct" -SecretValue (convertto-securestring $TFStorageAccount.StorageAccountName -AsPlainText -Force)).Id
        $skURL = (Set-AzKeyVaultSecret -VaultName $Ring1KeyVaultName -name "$subalias-storagekey" -SecretValue (convertto-securestring $key1 -AsPlainText -Force)).Id
        
        write-host "Assigning to target subscription" #TODO: add RoleDefinition param

        ## TODO: perform pre-flight check to make sure the SP exists... hopefully enough time has passed by now!
        New-AzRoleAssignment -ApplicationId $mySP.applicationId -RoleDefinitionName Contributor -scope "/subscriptions/$TargetSubscriptionId" | Out-Null

        $secrets += [ordered]@{
            'subalias'        = $subalias
            'client_id'       = "$($mySP.ApplicationId)"
            'keyvault'        = $Ring1KeyVaultName
            'keyvault_rg'     = (Get-AzKeyVault -VaultName $Ring1KeyVaultName).ResourceGroupName
            'subscription_id' = $TargetSubscriptionId
            'tenant_id'       = $targetTenantId
            'storageacct'     = "$saURL"
            'storagekey'      = "$skURL"
        }

        $subscriptionDirectoryName = ("$subalias $($targetSubscription.Name)") -replace " ", "_"
        new-item -type Directory -path $livePath -Name $subscriptionDirectoryName #| Out-Null

        #TODO: Add file output option for bulk-adding users
        write-host "Successfully configured deployer.$subalias.$username to deploy to $($targetSubscription.Name) and store Terraform state in $($TFStorageAccount.StorageAccountName)."
        write-host -ForegroundColor Green "Password for $subalias.$username.pfx is: $certpass `nPlease store securely!!"
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
New-EDOFUser @args