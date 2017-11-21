# Running Spark Jobs on Azure Batch with AMLW
This process uses the open source toolkit [AZTK](github.com/azure/aztk)

## Prereq 
1. AML Workbench installed and project set up

## Steps

1. Clone the AZTK repo
```bash
    git clone -b stable https://www.github.com/azure/aztk

    # You can also clone directly from master to get the latest bits
    git clone https://www.github.com/azure/aztk
```
1. Use pip to install required packages (requires python 3.5+ and pip 9.0.1+), make sure that your pip is for Python3. 
```bash
    pip3 install -r requirements.txt
```
1. Use setuptools:
```bash
    pip3 install -e .
```
1. Move into your AML Workspace Project directory:
```bash
    cd C:\Users\{user}\Documents\AML Workbench\{project}
```
1. Initialize the project in your AML Workspace Project directory [This will automatically create a *.aztk* folder with config files in your working directory]:
```bash
    aztk spark init
```
1. Fill in the fields for your Batch account and Storage account in your *.aztk/secrets.yaml* file. (We'd also recommend that you enter SSH key info in this file)

   This package is built on top of two core Azure services, [Azure Batch](https://azure.microsoft.com/en-us/services/batch/) and [Azure Storage](https://azure.microsoft.com/en-us/services/storage/). Create those resources via the portal (see [Getting Started](./docs/00-getting-started.md)).

1. Create and setup your cluster

First, create your cluster:
```bash
aztk spark cluster create \
    --id <my_cluster_id> \
    --size <number_of_nodes> \
    --vm-size <vm_size>
```
You can find more information on VM sizes [here.](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/sizes) Please note that you must use the official SKU name when setting your VM size - they usually come in the form: "standard_d2_v2".

You can also create your cluster with [low-priority](https://docs.microsoft.com/en-us/azure/batch/batch-low-pri-vms) VMs at an 80% discount by using `--size-low-pri` instead of `--size` (we currently do not support mixed low-priority and dedicated VMs):
```
aztk spark cluster create \
    --id <my_cluster_id> \
    --size-low-pri <number_of_low-pri_nodes> \
    --vm-size <vm_size>
```
1. Retrieve SSH information for the cluster.
```bash
aztk spark cluster ssh --id <my_cluster_id> --no-connect
```
1. Attach Compute to AML Workbench
```bash
az ml computetarget attach --name <my_cluster_id> --address <IP>:<Port> --username spark --password <password> --type remotedocker
```
1. Prepare Azure Batch Spark cluster
```bash
az ml experiment prepare -c <my_cluster_id>
```
1. Submit experiments to your cluster like you would any other compute target using either the CLI or Workbench.
```bash
az ml experiment submit -c <my_cluster_id> <mySparkJob.py>
```


