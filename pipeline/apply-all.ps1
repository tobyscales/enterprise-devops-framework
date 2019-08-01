#iterate through all subscriptions changed
$ErrorActionPreference='Continue'
for ($i = 0; $i -lt $env:subCount; $i++) {
    $subName = Invoke-Expression ('$env:subName' + $i)
    $env:path += ";$($env:AGENT_WORKFOLDER)"

    set-location "$($env:Build_ArtifactStagingDirectory)/live/$($subName)_$($env:EnvironmentName)"
    Get-ChildItem

    & "../../scripts/tfm.cmd" apply
}