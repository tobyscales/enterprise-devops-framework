#region functions
Function Get-UserInputWithConfirmation($message) {
    $useThis = "N"
    while ("Y" -inotmatch $useThis) {
        clear-host
        $input = Read-Host $message
        $useThis = Read-Host "$input, is that correct?"
        switch ($useThis) {
            "Y" { }
            "N" { }
            default { $useThis = Read-Host "Please enter Y or N" }
        }
    }
    return $input
}
Function Get-UserInputList { 
    param (
        [Parameter(Mandatory,
            Position = 0)]
        [System.Object[]]$objects, 

        [Parameter(Mandatory,
            Position = 1)]
        [string[]]$message)

    #write-host $message
    if ($objects.count -lt 1) { Write-Error "None found." -ErrorAction Stop; return $false }
    #write-host $PSBoundParameters.Values
    #Format-Table $objects -AutoSize

    do {
        clear-host
        $i = 1
        $objects | ForEach-Object { $_ | Add-Member -NotePropertyName Choice -NotePropertyValue $i -Force -PassThru; $i++ } | select Choice, *Name | Out-Host
        $i = read-host -prompt $message
        $selected_object = $objects[$i - 1]

    } until ($selected_object)
    return $selected_object
}
#endregion functions

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted 

write-host "Checking Prerequisites..."
if (-not (get-module Az.Accounts)) { Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser }

$startPath = get-item $pwd.Path
$configPath = (join-path $startPath.Parent "config")
$scriptPath = (join-path $startPath.Parent "scripts")
$bootstrapPath = (join-path $startPath.Parent "bootstrap")

#deploy Ring0 resources
$ring0ctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select your Ring 0 Subscription"
Set-AzContext $ring0ctx
$ring0loc = Get-UserInputList (Get-AzLocation) -message "Select an Azure Region to deploy Ring0 Resources"
$ring0rg = Get-UserInputWithConfirmation -message "Enter a name for your Ring 0 resource group"
New-AzResourceGroup -Name $ring0rg -Location $ring0loc.Location
New-AzResourceGroupDeployment -TemplateFile (join-path $bootstrapPath ring0.json) -TemplateParameterFile (join-path $bootstrapPath ring0.parameters.json) -ResourceGroupName $ring0rg -AsJob

#deploy Ring1 resources
$ring1ctx = Get-UserInputList (Get-AzContext -ListAvailable) -message "Select your Ring 0 Subscription"
Set-AzContext $ring1ctx
$ring1loc = Get-UserInputList (Get-AzLocation) -message "Select an Azure Region to deploy Ring1 Resources"
$ring1rg = Get-UserInputWithConfirmation -message "Enter a name for your Ring 1 resource group"
New-AzResourceGroup -Name $ring1rg -Location $ring1loc.Location
New-AzResourceGroupDeployment -TemplateFile (join-path $bootstrapPath ring1.json) -TemplateParameterFile (join-path $bootstrapPath ring1.parameters.json) -ResourceGroupName $ring1rg -AsJob

Set-location $scriptPath
& New-EDOFUser.ps1 -interactive

Set-location $startPath
