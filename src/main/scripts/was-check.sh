#!/bin/bash

#      Copyright (c) Microsoft Corporation.
# 
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
# 
#           http://www.apache.org/licenses/LICENSE-2.0
# 
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Define const variables for IM installation
WAS_ND_VERSION_ENTITLED=ND.v90_9.0.5007
NO_PACKAGES_FOUND="No packages were found"
IM_INSTALL_KIT=agent.installer.linux.gtk.x86_64.zip
IM_INSTALL_KIT_URL=https://public.dhe.ibm.com/ibmdl/export/pub/software/im/zips/${IM_INSTALL_KIT}
IM_INSTALL_DIRECTORY=IBM/InstallationManager/V1.9
logFile=deployment.log

echo "$(date): Start to install IBM Installation Manager." > $logFile

# Create installation directories
mkdir -p ${IM_INSTALL_DIRECTORY}

# Install IBM Installation Manager
wget -O "$IM_INSTALL_KIT" "$IM_INSTALL_KIT_URL" -q
mkdir im_installer
unzip -q "$IM_INSTALL_KIT" -d im_installer
./im_installer/userinstc -log log_file -acceptLicense -installationDirectory ${IM_INSTALL_DIRECTORY}

echo "$(date): IBM Installation Manager installed, start to check entitlement." >> $logFile

# Save credentials to a secure storage file
${IM_INSTALL_DIRECTORY}/eclipse/tools/imutilsc saveCredential -secureStorageFile storage_file \
    -userName "$IBM_USER_ID" -userPassword "$IBM_USER_PWD" -passportAdvantage

# Check whether IBMid is entitled or not
if [ $? -ne 0 ]; then
    echo "Cannot connect to Passport Advantage while saving the credential to the secure storage file." >> $logFile
fi

result=0
output=$(${IM_INSTALL_DIRECTORY}/eclipse/tools/imcl listAvailablePackages -cPA -secureStorageFile storage_file)
if [ echo $output | grep -q "$WAS_ND_VERSION_ENTITLED" ]; then
    echo "Entitled" >> $logFile
else
    result=1
    if [ echo $output | grep -q "$NO_PACKAGES_FOUND" ]; then
        echo "Undefined" >> $logFile
        echo "No WebSphere Application Server installation packages were found. This is likely due to a temporary issue with the installation repository. Try again and open an IBM Support issue if the problem persists."
    else
        echo "Unentitled" >> $logFile
        echo "The provided IBM ID does not have entitlement to install WebSphere Application Server. Please contact the primary or secondary contacts for your IBM Passport Advantage site to grant you access or follow steps at IBM eCustomer Care (https://ibm.biz/IBMidEntitlement) for further assistance."
    fi
fi

# Remove temporary files
rm -rf storage_file && rm -rf log_file

echo "$(date): Entitlement check completed." >> $logFile
[ $result -eq 1 ] && exit 1
