<#
 .SYNOPSIS
    Deploys a batch pool to Azure with a Windows DSVM node

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER ResourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

  .PARAMETER accountName
    The batch account name

 .PARAMETER Location
    Data Factory Region

 .PARAMETER batchUser
    User Account for connecting to batch nodes

 .PARAMETER password
    Password for connectiong to batch nodes


#>
param(
 [Parameter(Mandatory=$True)]
 [string]
 $ResourceGroupName,

 [Parameter(Mandatory=$True)]
 [string]
 $accountName,

 [Parameter(Mandatory=$True)]
 [string]
 $Location,

 [Parameter(Mandatory=$True)]
 [string]
 $batchUser,

 [Parameter(Mandatory=$True)]
 [string]
 $password,

 [Parameter(Mandatory=$True)]
 [string]
 $poolName
)

$batch = Get-AzureRmBatchAccount –AccountName $accountName –ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
if(!$batch){
    Write-Host "Creating batch account '$accountName' in location '$Location'";
    New-AzureRmBatchAccount –AccountName $accountName –Location $Location –ResourceGroupName $ResourceGroupName
}
else{
    Write-Host "Using existing batch account'$accountName'";
}

$context = Get-AzureRmBatchAccountKeys –ResourceGroupName $ResourceGroupName -AccountName $accountName 

$pool = Get-AzureBatchPool -BatchContext $context -Id $poolName -ErrorAction SilentlyContinue
if(!$pool){
    Write-Host "Creating batch pool '$poolName' in account '$accountName'";
    $startUpTask = New-Object Microsoft.Azure.Commands.Batch.Models.PSStartTask
    $batchJobResources=  New-Object System.Collections.Generic.List[Microsoft.Azure.Commands.Batch.Models.PSResourceFile]   
    $batchJobMarlingProgramResource = New-Object Microsoft.Azure.Commands.Batch.Models.PSResourceFile `
                                             -ArgumentList @("https://aka.ms/azureml-wb-msi","AmlWorkbenchSetup.msi")

    $batchJobResources.Add($batchJobMarlingProgramResource)
    $startUpTask.ResourceFiles = $batchJobResources
    $startUpTask.WaitForSuccess = $true
    $startUpTask.CommandLine ="cmd /c msiexec -i AmlWorkbenchSetup.msi  /qn && D:\Users\$batchUser\AppData\Local\AmlInstaller\Installer.Windows.exe --silent" #/silent /quiet
    $startUpTask.UserIdentity = "$batchUser"
 
    $userAccount = New-Object Microsoft.Azure.Commands.Batch.Models.PSUserAccount -ArgumentList @($batchUser, $password, "admin")

    $Offer="standard-data-science-vm"
    $Publisher="microsoft-ads"
    $Sku="standard-data-science-vm"
    $image = New-Object Microsoft.Azure.Commands.Batch.Models.PSImageReference -ArgumentList @($Offer,$Publisher,$Sku,"latest")
    $vm = New-Object Microsoft.Azure.Commands.Batch.Models.PSVirtualMachineConfiguration -ArgumentList @($image,"batch.node.windows amd64")

    New-AzureBatchPool -BatchContext $context -Id $poolName -VirtualMachineSize "Standard_A1" -MaxTasksPerComputeNode 4 -StartTask $startUpTask -TargetDedicatedComputeNodes 1 -UserAccount $userAccount -VirtualMachineConfiguration $vm
}
else{
    Write-Host "Using existing batch pool '$poolName'";
}
