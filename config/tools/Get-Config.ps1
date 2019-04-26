
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

write-host "Deploying to $thisrg..."

if (-not $subId -match 's\d\d\d\d\d') { Write-Error "Unable to find subscriptionID. Check your path." }

Add-content "$startPath/secrets.auto.tfvars" "`nthis-directory=`"$thisrg`"`n" -Force
Add-content "$startPath/secrets.auto.tfvars" "`nthis-subalias=`"$subid`"`n" -Force