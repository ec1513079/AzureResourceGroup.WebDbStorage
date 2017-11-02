<#
 .NOTES
    Example 1: Deployment Azure Resource Group

    First, login to AzureRmAccount.
    Second, get azure subscriptionid for deployment.
    Finally, RUN!

      Login-AzureRmAccount;
      $AzureSubId = (Get-AzureRmSubscription -SubscriptionName kotakahashi@tech.softbank.co.jp).SubscriptionId ; $AzureSubId;
      .\Deploy-AzureResourceGroup.ps1 `
        -ResourceGroupLocation japaneast `
        -ResourceGroupName TemplateDeploy `
        -SubscriptionId $AzureSubId;


#>

#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] [Parameter(Mandatory = $true)] $ResourceGroupLocation,
    [string] [Parameter(Mandatory = $true)] $ResourceGroupName,
    [string] $DeploymentName = 'WDSDeploy',
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'params\azuredeploy.parameters.minimum.json',
    [string] $SubscriptionId,
    [switch] $CompleteDeploy = $false,

    # ^^^^^^^^^^^^^^^^ Following valuable is't using in this script ^^^^^^^^^^^^^^^^ 
    [switch] $ValidateOnly,
    [string] $StorageContainerName = $ResourceGroupName.ToLowerInvariant() + '-stageartifacts',
    [string] $StorageAccountName,
    [switch] $UploadArtifacts,
    [string] $ArtifactStagingDirectory = '.',
    [string] $DSCSourceFolder = 'DSC'
    # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

# Set AzureRMContext for resource group deployment
Write-Output '', 'Deployment Azure Context'
if ([string]::IsNullOrEmpty($SubscriptionId)) {
    Get-AzureRmContext
}
else {
    Select-AzureRmSubscription -SubscriptionID $SubscriptionId
}

# Set Template path
$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force

# Deploy Mode
$mode = 'Incremental'
if ($CompleteDeploy) { $mode = 'Complete' }


####################################################################################################
## Azure Resource Manager Template Deploy
####################################################################################################
$Result = New-AzureRmResourceGroupDeployment -Name $DeploymentName `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile $TemplateFile `
                                       -TemplateParameterFile $TemplateParametersFile `
                                       -Mode $mode `
                                       @OptionalParameters `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages
if ($ErrorMessages) {
    Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    throw $ErrorMessages
}

Write-Output '', 'Template Deploy Result'
Write-Output $Result.OutputsString

