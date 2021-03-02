# Create cluster with specified number of nodes

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
 4. Change to sub-directory `arm-rhel-was-nd-cluster`
 5. Build the project by replacing all placeholder `${<place_holder>}` with valid values
    - set `-Ddynamic=false` to create static cluster, and set `-Ddynamic=true` to create dynamic cluster
    - connect to DB2 Server & Elastic Stack for static/dynamic 
      ```
      mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -Ddynamic=<true|false> -DnumberOfNodes=<numberOfNodes> -DdmgrVMPrefix=<dmgrVMPrefix> -DmanagedVMPrefix=<managedVMPrefix> -DdnsLabelPrefix=<dnsLabelPrefix> -DvmAdminId=<vmAdminId> -DvmAdminPwd=<vmAdminPwd> -DadminUser=<adminUser> -DadminPwd=<adminPwd> -DconnectToDB2Server=true -Ddb2ServerName=<db2ServerName> -Ddb2ServerPortNumber=<db2ServerPortNumber> -Ddb2DBName=<db2DBName> -Ddb2DBUserName=<db2DBUserName> -Ddb2DBUserPwd=<db2DBUserPwd> -Ddb2DSJndiName=<db2DSJndiName> -DconnectToELK=true -DcloudId=<cloudId> -DcloudAuthUser=<cloudAuthUser> -DcloudAuthPwd=<cloudAuthPwd> -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
      ```
    - connect to DB2 Server only
      ```
      mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -Ddynamic=<true|false> -DnumberOfNodes=<numberOfNodes> -DdmgrVMPrefix=<dmgrVMPrefix> -DmanagedVMPrefix=<managedVMPrefix> -DdnsLabelPrefix=<dnsLabelPrefix> -DvmAdminId=<vmAdminId> -DvmAdminPwd=<vmAdminPwd> -DadminUser=<adminUser> -DadminPwd=<adminPwd> -DconnectToDB2Server=true -Ddb2ServerName=<db2ServerName> -Ddb2ServerPortNumber=<db2ServerPortNumber> -Ddb2DBName=<db2DBName> -Ddb2DBUserName=<db2DBUserName> -Ddb2DBUserPwd=<db2DBUserPwd> -Ddb2DSJndiName=<db2DSJndiName> -DconnectToELK=false -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
      ```
    - connect to Elastic Stack only 
      ```
      mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -Ddynamic=<true|false> -DnumberOfNodes=<numberOfNodes> -DdmgrVMPrefix=<dmgrVMPrefix> -DmanagedVMPrefix=<managedVMPrefix> -DdnsLabelPrefix=<dnsLabelPrefix> -DvmAdminId=<vmAdminId> -DvmAdminPwd=<vmAdminPwd> -DadminUser=<adminUser> -DadminPwd=<adminPwd> -DconnectToDB2Server=false -DconnectToELK=true -DcloudId=<cloudId> -DcloudAuthUser=<cloudAuthUser> -DcloudAuthPwd=<cloudAuthPwd> -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
      ```
    - connect to neither DB2 Server nor Elastic Stack 
      ```
      mvn -Dgit.repo=<repo_user> -Dgit.tag=<repo_tag> -Ddynamic=<true|false> -DnumberOfNodes=<numberOfNodes> -DdmgrVMPrefix=<dmgrVMPrefix> -DmanagedVMPrefix=<managedVMPrefix> -DdnsLabelPrefix=<dnsLabelPrefix> -DvmAdminId=<vmAdminId> -DvmAdminPwd=<vmAdminPwd> -DadminUser=<adminUser> -DadminPwd=<adminPwd> -DconnectToDB2Server=false -DconnectToELK=false -Dtest.args="-Test All" -Ptemplate-validation-tests clean install
      ```
 6. Change to `./target/arm` directory
 7. Using `deploy.azcli` to deploy
    ```
    ./deploy.azcli -n <deploymentName> -i <subscriptionId> -g <resourceGroupName> -l <resourceGroupLocation>
    ```

## After deployment
- If you check the resource group in [azure portal](https://portal.azure.com/), you will see multiple VMs and related resources specified for the cluster created
- To open IBM WebSphere Integrated Solutions Console in browser for further administration:
  - Login to Azure Portal
  - Open the resource group you specified to deploy WebSphere Cluster
  - Navigate to "Deployments > specified_deployment_name > Outputs"
  - Copy value of property `adminSecuredConsole` and browse it with credentials you specified in cluster creation
- The deployment manager and node agent running in the cluster will be automatically started whenever the virtual machine is rebooted. In case you want to mannually stop/start/restart the process, using the following commands:
  ```
  /opt/IBM/WebSphere/ND/V9/bin/stopServer.sh <serverName>   # stop server
  /opt/IBM/WebSphere/ND/V9/bin/startServer.sh <serverName>  # start server
  ```
