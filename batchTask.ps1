Param(
    [string]$tenantId,
    [string]$servicePrincipal,
    [string]$password,
    [string]$jobid,
    [string]$rg,
    [string]$batch,
    [string]$batchUser,
    [string]$dsvm,
    [string]$pythonPath,
    [string]$gitProject,
    [string]$projectDir"
)

$secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
$secureCredential = New-Object System.Management.Automation.PSCredential ($servicePrincipal, $secpasswd)

#region Commands needed to run experiment
$setPath = "set PATH=%LOCALAPPDATA%\amlworkbench\Python;%LOCALAPPDATA%\amlworkbench\Python\Scripts;%PATH%"
$gitClone = "git clone {0}" -f $gitProject
$azLogin = "az login --service-principal -u {0} --password {1} --tenant {2}" -f $servicePrincipal, $password, $tenantId
$cd = "cd .\{0}" -f $projectDir
$azmlExperiment = "az ml experiment submit -c {0} --wait {1}" -f $dsvm, $pythonPath
$command= "cmd /c {0} && {1} && {2} && {3} && {4}" -f $setPath, $gitClone, $azLogin, $cd, $azmlExperiment
"$command"
#endregion

Add-AzureRmAccount -ServicePrincipal -Tenant $tenantId -Credential $secureCredential

$context = Get-AzureRmBatchAccountKeys -ResourceGroupName alicebobandnick -AccountName alicebatch
$userIdentity = New-Object Microsoft.Azure.Commands.Batch.Models.PSUserIdentity $batchUser
$taskid = "azmltask{0:G}" -f [int][double]::Parse((Get-Date -UFormat %s))

##Start-AzureRmVM -Name alicedsvm5 -ResourceGroupName alicebobandnick

Get-AzureBatchJob -Id $jobid -BatchContext $Context | New-AzureBatchTask -Id $taskid -CommandLine $command -UserIdentity $batchUser -BatchContext $Context
"$taskid"

#region Wait while task runs...
while((Get-AzureBatchTask -JobId $jobid -Id $taskid -BatchContext $context).PreviousState -ne "Running"){
    "Sleep..."
    Start-Sleep -Seconds 60
}
"Done!"
#endregion
"Stopping..."
##Stop-AzureRmVM -Name alicedsvm5 -ResourceGroupName alicebobandnick -StayProvisioned -Confirm false
"Stopped!"
