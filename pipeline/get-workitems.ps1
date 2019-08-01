$url = "$env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI$env:SYSTEM_TEAMPROJECT/_apis/build/builds/$env:BUILD_BUILDID/workitems?api-version=4.1"
Write-Host "URL: $url";
$workitems = Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $env:THE_TOKEN" };
$subs = @();
$tags = @();
$workItemJson = @();
write-host "******************";
if (-not $workitems.value.url) {  write-host "no subs found" } else {
    $workitems.value.url | foreach-object {
        $url = $_
        write-host "Found WorkItem: $url"
        $workItemJson += convertFrom-Json (Invoke-RestMethod -Uri $url -Headers @{ Authorization = "Bearer $env:THE_TOKEN" } | ConvertTo-Json -Depth 100);
    }
    $workitemjson | foreach-object {
        if ($_.PSobject.Properties -match "System.Tags") { 
            $tags += ($_.fields."System.Tags" -split ";").trim()
        } 
    }
    $i = 0;
    foreach ($tag in $tags) {    
        if ( ($tag.startswith("subsc_")) -and (-not $subs.contains($tag) )) {  
            $subs += $tag
            write-host "Found deployment for... $tag"
            Write-Host "##vso[task.setvariable variable=subName$i]$tag"  
            $i++
        }
    }

    $count = $($subs.count) #the vso[task] syntax prefers this format 
    Write-Host "Total subscriptions targeted: $count"
    Write-Host "##vso[task.setvariable variable=subCount]$count"
}
