$ErrorActionPreference='Continue'
#iterate through all subscriptions tagged
for ($i = 0; $i -lt $env:subCount; $i++) {
    $subName = Invoke-Expression ('$env:subName' + $i)
    $env:path += ";$($env:AGENT_WORKFOLDER)"

    set-location "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)"

    get-childitem -Directory -exclude "*.terraform" | ForEach-Object { 
        Set-Location $_.FullName

        if (Test-Path "cicd.plan") {
            write-host "***********************************" >> "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)/out.txt" 
            write-host "$_" >> "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)/out.txt" 
            write-host "***********************************" >> "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)/out.txt" 
            & terraform show cicd.plan >> "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)/out.txt" 
            write-host "         ----                            " >> "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)/out.txt" 
        }
    }

    write-host "##############"
    write-host "##############"
    get-content("$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)/out.txt") | write-host
    write-host "##############"
    write-host "##############"
}