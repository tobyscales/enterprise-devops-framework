
$url = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$env:SYSTEM_TEAMPROJECT/_apis/git/repositories/$env:BUILD_REPOSITORY_ID/commits/$env:BUILD_SOURCEVERSION/changes?api-version=5.0"

$currentCommits = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $env:THE_TOKEN" };
$subs = @();
$i = 0;
if (-not $currentCommits.changes) {  write-host "no commits found" } else {
    $currentCommits.changes | ForEach-Object {
        #write-host "Found commit: $_.item.commitId at path $_.item.path"

        if ([regex]::Match($_.item.path, 's[0-9a-fA-F]{5}')) {
            $dirSubscriptionName = [regex]::Match($_.item.path, 's[0-9a-fA-F]{5}*')
            #$dirSubscriptionName = $_.item.path.trimstart("/live/") -split "/" -match "subsc"
            $env = $($dirSubscriptionName -split "_")[-1]
            
            $dirSubscriptionName = $dirSubscriptionName.trimEnd("$env") 
            $dirSubscriptionName = $dirSubscriptionName.trimEnd("_")   #necessary cause otherwise the _ is interpreted as an escape character?
            
            if (-not $subs.contains($dirSubscriptionName)) {
                $subs += $dirSubscriptionName 
                write-host "Found $env deployment for... $dirSubscriptionName"
                Write-Host "##vso[task.setvariable variable=dirSubscriptionName$i;isOutput=true]$dirSubscriptionName"  
                $i++
            }
        }
    }
}

if (-not $subs ) { Write-Host "##vso[task.setvariable variable=foundSubs]false" } else { Write-Host "##vso[task.setvariable variable=foundSubs]true"}
#get-variable("subName$i") #could use this to force a failure in the agent
# write-error "No subscriptions found." } 

