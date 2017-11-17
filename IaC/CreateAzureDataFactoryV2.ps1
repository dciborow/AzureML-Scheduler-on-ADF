<#
 .SYNOPSIS
    Deploys a batch pool to Azure with a Windows DSVM node

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .PARAMETER prefix

  .PARAMETER unique

  .PARAMETER sourceBlobPath

  .PARAMETER sinkBlobPath

  .PARAMETER dataFactoryName

  .PARAMETER pipelineName

  .PARAMETER gitUser

  .PARAMETER gitPassword  

  .PARAMETER gitProject  

  .PARAMETER projectDir

  .PARAMETER accountName

  .PARAMETER poolName

  .PARAMETER jobid

  .PARAMETER batchUser

  .PARAMETER tenantId

  .PARAMETER servicePrincipal

  .PARAMETER password

  .PARAMETER dsvm

  .PARAMETER pythonPath

  .PARAMETER storageAccountName

#>
param(
 [Parameter(Mandatory=$True)]
 [string]
  $prefix,

  [Parameter(Mandatory=$True)]
  [string]
  $unique,

  [Parameter(Mandatory=$True)]
  [string]
  $sourceBlobPath,

  [Parameter(Mandatory=$True)]
  [string]
  $sinkBlobPath,

  [Parameter(Mandatory=$True)]
  [string]
  $dataFactoryName,

  [Parameter(Mandatory=$True)]
  [string]
  $pipelineName,

  [Parameter(Mandatory=$True)]
  [string]
  $gitUser,

  [Parameter(Mandatory=$True)]
  [string]
  $gitPassword,

  [Parameter(Mandatory=$True)]
  [string]
  $gitProject,

  [Parameter(Mandatory=$True)]
  [string]
  $projectDir,

  [Parameter(Mandatory=$True)]
  [string]
  $accountName,

  [Parameter(Mandatory=$True)]
  [string]
  $poolName,

  [Parameter(Mandatory=$True)]
  [string]
  $jobid,

  [Parameter(Mandatory=$True)]
  [string]
  $batchUser,

  [Parameter(Mandatory=$True)]
  [string]
  $tenantId,

  [Parameter(Mandatory=$True)]
  [string]
  $servicePrincipal,

  [Parameter(Mandatory=$True)]
  [string]
  $password,

  [Parameter(Mandatory=$True)]
  [string]
  $dsvm,

  [Parameter(Mandatory=$True)]
  [string]
  $pythonPath,
  
  [Parameter(Mandatory=$True)]
  [string]
  $storageAccountName 
)
$title = "$prefix$unique"
$dataFactoryRegion = "East US"
#region Helper Functions
function createResources{
param ($dataFactoryName , $dataFactoryRegion, $resourceGroupName)
# Create a data factory

$df = Get-AzureRmDataFactoryV2 -ResourceGroupName $resourceGroupName -Name $dataFactoryName -ErrorAction SilentlyContinue
if(!$df){
    Write-Host "Creating data factory '$dataFactoryName' in location '$dataFactoryRegion'";
    $df = Set-AzureRmDataFactoryV2 -ResourceGroupName $resourceGroupName -Location $dataFactoryRegion -Name $dataFactoryName 
}
else{
    Write-Host "Using existing data factory '$dataFactoryName'";
}
}
function addAzureStorage{
param ($dataFactoryName , $resourceGroupName, $storageAccountName)
$storageKey = Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName
#region JSON definition of the linked service. 
$storageLinkedServiceDefinition = @"
{
    "name": "AzureStorageLinkedService",
    "properties": {
        "type": "AzureStorage",
        "typeProperties": {
            "connectionString": {
                "value": "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$storageKey[0].Value",
                "type": "SecureString"
            }
        }
    }
}
"@
## IMPORTANT: stores the JSON definition in a file that will be used by the Set-AzureRmDataFactoryV2LinkedService command. 
$storageLinkedServiceDefinition | Out-File c:\StorageLinkedService.json
#endregion
## Creates a linked service in the data factory
Set-AzureRmDataFactoryV2LinkedService -DataFactoryName $dataFactoryName -ResourceGroupName $resourceGroupName -Name "AzureStorageLinkedService" -File c:\StorageLinkedService.json
}
function addBlobStorage{
param ($dataFactoryName , $resourceGroupName)
# Create an Azure Blob dataset in the data factory

## JSON definition of the dataset
$datasetDefiniton = @"
{
    "name": "BlobDataset",
    "properties": {
        "type": "AzureBlob",
        "typeProperties": {
            "folderPath": {
                "value": "@{dataset().path}",
                "type": "Expression"
            }
        },
        "linkedServiceName": {
            "referenceName": "AzureStorageLinkedService",
            "type": "LinkedServiceReference"
        },
        "parameters": {
            "path": {
                "type": "String"
            }
        }
    }
}
"@

## IMPORTANT: store the JSON definition in a file that will be used by the Set-AzureRmDataFactoryV2Dataset command. 
$datasetDefiniton | Out-File c:\BlobDataset.json

## Create a dataset in the data factory
Set-AzureRmDataFactoryV2Dataset -DataFactoryName $dataFactoryName -ResourceGroupName $resourceGroupName -Name "BlobDataset" -File "c:\BlobDataset.json"
}
function addBatchLinkedService{
param ($dataFactoryName , $resourceGroupName, $accountName, $poolName)
$context = Get-AzureRmBatchAccountKeys –ResourceGroupName $ResourceGroupName -AccountName $accountName 
$batchUri = "https://{0}" -f $context.AccountEndpoint
$accessKey = $context.PrimaryAccountKey
#Create Azure Batch linked Service
$batchDefinition = @"
{
    "name": "AzureBatchLinkedService",
    "properties": {
        "type": "AzureBatch",
        "typeProperties": {
            "accountName": "$accountName",
            "accessKey": {
                "type": "SecureString",
                "value": "$accessKey"
            },
            "batchUri": "$batchUri",
            "poolName": "$poolName",
            "linkedServiceName": {
                "referenceName": "AzureStorageLinkedService",
                "type": "LinkedServiceReference"
            }
        }
    }
}
"@
## IMPORTANT: store the JSON definition in a file that will be used by the Set-AzureRmDataFactoryV2Dataset command. 
$batchDefinition | Out-File c:\BatchCompute.json

## Create a dataset in the data factory
Set-AzureRmDataFactoryV2LinkedService -DataFactoryName $dataFactoryName -ResourceGroupName $resourceGroupName -Name "BatchCompute" -File "c:\BatchCompute.json"
}
function runPipeline{
param ($tenantId, $dataFactoryName , $resourceGroupName, $servicePrincipal, $password, $jobid, $accountName, $batchUser, $pipelineName, $dsvm, $pythonPath, $sourceBlobPath, $sinkBlobPath, $gitProject, $projectDir)
## JSON definition of the pipeline

$gitClone = "git clone {0}" -f $gitProject
$runPS = "powershell.exe -file .\\blads_dcib_cinderella_spark_h2o\\batchTask.ps1 $tenantId $servicePrincipal $password $jobid $resourceGroupName $accountName $dsvm $pythonPath $gitProject"
$command = "cmd /c {0} && {1}" -f $gitClone, $runPS
"$command"
$pipelineDefinition = @"
{
    "name": "$pipelineName",
    "properties": {
        "activities": [
            {
              "type": "Custom",
              "name": "RunPC",
              "linkedServiceName": {
                "referenceName": "BatchCompute",
                "type": "LinkedServiceReference"
              },
              "typeProperties": {
                "command": "$command"
              },
              "resourceLinkedService": {
                "referenceName": "AzureStorageLinkedService",
                "type": "LinkedServiceReference"
              }
            }
        ]
    }
}
"@

## IMPORTANT: store the JSON definition in a file that will be used by the Set-AzureRmDataFactoryV2Pipeline command. 
$pipelineDefinition | Out-File c:\CopyPipeline.json

## Create a pipeline in the data factory
Set-AzureRmDataFactoryV2Pipeline -DataFactoryName $dataFactoryName -ResourceGroupName $resourceGroupName -Name $pipelineName -File "c:\CopyPipeline.json"

# Create a pipeline run 

## JSON definition for pipeline parameters
$pipelineParameters = @"
{
    "inputPath": "$sourceBlobPath",
    "outputPath": "$sinkBlobPath"
}
"@

## IMPORTANT: store the JSON definition in a file that will be used by the Invoke-AzureRmDataFactoryV2Pipeline command. 
$pipelineParameters | Out-File c:\PipelineParameters.json

# Create a pipeline run by using parameters
$runId = Invoke-AzureRmDataFactoryV2Pipeline -DataFactoryName $dataFactoryName -ResourceGroupName $resourceGroupName -PipelineName $pipelineName -ParameterFile c:\PipelineParameters.json
# Check the pipeline run status until it finishes the copy operation
while ($True) {
    $result = Get-AzureRmDataFactoryV2ActivityRun -DataFactoryName $dataFactoryName -ResourceGroupName $resourceGroupName -PipelineRunId $runId -RunStartedAfter (Get-Date).AddMinutes(-30) -RunStartedBefore (Get-Date).AddMinutes(30)

    if (($result | Where-Object { $_.Status -eq "InProgress" } | Measure-Object).count -ne 0) {
        Write-Host "Pipeline run status: In Progress" -foregroundcolor "Yellow"
        Start-Sleep -Seconds 30
    }
    else {
        Write-Host "Pipeline '$pipelineName' run finished. Result:" -foregroundcolor "Yellow"
        $result
        break
    }
}

# Get the activity run details 
    $result = Get-AzureRmDataFactoryV2ActivityRun -DataFactoryName $dataFactoryName -ResourceGroupName $resourceGroupName `
        -PipelineRunId $runId `
        -RunStartedAfter (Get-Date).AddMinutes(-10) `
        -RunStartedBefore (Get-Date).AddMinutes(10) `
        -ErrorAction Stop

    $result

    if ($result.Status -eq "Succeeded") {`
        $result.Output -join "`r`n"`
    }`
    else {`
        $result.Error -join "`r`n"`
    }
}
function addTrigger{
param ($dataFactoryName, $resourceGroupName, $pipelineName)
$triggeredDefinition =
@"
{
"properties": {
        "name": "MyTrigger",
        "type": "ScheduleTrigger",        
        "typeProperties": {
            "recurrence": {
                "frequency": "Hour",
                "interval": 1,
                "startTime":  "2017-11-14T09:00:00-08:00",
                "endTime": "2017-12-14T09:00:00-08:00"
            }
        },
        "pipelines": [
            {
                "pipelineReference": {
                    "type": "PipelineReference",
                    "referenceName": "$pipelineName"
                },
                "parameters": { }
            }
        ]
    }
}
"@
$triggeredDefinition | Out-File c:\TriggeredDefinition.json

Set-AzureRmDataFactoryV2Trigger -Name "Hourly" -DataFactoryName $dataFactoryName -ResourceGroupName $resourceGroupName -File "c:\TriggeredDefinition.json"
Start-AzureRmDataFactoryV2Trigger -DataFactoryName $dataFactoryName -Name "Hourly" -ResourceGroupName $resourceGroupName -Confirm
}
#endregion

#region Azure Data Factory configuration, execution, and scheduling

createResources $dataFactoryName $dataFactoryRegion $resourceGroupName 
addAzureStorage $dataFactoryName $resourceGroupName $storageAccountName
addBlobStorage $dataFactoryName $resourceGroupName
addBatchLinkedService $dataFactoryName $resourceGroupName $accountName $poolName
runPipeline $tenantId $dataFactoryName $resourceGroupName $servicePrincipal $password $jobid $accountName $batchUser $pipelineName $dsvm $pythonPath $sourceBlobPath $sinkBlobPath $gitProject $projectDir
#addTrigger $dataFactoryName $resourceGroupName $pipelineName

#endregion

#region Clean Up
# To remove the data factory from the resource gorup
# Remove-AzureRmDataFactoryV2 -Name $dataFactoryName -ResourceGroupName $resourceGroupName
# 
# To remove the whole resource group
# Remove-AzureRmResourceGroup  -Name $resourceGroupName
#endregion