# Test cases for IBM WebSphere Application Server Cluster offer

To ensure no regressions introduced for any changes added to the IBM WebSphere Application Server Cluster offer, the following test cases must be successfully executed with the expected results before clicking "Go live" for the offer. 

During the execution of the test cases, please open issues for any unexpected results you observed with the reproducible steps.

## Test case 1: User fails to deploy a cluster with an invalid IBMid

Follow steps below to execute the test case:

1. Open offer in the browser ([live offer link](https://portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2021-04-08-twas-clustercluster) or [preview link](https://portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2021-04-08-twas-cluster-previewcluster)).
1. Click "Create".
1. The "Basics" tab should be displayed
   1. Create new resource group.
   1. Provide an invalid IBMid.
   1. Accept the IBM License Agreement.
1. Click "Next: Cluster configuration" to switch to the next tab.
   1. Set password or SSH public key per authentication type for VM administrator.
   1. Set password for WebSphere administrator.
1. Click "Next: IBM HTTP Server Load Balancer" to switch to the next tab.
   1. Set password or SSH public key per authentication type for VM administrator.
   1. Set password for IBM HTTP Server administrator.
1. Click "Next: Review + create" to switch to the next tab.
   1. Wait and see if validation passed.
   1. For any validation errors, switch to the related tab and fix errors based on validation messages. Re-visit this tab until validation passed.
1. Click "Create" to kick off the deployment.
1. Wait until the deployment failed. You should see the error details including the following message:
   1. The provided IBMid does not have entitlement to install WebSphere Application Server. Please contact the primary or secondary contacts for your IBM Passport Advantage site to grant you access or follow steps at IBM eCustomer Care (https://ibm.biz/IBMidEntitlement) for further assistance.
1. Expand "Deployment details" > find new created "Microsoft.Network/networkSecurityGroups" resource ended with "-nsg" > click its name > click "TCP" > append ",22" to the value of field "Destination port ranges" > click "Save". Wait until change completes.
1. Switch back to deployment page > make sure "Deployment details" is expanded
   1. For new created "Microsoft.Compute/virtualMachines" resource prefixed with "dmgr" > click its name > copy its "Public IP address" > Open a terminal > ssh with websphere vm administrator user name and password/private key > check that there is nothing in directory "/datadrive".
   1. Repeat step #a for another VM prefixed with "ihs".
1. Delete the resource group to free up the resource.

## Test case 2: User can successfully deploy a cluster with IBM HTTP Server configured

Follow steps below to execute the test case:

1. Open offer in the browser ([live offer link](https://portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2021-04-08-twas-clustercluster) or [preview link](https://portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2021-04-08-twas-cluster-previewcluster)).
1. Click "Create".
1. The "Basics" tab should be displayed
   1. Create new resource group.
   1. Provide an entitled IBMid.
   1. Accept the IBM License Agreement.
1. Click "Next: Cluster configuration" to switch to the next tab.
   1. Set password or SSH public key per authentication type for VM administrator.
   1. Set password for WebSphere administrator.
1. Click "Next: IBM HTTP Server Load Balancer" to switch to the next tab.
   1. Set password or SSH public key per authentication type for VM administrator.
   1. Set password for IBM HTTP Server administrator.
1. Click "Next: Review + create" to switch to the next tab.
   1. Wait and see if validation passed.
   1. For any validation errors, switch to the related tab and fix errors based on validation messages. Re-visit this tab until validation passed.
1. Click "Create" to kick off the deployment.
1. Wait until the deployment successfully completes.
1. Open "Outputs" of the deployment page
   1. Copy value of property "adminSecuredConsole" > Open it in the browser tab > You should see login page of "WebSphere Integrated Solutions Console".
   1. Copy value of property "ihsConsole" > Open it in the browser tab > You should see welcome page of "IBM HTTP Server".
1. Sign into "WebSphere Integrated Solutions Console" with the user name and password you specified for the WebSphere administrator before.
1. In the left navigation area, click "Servers" > "Clusters" > "WebSphere application server clusters"
   1. Check "MyCluster" is listed and its status is started.
   1. Click "MyCluster" > "Cluster members" > Check 3 cluster members are listed.
1. In the left navigation area, click "Servers" > "Server Types" > "Web servers"
   1. Check "webserver1" is listed and its status is started.
   1. Click " webserver1" > "Intelligent Management" > Check "Enable" is checked.
1. In the left navigation area, click "System administration" > "Console Preferences" > Check "Synchronize changes with Nodes" > click "Apply".
1. In the left navigation area, click "Applications" > "Application Types" > "WebSphere enterprise applications".
   1. Click "Install" > Select "Remote file system" > click "Browse..." > select "Dmgr001Node" > click "V9" > click "installableApps" > select "DefaultApplication.ear" > click "OK" > click "Next" > "Next" > "Next" > Press Ctrl and click all items listed in "Clusters and servers", select all modules, click "Apply", click "Next" > Select all modules, click "Next" > click "Finish" > click "Save" > click "OK" until you see all nodes are synchronized.
   1. Select "DefaultApplication.ear" > Click "Start". You should see messages indicating application successfully started.
1. Switch to welcome page of IBM HTTP Server > Append "/snoop" to the address bar and press "Enter". You should see Snoop Servlet page displayed.
   1. Locate to table "Request Information:" and take a note for the values of properties "Local address" and "Local host".
   1. Refresh the page, you should see the values of properties "Local address" and "Local host" are updated.
   1. Repeat the above step until you observe all of cluster members appeared.
1. Switch to deployment page > click "Overview" > Expand "Deployment details"
   1. For each of new created resource with type "Microsoft.Compute/virtualMachines" > click its name > click "Restart" to restart VM. Repeat for all of VMs.
   1. Wait until all of VMs are restarted.
1. Switch to page of "WebSphere Integrated Solutions Console" > Wait until it’s accessible. Repeat steps #11 and #12. Note: you need to wait for a while before the cluster member servers are restarted. Refresh the page to get the status update of the cluster.
1. Switch to Snoop Servlet page > Wait until it’s accessible. Repeat Step #15.
1. Delete the resource group to free up the resource.

## Test case 3: User can successfully deploy a cluster without IBM HTTP Server configured

Follow steps below to execute the test case:

1. Open offer in the browser ([live offer link](https://portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2021-04-08-twas-clustercluster) or [preview link](https://portal.azure.com/#create/ibm-usa-ny-armonk-hq-6275750-ibmcloud-aiops.2021-04-08-twas-cluster-previewcluster)).
1. Click "Create".
1. The "Basics" tab should be displayed
   1. Create new resource group.
   1. Provide an entitled IBMid.
   1. Accept the IBM License Agreement.
1. Click "Next: Cluster configuration" to switch to the next tab.
   1. Set password or SSH public key per authentication type for VM administrator.
   1. Set password for WebSphere administrator.
1. Click "Next: IBM HTTP Server Load Balancer" to switch to the next tab.
   1. Select "No" for option "Configure an IBM HTTP Server?".
1. Click "Next: Review + create" to switch to the next tab.
   1. Wait and see if validation passed.
   1. For any validation errors, switch to the related tab and fix errors based on validation messages. Re-visit this tab until validation passed.
1. Click "Create" to kick off the deployment.
1. Wait until the deployment successfully completes.
1. Open "Outputs" of the deployment page
   1. Copy value of property "adminSecuredConsole" > Open it in the browser tab > You should see login page of "WebSphere Integrated Solutions Console".
   1. Check value of property "ihsConsole" is "N/A".
1. Sign into "WebSphere Integrated Solutions Console" with the user name and password you specified for the WebSphere administrator before.
1. In the left navigation area, click "Servers" > "Clusters" > "WebSphere application server clusters"
   1. Check "MyCluster" is listed and its status is started.
   1. Click "MyCluster" > "Cluster members" > Check 3 cluster members are listed.
1. Switch to deployment page > click "Overview" > Expand "Deployment details"
   1. For each of new created resource with type "Microsoft.Compute/virtualMachines" > click its name > click "Restart" to restart VM. Repeat for all of VMs.
   1. Wait until all of VMs are restarted.
1. Switch to page of "WebSphere Integrated Solutions Console" > Wait until it’s accessible. Repeat steps #11. Note: you need to wait for a while before the cluster member servers are restarted. Refresh the page to get the status update of the cluster.
1. Delete the resource group to free up the resource.
