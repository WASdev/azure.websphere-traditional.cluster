# Add additional nodes to the exsiting cluster

## Prerequisites
 - Register an [Azure subscription](https://azure.microsoft.com/en-us/)
 - The virtual machine offer which includes the image of RHEL7.4, IBM WebSphere & JDK is used as image reference to deploy virtual machine on Azure. Before the offer goes live in Azure Marketplace, your Azure subscription needs to be added into white list to successfully deploy VM using ARM template of this repo.
 - Install [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest)
 - Install [PowerShell Core](https://docs.microsoft.com/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1)
 - Install [Maven](https://maven.apache.org/download.cgi)
 - Install [`jq`](https://stedolan.github.io/jq/download/)

 ## Steps of deployment
 1. Checkout [azure-javaee-iaas](https://github.com/Azure/azure-javaee-iaas)
    - change to directory hosting the repo project & run `mvn clean install`
 2. Checkout [arm-ttk](https://github.com/Azure/arm-ttk) under the specified parent directory
 3. Checkout this repo under the same parent directory and change to directory hosting the repo project
 4. Change to sub-directory `add-nodes`
 5. Build the project by replacing all placeholder `${<place_holder>}` with valid values. You can get valid values of parameters from `outputs` of deployment which was used for creating the initial cluster, including `clusterName`, `nodeGroupName`, `coreGroupName`, `dmgrHostName`, `dmgrPort`, `virtualNetworkName` (mapped to `vNetName`) & `subnetName`.
    ```
    mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -DnumberOfNodes=<numberOfNodes> -DmanagedVMPrefix=<managedVMPrefix> -DdnsLabelPrefix=<dnsLabelPrefix> -DvmAdminId=<vmAdminId> -DvmAdminPwd=<vmAdminPwd> -DadminUser=<adminUser> -DadminPwd=<adminPwd> -DclusterName=<clusterName> -DnodeGroupName=<nodeGroupName> -DcoreGroupName=<coreGroupName> -DdmgrHostName=<dmgrHostName> -DdmgrPort=<dmgrPort> -DvNetName=<vNetName> -DsubnetName=<subnetName> -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
    ```
 6. Change to `./target/arm` directory
 7. Using `deploy.azcli` to deploy. Similar to step 5, you can get valid values of parameters `resourceGroupName` & `resourceGroupLocation` (mapped from `region`) from `outputs` of deployment which was used for creating the initial cluster.
    ```
    ./deploy.azcli -n <deploymentName> -i <subscriptionId> -g <resourceGroupName> -l <resourceGroupLocation>
    ```

## After deployment
- If you check the resource group in [azure portal](https://portal.azure.com/), you will see new VMs and related resources created
- Open VM resource blade of deployment manager and copy its DNS name, then open IBM WebSphere Integrated Solutions Console for further administration by browsing https://<dns_name>:9043/ibm/console
- The deployment manager and node agent running in the cluster will be automatically started whenever the virtual machine is rebooted. In case you want to mannually stop/start/restart the process, using the following commands:
  ```
  /opt/IBM/WebSphere/ND/V9/bin/stopServer.sh <serverName>   # stop server
  /opt/IBM/WebSphere/ND/V9/bin/startServer.sh <serverName>  # start server
  ```
