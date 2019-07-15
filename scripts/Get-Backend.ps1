$ErrorActionPreference = 'Stop'

#region Functions
Function Get-TFData {
    param( [string]$filePath, [string]$masterKey, [switch]$asObject = $false )

    $rawFiledata = (Get-Content -path $filePath -Raw) 
    $tfblock = ($rawFiledata | select-string -Pattern "(?smi)$masterkey.+?{.+?[}]" | foreach-object { $_.matches.value })

    if ($asObject) {
        #trim the brackets off our Terraform block
        $tfblock = $tfblock -replace "(?m)$masterkey.+?{", ""
        $tfblock = $tfblock -replace "}$", ""
        $tfblock = $tfblock -replace '"', ""

        return $tfblock | ConvertFrom-StringData
    }
    else {
        return $tfblock
    }
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
    [string]$certFile,
    [securestring]$certPass,
    [string]$audience,
    [string]$oAuthURI
) {

    $marshal = [System.Runtime.InteropServices.Marshal]
    $ptr = $marshal::SecureStringToBSTR($certPass)
    $CertFilePlainPassword = $marshal::PtrToStringBSTR($ptr)
    $marshal::ZeroFreeBSTR($ptr)
    $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::New($certFile, $CertFilePlainPassword)

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
#TODO: remove AzureAD module dependencies??!?
import-module az.accounts

#TODO: add error-checking for $configPath
#TOFIX: pull entire config from subscription alias
$startPath = $pwd.path
try {
$rootPath = "$($startPath.Substring(0, $startPath.indexof("live")))" } catch { write-host -ForegroundColor yellow "Could not find \live folder. Check your path."; throw }

$configPath = join-path $rootPath "config"
$certPath   = join-path $configPath "certs"
$scriptPath = join-path $rootPath "scripts"

$backendFile = join-path $startPath "backend.tfvars"
$globalsFile = join-path $configPath "globals.tfvars"
$secretsFile = join-path $configPath "secrets.tfvars"

$subId = [regex]::Match($startPath, 's[0-9a-fA-F]{5}') #regex match the subscription ID in the path
if (-not $subId.Success) { write-host -ForegroundColor yellow "Could not find subscription reference in path."; throw } 

$subId = $subId.Value
write-host "Initializing subscription $subId..." -ForegroundColor green

if (
    (test-path "$globalsFile") -and
    (test-path "$secretsFile") 
) { 
       
    $username = ((Get-Content -path "$globalsFile").ToLower() | Where-Object { ( (($_.StartsWith('user'))) ) }).split('=')[1].trim('"', ' ')
    $certFile = (join-path $certPath "$subId.$username.pfx")
  
    if (-not (test-path $certFile)) { throw }

    $certPass = Read-Host -Prompt "Please enter a password for the certificate." -AsSecureString
    #$certpass = ConvertTo-SecureString "" -AsPlainText -Force

    $thisConfig = Get-TFData -filePath $secretsFile -masterKey $subId -asObject
    
    if (-not $thisConfig) { Write-Host -ForegroundColor red "Get-Backend.ps1: Unable to find keyvault configuration in secrets.tfvars.`n Check $configPath and try again." }

    $oauthUri = Get-Oauth2Uri $thisConfig.keyvault

    $Token = Get-OauthTokenFromCertificate -clientId $thisConfig.client_id -certFile $certFile -certPass $certpass -audience "https://vault.azure.net" -oAuthURI $oauthUri    
    #TODO: add option to use client secrets instead
    #$thetoken = Get-OauthTokenFromSecret -ClientID $thisConfig.clientId -ClientSecret $thisConfig.clientSecret -TenantId $thisConfig.tenantId -ResourceName "https://vault.azure.net" 
 
    $thisConfig.storageacct = get-KVsecret $Token -url "$($thisConfig.storageacct)"
    $thisConfig.storagekey = get-KVsecret $Token -url "$($thisConfig.storagekey)"

    switch ((Split-Path $startPath -Leaf) -match 's[0-9a-fA-F]{5}') {
        $true {
            #subscription level
            get-childitem -directory $startpath | foreach-object { set-location $_.Name; $thisrg=(split-path $pwd.path -leaf); Set-Content "backend.tfvars" -value "storage_account_name=`"$($thisConfig.storageacct)`"`ncontainer_name=`"$thisrg`"`naccess_key=`"$($thisConfig.storagekey)`"`nkey=`"$username.terraform.tfstate`""; set-location $startPath }
        }
        $false {
            #rg level
            $thisrg = (Split-Path $startPath -Leaf)
            Set-Content $backendFile -value "storage_account_name=`"$($thisConfig.storageacct)`"`ncontainer_name=`"$thisrg`"`naccess_key=`"$($thisConfig.storagekey)`"`nkey=`"$username.terraform.tfstate`""
        }
    }
}
else {
    # end test-path if
    write-host -ForegroundColor DarkRed "`n `nError loading configuration for Get-Backend.ps1, check: `n$globalsFile and `n$secretsFile." 
    throw 
}
