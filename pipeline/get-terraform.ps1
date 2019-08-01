$tf_path="$($env:AGENT_WORKFOLDER)"
$tf_version="$($env:TF_VERSION)"
#$tf_path="$($env:SYSTEM_DEFAULTWORKINGDIRECTORY)"
$download_location="$tf_path\terraform.zip"

Write-Host "Downloading version $tf_version of terraform"

# Build download URL
    $url = "https://releases.hashicorp.com/terraform/$tf_version/terraform_$($tf_version)_windows_amd64.zip"

# Output folder (in location provided)
    write-host "Saving $url to $download_location"

# Set TLS to 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Download terraform
    Invoke-WebRequest -Uri $url -OutFile $download_location  

    # Unzip terraform and replace existing terraform file
    Write-Host "Installing latest terraform"
    Expand-Archive -Path $download_location -DestinationPath $tf_path -Force

    # Remove zip file
    #Write-Host "Remove zip file"
    #Remove-Item $download_location -Force

