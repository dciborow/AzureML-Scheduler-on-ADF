<#
 .SYNOPSIS
    Deploys a batch pool to Azure with a Windows DSVM node

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER Title
    The title of the deployment

 .PARAMETER ResourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

  .PARAMETER StorageAccountName
    The batch account name

 .PARAMETER Location
    Data Factory Region

#>
param(
 [Parameter(Mandatory=$True)]
 [string]
 $title,

 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 [Parameter(Mandatory=$True)]
 [string]
 $storageAccountName,

 [Parameter(Mandatory=$True)]
 [string]
 $location
)


$storageAccountName = "{0}blob" -f $title
Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -ev notPresent -ea 0
if ($notPresent)
{
    Write-Host "Creating storage account'$storageAccountName' in group '$resourceGroupName'";
    New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName -Type "Standard_LRS" -Location $location
}
else{
    Write-Host "Using existing batch pool '$poolName'";
}