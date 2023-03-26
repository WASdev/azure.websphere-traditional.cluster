# How to update the tWAS on Azure VMs solution for next tWAS fixpack

Please follow sections below in order to update the solution for next tWAS fixpack.

## Updating the image

1. Which file to update for WAS, IHS and BigFix client versions?
   * For WAS version in `twas-nd` image, update the following properties in file [`virtualimage.properties`](https://github.com/WASdev/azure.websphere-traditional.image/blob/main/twas-nd/src/main/scripts/virtualimage.properties#L14-L15), e.g.:

     ```bash
     WAS_ND_TRADITIONAL=com.ibm.websphere.ND.v90
     IBM_JAVA_SDK=com.ibm.java.jdk.v8
     ```

     Note: only the major version should be specified, the minor version should not be hard-coded as the Installation Manager will intelligently install the latest available minor version.

   * For BigFix client version in `twas-nd` image, update the following properties in file [`virtualimage.properties`](https://github.com/WASdev/azure.websphere-traditional.image/blob/main/twas-nd/src/main/scripts/virtualimage.properties#L32-L34), e.g.:

     ```bash
     BES_AGENT_RPM=BESAgent-10.0.8.37-rhe6.x86_64.rpm
     BES_AGENT_RPM_URL=https://software.bigfix.com/download/bes/100/${BES_AGENT_RPM}
     GPG_RPM_PUBLIC_KEY_URL=https://software.bigfix.com/download/bes/95/RPM-GPG-KEY-BigFix-9-V2
     ```

     Note: these properties shouldn't be updated unless there're new versions/updates available.

   * For IHS version in `ihs` image, update the following properties in file [`virtualimage.properties`](https://github.com/WASdev/azure.websphere-traditional.image/blob/main/ihs/src/main/scripts/virtualimage.properties#L14-L17), e.g.:

     ```bash
     IBM_HTTP_SERVER=com.ibm.websphere.IHS.v90
     WEBSPHERE_PLUGIN=com.ibm.websphere.PLG.v90
     WEBSPHERE_WCT=com.ibm.websphere.WCT.v90
     IBM_JAVA_SDK=com.ibm.java.jdk.v8
     ```

     Note: only the major version should be specified, the minor version should not be hard-coded as the Installation Manager will intelligently install the latest available minor version.

1. When to update the images?
- For new tWAS fixpack, try to update the image soon after the fixpack GA but no longer than one week after the GA.
- Images may also need to updated to fix a critical WebSphere or OS fixes.

3. How to run CI/CD?
   * Go to [Actions](https://github.com/WASdev/azure.websphere-traditional.image/actions) > Click `twas-nd CICD` > Click to expand `Run workflow` > Click `Run workflow` > Refresh the page
   * Go to [Actions](https://github.com/WASdev/azure.websphere-traditional.image/actions) > Click `ihs CICD` > Click to expand `Run workflow` > Click `Run workflow` > Refresh the page
   * If Workflow does not kick off from the UI, try the command line:
   ```
   PERSONAL_ACCESS_TOKEN=<access-token>
   REPO_NAME=WASdev/azure.websphere-traditional.image
   curl --verbose -X POST https://api.github.com/repos/${REPO_NAME}/dispatches -H "Accept: application/vnd.github.everest-preview+json" -H "Authorization: token ${PERSONAL_ACCESS_TOKEN}" --data '{"event_type": "integration-test-all"}
   ```

1. How to test the image, what testcases to run?
   * The CI/CD has already contains tests to verify the entitlement check and tWAS installation, so basically it's good to go without manual tests.
   * However, if CI/CD failed, please look at error messages from the CI/CD logs, and [access the source VM](https://github.com/WASdev/azure.websphere-traditional.image/blob/main/docs/howto-access-source-vm.md) for troubleshooting if necessary.

1. How to publish the image in marketplace and who can do it?
   1. For `twas-nd` image: Wait until the CI/CD workflow for `twas-nd CICD` successfully completes > Click to open details of the workflow run > Scroll to the bottom of the page > Click `sasurl-twasnd` to download the zip file `sasurl-twasnd.zip` > Unzip and open file `sas-url-twasnd.txt` > Find values for `osDiskSasUrl` and `dataDiskSasUrl`;
   1. For `ihs` image: Wait until the CI/CD workflow for `ihs CICD` successfully completes > Click to open details of the workflow run > Scroll to the bottom of the page > Click `sasurl-ihs` to download the zip file `sasurl-ihs.zip` > Unzip and open file `sas-url-ihs.txt` > Find values for `osDiskSasUrl` and `dataDiskSasUrl`;
   1. Sign into [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview): Repeat these steps for ND and IHS images.
      * Select the Directory `IBM-Alliance-Microsoft Partner Network-Global-Tenant`
      * Expand `Build solutions` and choose `Publish your solution`.  
      * Click to open the offer for `2023-03-23-twas-cluster-base-image` ND base image (`2021-06-03-ihs-base-image` for IHS base image)
      * Click `Plan overview` then click to open the plan
      * **IMPORTANT** Click `Pricing and availability` to verify the plan is NOT hidden from the marketplace
         * Ensure the `Hide plan` checkbox is NOT checked
      * Click `Technical configuration` 
      * Scroll down and click `+` under "VM images" > Specify a new value for `Version number`, following the convention \<major version\>.YYYYMMDD, e.g. 9.0.20210929 and write it down (We deliberately do not specify the minor verson because the pipeline gets the latest at the time it is run). 
      * Under `SAS URI` > `Add OS Disk`. Copy and paste value of `osDiskSasUrl` for `twas-nd` or `ihs` (from the earlier steps) to the textbox `OS VHD Link` 
      * Click `+ Add data disk` > Select `Data disk 0` > Copy and paste value of `dataDiskSasUrl` for `twas-nd` or `ihs` (from the earlier steps) to the textbox `Data disk VHD link`
      * Scroll to the bottom of the page and click `Save draft`
      * Click `Review and publish`
      * In the "Notes for certification" section enter the twas-nd or ihs CICD URL
      * Click `Publish`;
      * Wait for few hours to a day, keep refreshing the page until "Go Live" button appears
      * Click on "Go Live" and wait again (for few hours) for the image to be published. See [screenshots](https://github.com/WASdev/azure.websphere-traditional.cluster/issues/138#issuecomment-1034053293)
      * **Note:** After the image is successfully published and available, please [clean up the storage account with VHD files](https://github.com/WASdev/azure.websphere-traditional.image/blob/main/docs/howto-cleanup-after-image-published.md) for reducing Azure cost.
      * Now proceed to [Updating and publishing the solution code](#updating-and-publishing-the-solution-code) steps

   Note: Currently Graham Charters has privilege to update the image in marketplace, contact him for more information.

1. Do we need to update the solution every time we do the image update?
   * Yes. That's because image versions of [`twas-nd`](https://github.com/WASdev/azure.websphere-traditional.cluster/blob/main/src/main/bicep/config.json#L17) and [`ihs`](https://github.com/WASdev/azure.websphere-traditional.cluster/blob/main/src/main/bicep/config.json#L23) are explicitely referenced in the tWAS solution. Make sure correct image versions are specified in the `config.json` of the solution code.

## Updating and publishing the solution code

Note: **Wait for images to be published before proceeding with this step.** The steps included in this section are also applied to release new features / bug fixes which have no changes to the images.

1. How to update the version of the solution?
   * Increase the [version number](https://github.com/WASdev/azure.websphere-traditional.cluster/blob/main/pom.xml#L23) which is specified in the `pom.xml`
   * Also update the [`twasNdImageVersion`](https://github.com/WASdev/azure.websphere-traditional.cluster/blob/main/src/main/bicep/config.json#L17) and [`ihsImageVersion`](https://github.com/WASdev/azure.websphere-traditional.cluster/blob/main/src/main/bicep/config.json#L23) in the `config.json` (obtained from publish step)
   * Get the PR merged

1. How to run CI/CD?
   * Go to [Actions](https://github.com/WASdev/azure.websphere-traditional.cluster/actions) > Click `integration-test` > Click to expand `Run workflow` > Click `Run workflow` > Refresh the page

1. How to publish the solution in marketplace and who can do it? (**Note: Make sure the images are published before publishing the solution**)
   1. Wait until the CI/CD workflow for `integration-test` successfully completes 
       * Click to open details of the workflow run > Scroll to the bottom of the page
       * Click `azure.websphere-traditional.cluster-<version>-arm-assembly` to download the zip file `azure.websphere-traditional.cluster-<version>-arm-assembly.zip`;
   3. Sign into [Microsoft Partner Center](https://partner.microsoft.com/dashboard/commercial-marketplace/overview)
       * Click to open the offer for the solution (likely `2021-04-08-twas-cluser`) > Click `Plan overview`
       * Click to open the plan > Click `Technical configuration`
       * Specify the increased version number for `Version` (note, the version is in the zip file name)
       * Click `Remove` to remove the previous package file
       * Click `browse your file(s)` to upload the downloaded zip package generated by the CI/CD pipeline before
       * Scroll to the bottom of the page
       * Click `Save draft`
       * Click `Review and publish`
       * In the "Notes for certification" section enter the `integration-test` URL
       * Click `Publish`
       * Wait until solution offer is in `Publisher signoff` (aka "preview") stage and "Go Live" button appears(it could take few hours)
       * Before clicking "Go Live" use the preview link to test the solution
       * <img width="1115" alt="image" src="https://user-images.githubusercontent.com/24283162/153244611-d3623867-61b2-4997-a265-ce0491e1ae8d.png">
       * Run test cases defined in [twas-solution-test-cases.md](twas-solution-test-cases.md). Note: use "preview link" for each test case.
       * Click "Go Live"
       * Wait for remaining steps to complete (may take couple of days)
       * Make sure to delete your test deployments
       * Once the solution is in "Publish" stage, new version is publicly available
       * To verify the version number, launch the solution in Azure portal and hover over "Issue tracker" and it should display the version number. For example, https://aka.ms/azure-twasnd-cluster-issues?version=**1.3.29**

   Note: Currently Graham Charters has privilege to update the solution in marketplace, contact him for more information.

1. Create a [release](https://github.com/WASdev/azure.websphere-traditional.cluster/releases) for this GA code and tag with the pom.xml version number.


## What needs to be cleaned up from test env and how to clean them up?

Azure marketplace is responsible for managing different stages during the offer publishing, just follow its process to make it Go-Live and no additional clean-ups are needed.

## Do we delete/archive previous version of the solution?

Previous versions of the solution are archived. You can find/download them from "Offer > Plan overview > Technical configuration > Previously published packages".

## Create a release and a branch with the GA code (for image and cluster repo)

Probably creating a release/tag for each GA code is good enough.

## Troubleshooting
1. `AADSTS7000215: Invalid client secret provided`: See https://github.com/WASdev/azure.websphere-traditional.cluster/issues/153
