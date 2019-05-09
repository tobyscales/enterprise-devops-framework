$ErrorActionPreference = 'Stop'

#region Functions
Function Get-TFData {
    param( [string]$filePath, [string]$masterKey )

    $masterKey = $masterKey.ToLower()

    $rawFiledata = (Get-Content -path $filePath -Raw).ToLower() # | Where-Object { ( (-not ($_.StartsWith('#'))) ) }
    $endbracket = $rawFiledata.indexOf('}', $rawFiledata.IndexOf($masterKey)) - $rawFiledata.IndexOf($masterKey) + 1
    $bracketed_string = (Get-Content -path $filePath -Raw).substring($rawFiledata.indexOf($masterKey), $endbracket) #re-use original because lowercase!
    return ($bracketed_string.substring($bracketed_string.indexOf('{') + 1)).Trim('{', '}') | ConvertFrom-StringData
}
function Get-OAuth2Uri
(
    [string]$vaultName
) {
    $response = try { Invoke-WebRequest -Method GET -Uri "https://$vaultName.vault.azure.net/keys" -Headers @{ } 
    }
    catch {
        $headers = $_.Exception.Response.Headers
        $headers | ForEach-Object { if ($_ -match "WWW-Authenticate") { $authHeader = $_.Value } }
    }

    $endpoint = [regex]::match($authHeader, 'authorization="(.*?)"').Groups[1].Value

    return "$endpoint/oauth2/token"
}
#from https://github.com/Azure/azure-powershell/issues/2494
function Get-CachedToken($tenantId) {
    #$cache = [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared
    $cache = (Get-AzContext).TokenCache
    $cacheItem = $cache.ReadItems() | Where-Object { $_.TenantId -eq $tenantId } | Select-Object -First 1
    write-host $cacheItem
    return $cacheItem.AccessToken
}
# Invoke-Rest KV calls cribbed from https://blogs.msdn.microsoft.com/cclayton/2017/01/02/using-key-vault-secrets-in-powershell/
function Get-Keys
(
    [string]$accessToken,
    [string]$vaultName
) {
    $headers = @{ 'Authorization' = "Bearer $accessToken" }
    $queryUrl = "https://$vaultName.vault.azure.net/keys" + '?api-version=2016-10-01'
    write-host $queryUrl
    $Response = Invoke-RestMethod -Method GET -Uri $queryUrl -Headers $headers

    return $Response.value
}
function Get-Secrets
(
    [string]$accessToken,
    [string]$vaultName
) {
    $headers = @{ 'Authorization' = "Bearer $accessToken" }
    $queryUrl = "https://$vaultName.vault.azure.net/secrets" + '?api-version=7.0'

    $Response = Invoke-RestMethod -Method GET -Uri $queryUrl -Headers $headers

    return $Response.value
}
function Get-KVSecret
(
    [string]$accessToken,
    [string]$url
) {
    $headers = @{ 'Authorization' = "Bearer $accessToken" }
    
    $url = $url + '?api-version=7.0'

    $Response = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

    return $Response.value
}
#from https://github.com/tyconsulting/AzureServicePrincipalAccount-PS
function Get-OauthTokenFromCertificate
(
    [string]$clientId,
    [string]$certPath,
    [securestring]$certPass,
    [string]$audience,
    [string]$oAuthURI
) {

    $marshal = [System.Runtime.InteropServices.Marshal]
    $ptr = $marshal::SecureStringToBSTR($certPass)
    $CertFilePlainPassword = $marshal::PtrToStringBSTR($ptr)
    $marshal::ZeroFreeBSTR($ptr)
    $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::New($certPath, $CertFilePlainPassword)

    $ClientCert = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientAssertionCertificate]::new($clientId, $Cert)
    $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($oAuthURI)
    $Token = ($authContext.AcquireTokenAsync($audience, $ClientCert)).Result.AccessToken

    return $token
}

#from http://danstis.azurewebsites.net/authenticate-to-azure-active-directory-using-powershell/
function Get-OauthTokenFromSecret {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)][string]$ClientID,
        [Parameter(Mandatory = $true)][string]$ClientSecret,
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $false)][string]$ResourceName = "https://graph.windows.net",
        [Parameter(Mandatory = $false)][switch]$ChinaAuth
    )

    #This script will require the Web Application and permissions configured in Azure Active Directory.
    if ($ChinaAuth) {
        $LoginURL = 'https://login.chinacloudapi.cn'
    }
    else {
        $LoginURL = 'https://login.microsoftonline.com'
    }
    #Get an Oauth 2 access token based on client id, secret and tenant id
    $Body = @{grant_type = "client_credentials"; resource = $ResourceName; client_id = $ClientID; client_secret = $ClientSecret }
    $response = Invoke-RestMethod -Method Post -Uri $LoginURL/$TenantId/oauth2/token -Body $Body
    return $response.access_Token
}
#endregion

