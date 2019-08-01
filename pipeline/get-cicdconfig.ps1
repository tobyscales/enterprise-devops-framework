#update tokens in global.tfvars, copy to live directory
set-location $($env:Build_ArtifactStagingDirectory)
(Get-Content config/globals.cicd).replace('__EnvironmentName__', "$($env:EnvironmentName)") | Set-Content config/globals.tfvars -force

#iterate through all subscriptions tagged and update tokens in terraform.tfvars
for ($i = 0; $i -lt $env:subCount; $i++) {
    $subName = Invoke-Expression ('$env:dirSubscriptionName' + $i) #gets the current subscription name from pipeline
    $subalias = [regex]::Match($subName, 's[0-9a-fA-F]{5}')       #gets subscription id for replacing vars

    write-host "Deploying $subName using alias $subalias..."    
    
    #use Invoke-Expression plus {} syntax to properly pull the environment variable for $subalias-subid, etc

    $keyvaulturl = Invoke-Expression ('${env:' + "$subalias-keyvaulturl}")

    $secrets += [ordered]@{
        'subalias'        = $subalias
        'tenant_id'       = Invoke-Expression ('${env:' + "$subalias-tenantid}")
        'client_id'       = Invoke-Expression ('${env:' + "$subalias-clientid}")
        'client_secret'   = Invoke-Expression ('${env:' + "$subalias-clientsecret}")
        'subscription_id' = Invoke-Expression ('${env:' + "$subalias-subid}")

        'storageacct'     = Invoke-Expression ('${env:' + "$subalias-storageacct}")
        'storagekey'      = Invoke-Expression ('${env:' + "$subalias-accesskey}")

        #'keyvault'        = $Ring1KeyVaultName
        #'keyvault_rg'     = "$($ring1KeyVault.ResourceGroupName)"
    }

   <# $thisConfig = [PSCustomObject]@{
        subId        = Invoke-Expression ('${env:' + "$subalias-subid}")
        tenantId     = Invoke-Expression ('${env:' + "$subalias-tenantid}")
        clientId     = Invoke-Expression ('${env:' + "$subalias-clientid}")
        clientSecret = Invoke-Expression ('${env:' + "$subalias-clientsecret}")
        storageacct  = Invoke-Expression ('${env:' + "$subalias-storageacct}")
        accesskey    = Invoke-Expression ('${env:' + "$subalias-accesskey}")
    } #>



}

$secretsFile = config/secrets.tfvars

foreach ($secret in $secrets) {
    add-content $secretsFile "`n$($secret.subalias) = {" -force
    $columnWidth = $secret.Keys.length | Sort-Object | Select-Object -Last 1
    $secret.GetEnumerator() | ForEach-Object { "{0,-$columnWidth}=`"{1}`"" -F $_.Key, $_.Value | out-file $secretsFile -Append -Force }
    add-content $secretsFile "}"
}   