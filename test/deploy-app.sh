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

# Get tWAS installation properties
source /datadrive/virtualimage.properties

# Parameters and variables
appPackageLocation=$1
appName=$2
loadBalancer=$3
cellName=Dmgr001NodeCell
clusterName=MyCluster
dmgrNodeName=Dmgr001Node

# Prepare script for app deployment
if [[ $loadBalancer == "ihs" ]]; then
    ihsNodeName=$(hostname | sed -e "s/dmgr/ihs/g")-node
    ihsServerName=webserver1
    nodes=( $(${WAS_ND_INSTALL_DIRECTORY}/profiles/Dmgr001/bin/wsadmin.sh -lang jython -c "AdminConfig.list('Node')" \
            | grep -Po "(?<=\/nodes\/)[^|]*(?=|.*)" | grep -v ${dmgrNodeName} | grep -v ${ihsNodeName} | sed 's/^/"/;s/$/"/') )
    deployTarget=WebSphere:cell=${cellName},cluster=${clusterName}+WebSphere:cell=${cellName},node=${ihsNodeName},server=${ihsServerName}
else
    nodes=( $(${WAS_ND_INSTALL_DIRECTORY}/profiles/Dmgr001/bin/wsadmin.sh -lang jython -c "AdminConfig.list('Node')" \
            | grep -Po "(?<=\/nodes\/)[^|]*(?=|.*)" | grep -v ${dmgrNodeName} | sed 's/^/"/;s/$/"/') )
    deployTarget=WebSphere:cell=${cellName},cluster=${clusterName}
fi
nodesString=$( IFS=,; echo "${nodes[*]}" )
deployAppTemplate=deploy-app.py.template
deployAppScript=deploy-app.py
cp $deployAppTemplate $deployAppScript

sed -i "s#\${APP_PACKAGE_LOCATION}#${appPackageLocation}#g" $deployAppScript
sed -i "s/\${APP_NAME}/${appName}/g" $deployAppScript
sed -i "s/\${DEPLOY_TARGET}/${deployTarget}/g" $deployAppScript
sed -i "s/\${NODES_STRING}/${nodesString}/g" $deployAppScript
sed -i "s/\${CELL_NAME}/${cellName}/g" $deployAppScript

# Install and start the app
${WAS_ND_INSTALL_DIRECTORY}/profiles/Dmgr001/bin/wsadmin.sh -lang jython -f $deployAppScript
