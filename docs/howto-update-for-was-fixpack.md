# How to update the tWAS on Azure VMs solution for next tWAS fixpack

Please follow sections below in order to update the solution for next tWAS fixpack.

## Updating the image

1. Which file to update for WAS version?
   * For `twas-nd` image, update the following properties in file [`virtualimage.properties`](https://github.com/WASdev/azure.websphere-traditional.image/blob/master/twas-nd/src/main/scripts/virtualimage.properties#L14-L15), e.g.:

     ```bash
     WAS_ND_TRADITIONAL=com.ibm.websphere.ND.v90
     IBM_JAVA_SDK=com.ibm.java.jdk.v8
     ```

     Note: only the major version should be specified, the minor version should not be hard-coded as the Installation Manager will intelligently install the latest available minor version.

   * For `ihs` image, update the following properties in file [`virtualimage.properties`](https://github.com/WASdev/azure.websphere-traditional.image/blob/master/ihs/src/main/scripts/virtualimage.properties#L22-L25), e.g.:

     ```bash
     IBM_HTTP_SERVER=com.ibm.websphere.IHS.v90
     WEBSPHERE_PLUGIN=com.ibm.websphere.PLG.v90
     WEBSPHERE_WCT=com.ibm.websphere.WCT.v90
     IBM_JAVA_SDK=com.ibm.java.jdk.v8
     ```

     Note: only the major version should be specified, the minor version should not be hard-coded as the Installation Manager will intelligently install the latest available minor version.

1. How to run CI/CD?
   * Go to [Actions](https://github.com/WASdev/azure.websphere-traditional.image/actions) > Click `twas-nd CICD` > Click to expand `Run workflow` > Click `Run workflow` > Refresh the page
   * Go to [Actions](https://github.com/WASdev/azure.websphere-traditional.image/actions) > Click `ihs CICD` > Click to expand `Run workflow` > Click `Run workflow` > Refresh the page

1. How to test the image, what testcases to run?
   * The CI/CD has already contains tests to verify the entitlement check and tWAS installation, so basically it's good to go without manual tests.

1. How to publish the image in marketplace and who can do it?
   1. For `twas-nd` image: Wait until the CI/CD workflow for `twas-nd CICD` successfully completes > Click to open details of the workflow run > Scroll to the bottom of the page > Click `sasurl` to download the zip file `sasurl.zip` > Unzip and open file `sas-url.txt` > Find values for `osDiskSasUrl` and `dataDiskSasUrl`;
   1. For `ihs` image: Wait until the CI/CD workflow for `ihs CICD` successfully completes > Click to open details of the workflow run > Scroll to the bottom of the page > Click `sasurl` to download the zip file `sasurl.zip` > Unzip and open file `sas-url.txt` > Find values for `osDiskSasUrl` and `dataDiskSasUrl`;
   1. Sign into [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview)
      * Select the Directory `IBM-Alliance-Microsoft Partner Network-Global-Tenant`
      * Expand `Build solutions` and choose `Publish your solution`.  
      * Click to open the offer for `<date>-twas-cluster-base-image` base image
      * Click `Plan overview` the click to open the plan 
      * Click `Technical configuration` 
      * Click `+ Add VM image` > Specify a new value for `Disk version`, following the convention \<major version\>.YYYYMMDD, e.g. 9.0.20210929 and write it down (We deliberately do not specify the minor verson because the pipeline gets the latest at the time it is run). 
      * Select `SAS URI` > Copy and paste value of `osDiskSasUrl` for `twas-nd` (from the earlier steps) to the textbox `SAS URI` 
      * Click `+ Add data disk (max 16)` > Select `Data disk 0` > Copy and paste value of `dataDiskSasUrl` for `twas-nd` (from the earlier steps) to the textbox `Data disk VHD link`
      * Scroll to the bottom of the page and click `Save draft`
      * Click `Review and publish`
      * Click `Publish`;
   3. Sign into [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview)
      * Select the Directory `IBM-Alliance-Microsoft Partner Network-Global-Tenant`
      * Expand `Build solutions` and choose `Publish your solution`.  
      * Click to open the offer for `ihs base image` 
      * Click `Plan overview` and click to open the plan
      * Click `Technical configuration`
      * Click `+ Add VM image` > Specify a new value for `Disk version`, following the convention \<major version\>.YYYYMMDD, e.g. 9.0.20210929 and write it down (We deliberately do not specify the minor verson because the pipeline gets the latest at the time it is run). 
      * Select `SAS URI` > Copy and paste value of `osDiskSasUrl` for `ihs` (from the earlier steps) to the textbox `SAS URI`
      * Click `+ Add data disk (max 16)` > Select `Data disk 0` > Copy and paste value of `dataDiskSasUrl` for `ihs` (from the earlier steps) to the textbox `Data disk VHD link`
      * Scroll to the bottom of the page and click `Save draft`
      * Click `Review and publish`
      * Click `Publish`;

   Note: Currently Graham Charters has privilege to update the image in marketplace, contact him for more information.

1. Do we need to update the solution every time we do the image update?
   * Yes. That's because image versions of [`twas-nd`](https://github.com/WASdev/azure.websphere-traditional.cluster/blob/master/pom.xml#L51) and [`ihs`](https://github.com/WASdev/azure.websphere-traditional.cluster/blob/master/pom.xml#L57) are explicitely referenced in the tWAS solutoin. Make sure correct image versions are specified in the `pom.xml` of the solution code.

## Updating and publishing the solution code

Note: The steps included in this section are also applied to release new features / bug fixes which have no changes to the images.

1. How to update the version of the solution?
   * Increase the [version number](https://github.com/WASdev/azure.websphere-traditional.cluster/blob/master/pom.xml#L23) which is specified in the `pom.xml`
   * Also update the `twasnd.image.version` and `ihs.image.version` (obtained from publish step)

1. How to run CI/CD?
   * Go to [Actions](https://github.com/WASdev/azure.websphere-traditional.cluster/actions) > Click `Package ARM` > Click to expand `Run workflow` > Click `Run workflow` > Refresh the page

1. How to publish the solution in marketplace and who can do it?
   1. Wait until the CI/CD workflow for `Package ARM` successfully completes 
       * Click to open details of the workflow run > Scroll to the bottom of the page
       * Click `azure.websphere-traditional.cluster-<version>-arm-assembly` to download the zip file `azure.websphere-traditional.cluster-<version>-arm-assembly.zip`;
   3. Sign into [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview)
       * Click to open the offer for the solution > Click `Plan overview`
       * Click to open the plan > Click `Technical configuration`
       * Specify the increased version number for `Version`
       * Click `Remove` to remove the previous package file
       * Click `browse your file(s)` to upload the downloaded zip package generated by the CI/CD pipeline before
       * Scroll to the bottom of the page
       * Click `Save draft`
       * Click `Review and publish`
       * Click `Publish`

   Note: Currently Graham Charters has privilege to update the solution in marketplace, contact him for more information.

1. Create a [release](https://github.com/WASdev/azure.websphere-traditional.cluster/releases) for this GA code and tag with the pom.xml version number.

1. How to test the solution, what testcases to run?
   1. Wait until the soluton offer is in `Publisher signoff` (aka "preview") stage;
   1. Run test cases defined in [twas-solution-test-cases.pdf](twas-solution-test-cases.pdf). Note: use "preview link" for each test case.

## What needs to be cleaned up from test env and how to clean them up?

Azure marketplace is responsible for managing different stages during the offer publishing, just follow its process to make it Go-Live and no additional clean-ups are needed.

## Do we delete/archive previous version of the solution?

Previous versions of the solution are archived. You can find/download them from "Offer > Plan overview > Technical configuration > Previously published packages".

## Create a release and a branch with the GA code (for image and cluster repo)

Probably creating a release/tag for each GA code is good enough.