write-host "Checking Prerequisites..."
#TODO: check for AzureAD module dependencies

#TODO: add error-checking for $configPath
$startPath = $pwd.path
$configPath = "$($startPath.Substring(0, $startPath.indexof("live")))config"
$subId = [regex]::Match($startPath, 's[0-9a-fA-F]{5}') #regex match the subscription ID in the path

if (-not $subId.Success) { write-error "Could not find subscription reference in path." } else {
    $subId = $subId.Value
    write-host "Initializing subscription $subId..." -ForegroundColor green

    $username = ((Get-Content -path "$configPath\globals.tfvars").ToLower() | Where-Object { ( (($_.StartsWith('user'))) ) }).split('=')[1].trim('"', ' ')
    $certPath = "$configPath\certs\$subId.$username.pfx" 

    #TODO: Cleanup cert pass
    $certpass = ConvertTo-SecureString "hi" -AsPlainText -Force
    
    $kvResourceGroups = Get-TFData "$configPath\secrets.tfvars" "keyvault_rgs" 
    $kvVaults = Get-TFData "$configPath\secrets.tfvars" "keyvaults" 
    $clientIds = Get-TFData "$configPath\secrets.tfvars" "clientids"
    $tenantIds = Get-TFData "$configPath\secrets.tfvars" "tenantids"
    #$clientSecrets = Get-TFData "$configPath\secrets.tfvars" "clientsecrets"
    $backends = Get-TFData "$configPath\secrets.tfvars" "backends"

    foreach ($rg in $kvResourceGroups.KEYS.GetEnumerator()) {
        if ($rg -eq $subId) {
            write-host "Using config at " -NoNewline
            write-host -ForegroundColor green "$configPath\secrets.tfvars"
            $thisConfig = [PSCustomObject]@{
                subId        = $subId.Value
                clientId     = $clientIds.$rg.trim('"')
                #clientSecret = $clientSecrets.$rg.trim('"')
                tenantId     = $tenantIds.$rg.trim('"')
                vault        = $kvVaults.$rg.trim('"')
                vaultrg      = $kvResourceGroups.$rg.trim('"')
                storageacct  = $backends."$rg-storageacct".trim('"')
                storagekey   = $backends."$rg-storagekey".trim('"')
                username     = $username.trim('"')
            }
        }
    }
    
    if (-not $thisConfig) { Write-Host -ForegroundColor red "Unable to find keyvault configuration in secrets.tfvars.`n Check $configPath and try again." }

    $oauthUri = Get-Oauth2Uri $thisConfig.vault
    $Token = Get-OauthTokenFromCertificate -clientId $thisConfig.clientId -certPath $certPath -certPass $certpass -audience "https://vault.azure.net" -oAuthURI $oauthUri
    
    #TODO: add option to use client secrets instead
    #$thetoken = Get-OauthTokenFromSecret -ClientID $thisConfig.clientId -ClientSecret $thisConfig.clientSecret -TenantId $thisConfig.tenantId -ResourceName "https://vault.azure.net" 
 
    $thisConfig.storageacct = get-KVsecret $Token -url "$($thisConfig.storageacct)"
    $thisConfig.storagekey = get-KVsecret $Token -url "$($thisConfig.storagekey)"

    switch ((Split-Path $startPath -Leaf) -match 's[0-9a-fA-F]{5}') {
        $true {
            #subscription level
            get-childitem -directory $startpath | foreach-object { set-location $_.Name; Set-Content "backend.tfvars" -value "storage_account_name=`"$($thisConfig.storageacct)`"`ncontainer_name=`"$($thisrg)`"`naccess_key=`"$($thisConfig.storagekey)`"`nkey=`"$($thisConfig.username).terraform.tfstate`""; set-location $startPath }
        }
        $false {
            #rg level
            Set-Content "$startPath/backend.tfvars" -value "storage_account_name=`"$($thisConfig.storageacct)`"`ncontainer_name=`"$($thisrg)`"`naccess_key=`"$($thisConfig.storagekey)`"`nkey=`"$($thisConfig.username).terraform.tfstate`""
        }
    }
}