#region Define Functions
Function Get-TFData {
    param( [string]$filePath, [string]$masterKey )

    $masterKey = $masterKey.ToLower()

    $rawFiledata = (Get-Content -path $filePath -Raw).ToLower() # | Where-Object { ( (-not ($_.StartsWith('#'))) ) }
    $endbracket = $rawFiledata.indexOf('}', $rawFiledata.IndexOf($masterKey)) - $rawFiledata.IndexOf($masterKey) + 1
    $bracketed_string = $rawFiledata.substring($rawFiledata.indexOf($masterKey), $endbracket)
    return ($bracketed_string.substring($bracketed_string.indexOf('{') + 1)).Trim('{', '}') | ConvertFrom-StringData
}

#endregion 

write-host "Checking Prerequisites..."
if (-not (get-module Az.Keyvault)) { Install-Module -Name Az.Keyvault -AllowClobber -Scope CurrentUser -repository PSGallery }

$startPath = $pwd.path
$configPath = "$($startPath.Substring(0, $startPath.indexof("live")))config"

#TODO: allow for subscription-level "terragrunt apply-all" style deployments
#checks whether we're in a root subscription_dir or a leaf resourcegroup_dir
switch ((Split-Path $startPath -Leaf) -match '\d\d\d\d\d') {
    "$true" {
        #subscription level
        $subId = (Split-Path $startPath -Leaf).Substring(0, 5)
        write-host "Apply-all is not supported at this time."
        break
    }
    "$false" {
        #rg level
        $subId = "s" + (Split-Path (Split-Path $startPath) -Leaf).Substring(0, 5)
        $thisrg = (Split-Path $startPath -Leaf)
    }
}

write-host "Initializing in $thisrg..." -ForegroundColor green

if (-not $subId -match 's\d\d\d\d\d') { Write-Error "Unable to find subscriptionID. Check your path."; break }

$username = ((Get-Content -path "$configPath\globals.tfvars").ToLower() | Where-Object { ( (($_.StartsWith('user'))) ) }).split('=')[1].trim('"', ' ')

#$certPath = "$configPath\certs\$subId.pfx" 
#$cert = Get-PfxCertificate $certPath -Password $certpass

$kvResourceGroups = Get-TFData "$configPath\secrets.tfvars" "keyvault_rgs" 
$kvVaults = Get-TFData "$configPath\secrets.tfvars" "keyvaults" 
#$clientIds = Get-TFData "$configPath\secrets.tfvars" "clientids"
#$tenantIds = Get-TFData "$configPath\secrets.tfvars" "tenantids"
#$backends = Get-TFData "$configPath\secrets.tfvars" "backends"
 

foreach ($rg in $kvResourceGroups.KEYS.GetEnumerator()) {
    if ($rg -eq $subId) {
        write-host "Using config at " -NoNewline
        write-host -ForegroundColor green "$configPath\secrets.tfvars"
        $thisConfig = [PSCustomObject]@{
            subId       = $subId
            #clientId    = $clientIds.$rg.trim('"')
            #tenantId    = $tenantIds.$rg.trim('"')
            vault       = $kvVaults.$rg.trim('"')
            vaultrg     = $kvResourceGroups.$rg.trim('"')
            storageacct = ""
            storagekey  = ""
            #storageacct = $backends."$rg-storageacct".trim('"')
            #storagekey  = $backends."$rg-storagekey".trim('"')
            username    = $username.trim('"')
        }
    }
}
#$thisconfig | fl
if (-not $thisConfig) { Write-Host -ForegroundColor red "Unable to find keyvault configuration in secrets.tfvars.`n Check $configPath and try again." }

#TODO:
#remove dependency on Az.accounts, just use raw invoke-rest
#remove dependency on Az.Keyvault

#$certThumbPrint = (Get-PfxCertificate -FilePath $certPath -Password $certPass ).ThumbPrint

#Connect-AzAccount -CertificateThumbprint $cert.Thumbprint -ApplicationId $thisConfig.clientId -tenant $thisConfig.tenantId -ServicePrincipal *>$null
#get-azk
$thisConfig.storagekey = (Get-AzKeyVaultSecret -VaultName "$($thisConfig.vault)" -name "$($thisconfig.subid)-storagekey").SecretValueText
$thisConfig.storageacct = (Get-AzKeyVaultSecret -VaultName "$($thisConfig.vault)" -name "$($thisconfig.subid)-storageacct").SecretValueText

#(Get-Content "$configPath/backend.cicd") | Set-content "$startPath/backend.tf" -force
#(Get-Content "$startPath/backend.tf").replace("__storageacct__", "$($thisConfig.storageacct)") | Set-Content "$startPath/backend.tf" -force
#(Get-Content "$startPath/backend.tf").replace("__storagekey__", "$($thisConfig.storagekey)") | Set-Content "$startPath/backend.tf" -force
#(Get-Content "$startPath/backend.tf").replace("__resourcegroup__", "$thisrg") | Set-Content "$startPath/backend.tf" -force
#(Get-Content "$startPath/backend.tf").replace("__username__", "$($thisConfig.username)") | Set-Content "$startPath/backend.tf" -force
Set-Content "$startPath/backend.tfvars" -value "storage_account_name=`"$($thisConfig.storageacct)`"`ncontainer_name=`"$($thisrg)`"`naccess_key=`"$($thisConfig.storagekey)`"`nkey=`"$($thisConfig.username).terraform.tfstate`""

#Add-content "$startPath/secrets.auto.tfvars" "`nthis-directory=`"$thisrg`"`n" -Force
#Add-content "$startPath/secrets.auto.tfvars" "`nthis-subalias=`"$subid`"`n" -Force