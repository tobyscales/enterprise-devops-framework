#TODO: add error-checking for $configPath
$startPath = $pwd.path
$configPath = "$($startPath.Substring(0, $startPath.indexof("live")))config"
$subId= [regex]::Match($startPath,'s[0-9a-fA-F]{5}') #regex match the subscription ID in the path

if (-not $subId.Success) { write-error "Could not find subscription reference in path." } else {
    #checks whether we're in a root subscription_dir or a leaf resourcegroup_dir
    switch ((Split-Path $startPath -Leaf) -match 's[0-9a-fA-F]{5}') {
        $true {
            #subscription level
            get-childitem -directory $startpath | foreach-object { set-location $_.Name; & "$configPath\tools\get-config.ps1"; set-location $startPath  }
        }
        $false {
            #rg level
            $subId=$subId.Value
            $thisrg = (Split-Path $startPath -Leaf)

            write-host "Configuring $thisrg..."
            copy-item "$configPath/globals.tfvars" "$startPath/globals.auto.tfvars" -Force
            copy-item "$configPath/secrets.tfvars" "$startPath/secrets.auto.tfvars" -Force
            copy-item "$configPath/provider.tf" "$startPath/provider.tf" -Force
            copy-item "$configPath/certs/$subId.pfx" "$startPath/$subId.pfx" -Force

            Add-content "$startPath/secrets.auto.tfvars" "`nthis-directory=`"$thisrg`"`n" -Force
            Add-content "$startPath/secrets.auto.tfvars" "`nthis-subalias=`"$subid`"`n" -Force
        }
    }
}