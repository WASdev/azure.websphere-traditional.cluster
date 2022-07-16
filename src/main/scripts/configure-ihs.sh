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

create_systemd_service() {
  srvName=$1
  srvDescription=$2
  serverName=$3

  # Add systemd unit file
  cat <<EOF > /etc/systemd/system/${srvName}.service
[Unit]
Description=${srvDescription}
RequiresMountsFor=/datadrive
After=network.target
[Service]
Type=forking
ExecStart=/bin/sh -c "${IHS_INSTALL_DIRECTORY}/bin/${serverName} start"
ExecStop=/bin/sh -c "${IHS_INSTALL_DIRECTORY}/bin/${serverName} stop"
SuccessExitStatus=0
TimeoutStartSec=900
[Install]
WantedBy=default.target
EOF

  # Enable service
  systemctl daemon-reload
  systemctl enable "$srvName"
}

# Get IHS installation properties
source /datadrive/virtualimage.properties

# Check whether the user is entitled or not
while [ ! -f "$WAS_LOG_PATH" ]
do
    sleep 5
done

isDone=false
while [ $isDone = false ]
do
    result=`(tail -n1) <$WAS_LOG_PATH`
    if [[ $result = $ENTITLED ]] || [[ $result = $UNENTITLED ]] || [[ $result = $UNDEFINED ]] || [[ $result = $EVALUATION ]]; then
        isDone=true
    else
        sleep 5
    fi
done

# Remove cloud-init artifacts and logs
cloud-init clean --logs

# Terminate the process for the un-entitled or undefined user
if [ ${result} != $ENTITLED ] && [ ${result} != $EVALUATION ]; then
    if [ ${result} = $UNENTITLED ]; then
        echo "The provided IBMid does not have entitlement to install WebSphere Application Server. Please contact the primary or secondary contacts for your IBM Passport Advantage site to grant you access or follow steps at IBM eCustomer Care (https://ibm.biz/IBMidEntitlement) for further assistance."
    else
        echo "No WebSphere Application Server installation packages were found. This is likely due to a temporary issue with the installation repository. Try again and open an IBM Support issue if the problem persists."
    fi
    exit 1
fi

# Check required parameters
if [ "$9" == "" ]; then 
  echo "Usage:"
  echo "  ./configure-ihs.sh [dmgrHostname] [ihsUnixUsername] [ihsAdminUsername] [ihsAdminPassword] [storageAccountName] [storageAccountKey] [fileShareName] [mountpointPath] [storageAccountPrivateIp]"
  exit 1
fi
dmgrHostname=$1
ihsUnixUsername=$2
ihsAdminUsername=$3
ihsAdminPassword=$4
storageAccountName=$5
storageAccountKey=$6
fileShareName=$7
mountpointPath=$8
storageAccountPrivateIp=$9

echo "$(date): Start to configure IHS."

# Open ports
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=8008/tcp --permanent
firewall-cmd --reload

hostname=`hostname`
responseFile="pct.response.txt"

# Create response file
echo "configType=remote" > $responseFile
echo "enableAdminServerSupport=true" >> $responseFile
echo "enableUserAndPass=true" >> $responseFile
echo "enableWinService=false" >> $responseFile
echo "ihsAdminCreateUserAndGroup=true" >> $responseFile
echo "ihsadminPort=8008" >> $responseFile
echo "ihsAdminUnixUserID=$ihsUnixUsername" >> $responseFile
echo "ihsAdminUnixUserGroup=$ihsUnixUsername" >> $responseFile
echo "ihsAdminUserID=$ihsAdminUsername" >> $responseFile
echo "ihsAdminPassword=$ihsAdminPassword" >> $responseFile
echo "mapWebServerToApplications=true" >> $responseFile
echo "wasMachineHostName=$dmgrHostname" >> $responseFile
echo "webServerConfigFile1=$IHS_INSTALL_DIRECTORY/conf/httpd.conf" >> $responseFile
echo "webServerDefinition=webserver1" >> $responseFile
echo "webServerHostName=$hostname" >> $responseFile
echo "webServerInstallArch=64" >> $responseFile
echo "webServerPortNumber=80" >> $responseFile
echo "webServerSelected=ihs" >> $responseFile
echo "webServerType=IHS" >> $responseFile

# Configure IHS using WCT
$WCT_INSTALL_DIRECTORY/WCT/wctcmd.sh -tool pct -importDefinitionLocation -defLocPathname $PLUGIN_INSTALL_DIRECTORY -defLocName WS1 -response $responseFile
rm -rf $responseFile

# Start IHS admin server
$IHS_INSTALL_DIRECTORY/bin/adminctl start

# Create systemd services to automatically starting IHS admin server when system is rebooted
create_systemd_service ihs_web_server "IBM HTTP Server" apachectl
create_systemd_service ihs_admin_server "IBM HTTP Server admin server" adminctl

# Mount Azure File Share system
mkdir -p $mountpointPath
mkdir /etc/smbcredentials
echo "username=$storageAccountName" > /etc/smbcredentials/${storageAccountName}.cred
echo "password=$storageAccountKey" >> /etc/smbcredentials/${storageAccountName}.cred
chmod 600 /etc/smbcredentials/${storageAccountName}.cred
echo "//${storageAccountPrivateIp}/${fileShareName} $mountpointPath cifs nofail,credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino" >> /etc/fstab

mount -t cifs //${storageAccountPrivateIp}/${fileShareName} $mountpointPath -o credentials=/etc/smbcredentials/${storageAccountName}.cred,dir_mode=0777,file_mode=0777,serverino
if [[ $? != 0 ]]; then
  echo "$(date): Failed to mount //${storageAccountPrivateIp}/${fileShareName} $mountpointPath."
  exit 1
fi

# Move the IHS confguration script to Azure File Share system
mv $PLUGIN_INSTALL_DIRECTORY/bin/configurewebserver1.sh $mountpointPath
if [[ $? != 0 ]]; then
  echo "$(date): Failed to move $PLUGIN_INSTALL_DIRECTORY/bin/configurewebserver1.sh to $mountpointPath."
  exit 1
fi

echo "$(date): Complete to configure IHS."
