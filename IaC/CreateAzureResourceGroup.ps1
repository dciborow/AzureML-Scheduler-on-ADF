<#
 .SYNOPSIS
    Deploys a resource group in Azure

 .DESCRIPTION
    Deploys an Azure Resource Group

 .PARAMETER ResourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER Location
    Data Factory Region

#>
param(

 [Parameter(Mandatory=$True)]
 [string]
 $resourceGroupName,

 [Parameter(Mandatory=$True)]
 [string]
 $location
)

Get-AzureRmResourceGroup -Name $resourceGroupName -ev notPresent -ea 0
if ($notPresent)
{
    Write-Host "Creating resource group '$resourceGroupName'";
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $location
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}