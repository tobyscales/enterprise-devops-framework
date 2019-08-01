
Function Get-TFData {
    param( [string]$filePath, [string]$masterKey, [switch]$asObject = $false )

    $rawFiledata = (Get-Content -path $filePath -Raw) 
    $tfblock = ($rawFiledata | select-string -Pattern "(?smi)$masterkey.+?{.+?[}]" | foreach-object { $_.matches.value })

    if ($asObject) {
        #trim the brackets off our Terraform block
        $tfblock = $tfblock -replace "(?m)$masterkey.+?{", ""
        $tfblock = $tfblock -replace "}$", ""

        return $tfblock | ConvertFrom-StringData
    }
    else {
        return $tfblock
    }
}

#TODO: add error-checking for $configPath

$startPath = $pwd.path
$rootPath = (get-item $PSScriptRoot).Parent.FullName
$bootstrapPath = (join-path $rootPath "bootstrap")
$configPath    = (join-path $rootPath "config")
$certPath      = (join-path $configPath "certs")
$livePath      = (join-path $rootPath "live")
$scriptPath    = (join-path $rootPath "scripts")

$globalsFile = join-path $configPath "globals.tfvars"
$providerFile = join-path $configPath "provider.tf"
$secretsFile = join-path $configPath "secrets.tfvars"

$subId = [regex]::Match($startPath, 's[0-9a-fA-F]{5}') #regex match the subscription ID in the path
if (-not $subId.Success) { write-error "Could not find subscription reference in path."; throw } 

if (
    (test-path "$globalsFile") -and
    (test-path "$providerFile") 
) { 

    $username = ((Get-Content -path "$globalsFile").ToLower() | Where-Object { ( (($_.StartsWith('user'))) ) }).split('=')[1].trim('"', ' ')

    #checks whether we're in a root subscription_dir or a leaf resourcegroup_dir
    switch ((Split-Path $startPath -Leaf) -match 's[0-9a-fA-F]{5}') {
        $true {
            #subscription level
            get-childitem -directory $startpath | foreach-object { set-location $_.Name; & (join-path $scriptpath get-config.ps1); set-location $startPath }
        }
        $false {
            #rg level
            $subId = $subId.Value
            $thisrg = (Split-Path $startPath -Leaf)

            write-host "Configuring $thisrg..."
            copy-item "$configPath/globals.tfvars" "$startPath/secrets.auto.tfvars" -Force
            #copy-item "$configPath/secrets.tfvars" "$startPath/secrets.auto.tfvars" -Force
            copy-item "$configPath/provider.tf" "$startPath/provider.tf" -Force
            copy-item "$certPath/$subId.$username.pfx" "$startPath/$subId.$username.pfx" -Force

            ## SUPER IMPORTANT NOTE: /config/secrets.tfvars should never be checked into your code repo!
            $thisconfig = (Get-TFData "$configPath/secrets.tfvars" -masterKey $subId) -replace "(?smi)$subid.+?{", "this-config = {"
            Add-Content "$startPath/secrets.auto.tfvars" `n$thisconfig`n -force
            Add-Content "$startPath/secrets.auto.tfvars" "`nthis-directory=`"$thisrg`"`n" -Force
            #Add-content "$startPath/secrets.auto.tfvars" "`nthis-subalias=`"$subid`"`n" -Force
        }
    }
}
else {
    # end test-path if
    write-host -ForegroundColor DarkRed "`n `nError loading configuration for Get-Config, either could not find subscription reference in path or check: `n$globalsFile, `n$providerFile and `n$configPath\certs\$subId.$username.pfx"
    throw 
}
