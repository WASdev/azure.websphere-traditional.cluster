#!/bin/sh

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

# Check required parameters
if [ "$7" == "" ]; then 
  echo "Usage:"
  echo "  ./configure-ihs-on-dmgr.sh [profile] [wasUser] [wasPassword] [storageAccountName] [storageAccountKey] [fileShareName] [mountpointPath]"
  exit 1
fi
profile=$1
wasUser=$2
wasPassword=$3
storageAccountName=$4
storageAccountKey=$5
fileShareName=$6
mountpointPath=$7

source /datadrive/virtualimage.properties

# Mount Azure File Share system
mkdir -p $mountpointPath
mkdir /etc/smbcredentials
echo "username=$storageAccountName" > /etc/smbcredentials/${storageAccountName}.cred
echo "password=$storageAccountKey" >> /etc/smbcredentials/${storageAccountName}.cred
chmod 600 /etc/smbcredentials/${storageAccountName}.cred
echo "//${storageAccountName}.file.core.windows.net/${fileShareName} $mountpointPath cifs nofail,vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab

yum install cifs-utils -y
mount -t cifs //${storageAccountName}.file.core.windows.net/${fileShareName} $mountpointPath -o vers=2.1,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino
if [[ $? != 0 ]]; then
  echo "Failed to mount //${storageAccountName}.file.core.windows.net/${fileShareName} $mountpointPath"
  exit 1
fi

# Move the IHS confguration script from Azure File Share system to $WAS_ND_INSTALL_DIRECTORY/bin
while [ ! -f "$mountpointPath/configurewebserver1.sh" ]
do
  echo "$mountpointPath/configurewebserver1.sh is not accessible"
  sleep 5
done
mv $mountpointPath/configurewebserver1.sh $WAS_ND_INSTALL_DIRECTORY/bin
if [[ $? != 0 ]]; then
  echo "Failed to move $mountpointPath/configurewebserver1.sh to $WAS_ND_INSTALL_DIRECTORY/bin"
  exit 1
fi

# Get node name of IHS server
read -r -a cmds <<<`(tail -n1) <$WAS_ND_INSTALL_DIRECTORY/bin/configurewebserver1.sh`
nodeName=${cmds[14]}

echo "Configure IHS on the DMgr"
$WAS_ND_INSTALL_DIRECTORY/bin/configurewebserver1.sh -profileName $profile -user $wasUser -password $wasPassword >/dev/null 2>&1
rm -rf $WAS_ND_INSTALL_DIRECTORY/bin/configurewebserver1.sh

# Configure intelligent management for IHS
$WAS_ND_INSTALL_DIRECTORY/bin/wsadmin.sh -f configure-im.py $nodeName webserver1

# Generate, propagate plugin-cfg.xml and restart IHS
mv pluginutil.sh $WAS_ND_INSTALL_DIRECTORY/bin
$WAS_ND_INSTALL_DIRECTORY/bin/pluginutil.sh generate webserver1 $nodeName
$WAS_ND_INSTALL_DIRECTORY/bin/pluginutil.sh propagate webserver1 $nodeName
$WAS_ND_INSTALL_DIRECTORY/bin/pluginutil.sh propagateKeyring webserver1 $nodeName
$WAS_ND_INSTALL_DIRECTORY/bin/pluginutil.sh restart webserver1 $nodeName