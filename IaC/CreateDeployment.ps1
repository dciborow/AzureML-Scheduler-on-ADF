<#
 .SYNOPSIS
    Deploys a batch pool to Azure with a Windows DSVM node

 .DESCRIPTION
    Deploys an Azure Resource Manager template

  .PARAMETER prefix

  .PARAMETER unique

  .PARAMETER Location

  .PARAMETER sourceBlobPath

  .PARAMETER sinkBlobPath

  .PARAMETER gitUser

  .PARAMETER gitPassword  

  .PARAMETER gitProject  

  .PARAMETER projectDir

  .PARAMETER batchUser

  .PARAMETER password

  .PARAMETER dsvm

  .PARAMETER pythonPath
#>
param(
 [Parameter()]
 [string]
  $prefix = "amladf",

  [Parameter()]
  [string]
  $unique = (Get-Random -minimum 1 -maximum 999999),

  [Parameter()]
  [string]
  $Location = "East US",

  [Parameter()]
  [string]
  $sourceBlobPath = "/",

  [Parameter()]
  [string]
  $sinkBlobPath = "/",
 
  [Parameter()]
  [string]
  $gitUser = (git config user.email).split("@")[0],

  [Parameter(Mandatory=$True)]
  [string]
  $gitPassword,

  [Parameter()]
  [string]
  $vstsServer = (git config remote.origin.url).split("//.")[2],

  [Parameter()]
  [string]
  $vstsAccount=(git config remote.origin.url).split("//.")[6],

  [Parameter()]
  [string]
  $projectDir=(git config remote.origin.url).split("//.")[8],

  [Parameter(Mandatory=$True)]
  [string]
  $password,

  [Parameter(Mandatory=$True)]
  [string]
  $dsvm,

  [Parameter(Mandatory=$True)]
  [string]
  $pythonPath 
)
$title = ("{0}{1}" -f $prefix, $unique)

$poolName = "{0}pool" -f $title
$jobid = "adfv2-$poolName"
$batchUser = "rdpuser"
$accountName = "{0}batch" -f $title
$dataFactoryName = "{0}df" -f $title
$pipelineName = "MLPipeline"
$resourceGroupName = "{0}rg" -f $title
$gitProject = ("https://{0}:{1}@{2}.visualstudio.com/DefaultCollection/{3}/_git/{4}" -f $gitUser, $gitPassword, $vstsServer, $vstsAccount, $projectDir)
$storageAccountName = "{0}blob" -f $title
$tenantId = (Get-AzureRmContext).Subscription.TenantId
<# Create Service Princpal
Here we create an Azure Service Princpal so that we can log in remotely to our Azure Subscription from within our custom activity. 
The solution is currently configured for password based authentication. 
#>
#region
#Login-AzureRmAccount
$sp = Get-AzureRmADServicePrincipal -SearchString $title"sp"
if(!$sp){
    $securepassword = convertto-securestring $password -asplaintext -force
    $sp = New-AzureRmADServicePrincipal -DisplayName $title"sp" -Password $securepassword 
    Sleep 20
}
$servicePrincipal = $sp.ApplicationId
#New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $sp.ApplicationId

#region
#With Self Signed Cert instead of password
#Login-AzureRmAccount
#$cert = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "CN=exampleappScriptCert" -KeySpec KeyExchange
#$keyValue = [System.Convert]::ToBase64String($cert.GetRawCertData())

#$sp = New-AzureRMADServicePrincipal -DisplayName exampleapp -CertValue $keyValue -EndDate $cert.NotAfter -StartDate $cert.NotBefore
#Sleep 20
#New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $sp.ApplicationId
#endregion
#endregion


.\IaC\CreateAzureResourceGroup.ps1 `
    -resourceGroupName $resourceGroupName `
    -location $Location

.\IaC\CreateAzureStorageBlob.ps1 `
    -title $title `
    -resourceGroupName $resourceGroupName `
    -storageAccountName $storageAccountName `
    -location $Location 

.\IaC\CreateAzureBatch.ps1 `
    –AccountName $accountName `
    –Location $Location `
    –ResourceGroupName $resourceGroupName `
    -batchUser $batchUser `
    -password $password `
    -poolName $poolName

#region Create Azure DSVM
#.\IaC\CreateAzureDSVM.ps1 
#-resourceGroupName $resourceGroupName 
#-deploymentName "dsvmTestdcib"
#TODO Clean this up
#endregion

.\Iac\CreateAzureDataFactoryV2.ps1 `
    -prefix $prefix `
    -unique $unique `
    -sourceBlobPath $sourceBlobPath `
    -sinkBlobPath $sinkBlobPath `
    -dataFactoryName $dataFactoryName `
    -pipelineName $pipelineName `
    -gitUser $gitUser `
    -gitPassword $gitPassword `
    -gitProject $gitProject `
    -projectDir $projectDir `
    -accountName $accountName `
    -poolName $poolName `
    -jobid $jobid `
    -batchUser $batchUser `
    -tenantId $tenantId `
    -servicePrincipal $servicePrincipal `
    -password $password `
    -dsvm $dsvm `
    -pythonPath $pythonPath `
    -storageAccountName $storageAccountName
