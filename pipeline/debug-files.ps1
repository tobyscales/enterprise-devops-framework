Set-Location $($env:Build_ArtifactStagingDirectory)
tree /F | Select-object -skip 2 #skips the first two lines of output

write-host "#################################################################################################"
write-host "#################################################################################################"
write-host "#################################################################################################"

#iterate through all subscriptions tagged
for ($i = 0; $i -lt $env:subCount; $i++) {
    $subName = Invoke-Expression ('$env:subName' + $i)

    get-content "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)/terraform.tfvars" | write-host
    write-host "*************************************************************************************************"
    get-content "$($env:Build_ArtifactStagingDirectory)/live/global.tfvars" | write-host

    Set-Location "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)"

    #write-host "***********************************"
    #get-content .\provider.tf | write-host
    #write-host "***********************************"

    get-childitem -Directory -exclude "*.terraform" | ForEach-Object {
        Set-Location $_.FullName
        write-host "***********************************"
        write-host "***********************************"
        write-host "directory: $_"
        write-host "***********************************"
        get-content .\required.tf | write-host
        write-host "-----------"
        get-content .\terraform.tfvars | write-host
        write-host "-----------"
    }
}