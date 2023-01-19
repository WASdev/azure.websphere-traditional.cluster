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
   mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -DuseTrial=true -DnumberOfNodes=<numberOfNodes> -DvmSize=<vmSize> -DdmgrVMPrefix=<dmgrVMPrefix> -DmanagedVMPrefix=<managedVMPrefix> -DdnsLabelPrefix=<dnsLabelPrefix> -DadminUsername=<adminUsername> -DadminPasswordOrKey=<adminPassword|adminSSHPublicKey> -DauthenticationType=<password|sshPublicKey> -DwasUsername=<wasUsername> -DwasPassword=<wasPassword> -DselectLoadBalancer=<appgw|ihs|none> -DenableCookieBasedAffinity=<true|false> -DihsVmSize=<ihsVmSize> -DihsVMPrefix=<ihsVMPrefix> -DihsDnsLabelPrefix=<ihsDnsLabelPrefix> -DihsUnixUsername=<ihsUnixUsername> -DihsUnixPasswordOrKey=<ihsUnixPassword|ihsUnixSSHPublicKey> -DihsAuthenticationType=<password|sshPublicKey> -DihsAdminUsername=<ihsAdminUsername> -DihsAdminPassword=<ihsAdminPassword> -DenableDB=<true|false> -DdatabaseType=<db2|oracle|sqlserver> -DjdbcDataSourceJNDIName=<jdbcDataSourceJNDIName> -DdsConnectionURL=<dsConnectionURL> -DdbUser=<dbUser> -DdbPassword=<dbPassword> -Dtest.args="-Test All" -Pbicep -Passembly -Ptemplate-validation-tests clean install
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

## Deployment Description

The offer provisions the following Azure resources and a WebSphere Application Server ND cluster.

* Computing resources
  * VMs with the followings configurations:
     * OS: RHEL 8.4
     * JDK: IBM Java JDK 8
     * WebSphere Traditional version: 9.0.5.x.
  * Several VMs consisting of a WebSphere Application Server ND 9.0.5.x cluster with the following configurations:
    * A VM to run the WebSphere deployment manager and an arbitrary number of VMs to run the worker nodes of the cluster.
    * Choice of VM size.
    * An OS disk and a data disk is attached to the VM.
  * An IHS VM if user selects to deploy an IHS as load balancer, with the following configurations:
    * Choice of VM size.
    * An OS disk and a data disk is attached to the VM.
* Network resources
  * A virtual network and one or two subnets. User can also choose to deploy into an existing virtual network.
    * Two subnets are required if user selects to deploy an Azure Application Gateway.
    * A network security group if you select to create a new virtual network.
  * Several network interfaces:
    * One network interface for each VM.
    * One network interface created for private endpoint of the stroage account if user selects to deploy an IBM HTTP Server (IHS) as load balancer.
* Load Balancer
  * Choice of IBM Http Server (IHS) or Azure Application Gateway.
  * Several public IP addresses:
    * One public IP address assigned to the network interface of WebSphere deployment manager VM if user selects to create a new virtual network.
    * One public IP address assigned to the network interface of IHS VM if user selects to create a new virtual network and deploy an IHS as load balancer.
    * One public IP address assigned to the Azure Application Gateway if user selects to deploy an Azure Application Gateway as load balancer.
  * A Private Endpoint for the storage account if user selects to deploy an IHS as load balancer.
* Storage resources
  * A storage account for VM boot diagnostics, and sharing files if user selects to deploy an IHS as load balancer.
* Key software components
  * A WebSphere Application Server ND 9.0.5.x installed on each VM of the cluster with the following configurations:
    * The `WAS_INSTALL_ROOT` is `/datadrive/IBM/WebSphere/ND/V9`.
    * Options to deploy with existing WebSphere entitlement or with evaluation licens.
    * WebSphere administrator credential.
    * Database data source connection if user selects to connect a database.
  * IBM HTTP Server installed on the IHS VM with the following configurations:
    * Options to deploy with existing WebSphere entitlement or with evaluation licens.
    * IHS administrator credential.
  * IBM Java JDK 8. The `JAVA_HOME` is `${WAS_INSTALL_ROOT}/java/8.0`.

