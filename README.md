# Related Repositories

* Base images deployed by this Azure application
  * [twas-nd](https://github.com/WASdev/azure.websphere-traditional.image/tree/main/twas-nd)
  * [ihs](https://github.com/WASdev/azure.websphere-traditional.image/tree/main/ihs)
* [WebSphere traditional single server](https://github.com/WASdev/azure.websphere-traditional.singleserver)
* [Liberty on ARO](https://github.com/WASdev/azure.liberty.aro)
* [Liberty on AKS](https://github.com/WASdev/azure.liberty.aks)

# Deploy RHEL 8.4 VMs on Azure with IBM WebSphere Application Server ND Traditional V9.0.5 cluster and IBM HTTP Server V9.0 pre-installed

## Prerequisites

1. Register an [Azure subscription](https://azure.microsoft.com/).
1. The virtual machine offer which includes the image of RHEL 8.4 with IBM WebSphere and JDK pre-installed is used as image reference to deploy virtual machine on Azure. Before the offer goes live in Azure Marketplace, your Azure subscription needs to be added into white list to successfully deploy VM using ARM template of this repo.
1. Install [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest).
1. Install [PowerShell Core](https://docs.microsoft.com/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1).
1. Install [Maven](https://maven.apache.org/download.cgi).
1. Install [`jq`](https://stedolan.github.io/jq/download/).

## Steps of deployment

1. Checkout [azure-javaee-iaas](https://github.com/Azure/azure-javaee-iaas)
   1. Change to directory hosting the repo project & run `mvn clean install`
1. Checkout [arm-ttk](https://github.com/Azure/arm-ttk) under the specified parent directory
   1. Run `git checkout cf5c927eaf1f5652556e86a6b67816fc910d1b74` to checkout the verified version of `arm-ttk`
1. Checkout this repo under the same parent directory and change to directory hosting the repo project
1. Build the project by replacing all placeholder `${<place_holder>}` with valid values

   ```bash
   mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -DuseTrial=true -DnumberOfNodes=<numberOfNodes> -DvmSize=<vmSize> -DdmgrVMPrefix=<dmgrVMPrefix> -DmanagedVMPrefix=<managedVMPrefix> -DdnsLabelPrefix=<dnsLabelPrefix> -DadminUsername=<adminUsername> -DadminPasswordOrKey=<adminPassword|adminSSHPublicKey> -DauthenticationType=<password|sshPublicKey> -DwasUsername=<wasUsername> -DwasPassword=<wasPassword> -DconfigureIHS=<true|false> -DihsVmSize=<ihsVmSize> -DihsVMPrefix=<ihsVMPrefix> -DihsDnsLabelPrefix=<ihsDnsLabelPrefix> -DihsUnixUsername=<ihsUnixUsername> -DihsUnixPasswordOrKey=<ihsUnixPassword|ihsUnixSSHPublicKey> -DihsAuthenticationType=<password|sshPublicKey> -DihsAdminUsername=<ihsAdminUsername> -DihsAdminPassword=<ihsAdminPassword> -Dtest.args="-Test All" -Pbicep -Passembly -Ptemplate-validation-tests clean install
   ```

1. Change to `./target/cli` directory
1. Using `deploy.azcli` to deploy

   ```bash
   ./deploy.azcli -n <deploymentName> -g <resourceGroupName> -l <resourceGroupLocation>
   ```

## After deployment

1. If you check the resource group in [azure portal](https://portal.azure.com/), you will see multiple VMs and related resources specified for the cluster created
1. To open IBM WebSphere Integrated Solutions Console in browser for further administration:
   1. Login to Azure Portal
   1. Open the resource group you specified to deploy WebSphere Cluster
   1. Navigate to "Deployments > specified_deployment_name > Outputs"
   1. Copy value of property `adminSecuredConsole` and browse it with credentials you specified in cluster creation
   1. Copy value of property `ihsConsole` and open it in your browser if you selected to deploy IBM HTTP Server before
