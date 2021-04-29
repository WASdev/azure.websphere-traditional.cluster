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

create_dmgr_profile() {
    profileName=$1
    hostName=$2
    nodeName=$3
    cellName=$4
    adminUserName=$5
    adminPassword=$6

    ${WAS_ND_INSTALL_DIRECTORY}/bin/manageprofiles.sh -create -profileName ${profileName} -hostName $hostName \
        -templatePath ${WAS_ND_INSTALL_DIRECTORY}/profileTemplates/management -serverType DEPLOYMENT_MANAGER \
        -nodeName ${nodeName} -cellName ${cellName} -enableAdminSecurity true -adminUserName ${adminUserName} -adminPassword ${adminPassword}
}

add_admin_credentials_to_soap_client_props() {
    profileName=$1
    adminUserName=$2
    adminPassword=$3
    soapClientProps=${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/properties/soap.client.props

    # Add admin credentials
    sed -i "s/com.ibm.SOAP.securityEnabled=false/com.ibm.SOAP.securityEnabled=true/g" "$soapClientProps"
    sed -i "s/com.ibm.SOAP.loginUserid=/com.ibm.SOAP.loginUserid=${adminUserName}/g" "$soapClientProps"
    sed -i "s/com.ibm.SOAP.loginPassword=/com.ibm.SOAP.loginPassword=${adminPassword}/g" "$soapClientProps"

    # Encrypt com.ibm.SOAP.loginPassword
    ${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/PropFilePasswordEncoder.sh "$soapClientProps" com.ibm.SOAP.loginPassword
}

create_systemd_service() {
    srvName=$1
    srvDescription=$2
    profileName=$3
    serverName=$4

    # Add systemd unit file
    cat <<EOF > /etc/systemd/system/${srvName}.service
[Unit]
Description=${srvDescription}
RequiresMountsFor=/datadrive
[Service]
Type=forking
ExecStart=/bin/sh -c "${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/startServer.sh ${serverName}"
ExecStop=/bin/sh -c "${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/stopServer.sh ${serverName}"
PIDFile=${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/logs/${serverName}/${serverName}.pid
SuccessExitStatus=143 0
TimeoutStartSec=900
[Install]
WantedBy=default.target
EOF

    # Enable service
    systemctl daemon-reload
    systemctl enable "$srvName"
}

create_cluster() {
    profileName=$1
    dmgrNode=$2
    cellName=$3
    clusterName=$4
    members=$5
    dynamic=$6

    nodes=( $(${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "AdminConfig.list('Node')" \
        | grep -Po "(?<=\/nodes\/)[^|]*(?=|.*)" | grep -v $dmgrNode | sed 's/^/"/;s/$/"/') )
    while [ ${#nodes[@]} -ne $members ]
    do
        sleep 5
        echo "adding more nodes..."
        nodes=( $(${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "AdminConfig.list('Node')" \
            | grep -Po "(?<=\/nodes\/)[^|]*(?=|.*)" | grep -v $dmgrNode | sed 's/^/"/;s/$/"/') )
    done
    sleep 60

    if [ "$dynamic" = True ]; then
        echo "all nodes are managed, creating dynamic cluster..."
        cp create-dcluster.py create-dcluster.py.bak
        sed -i "s/\${CLUSTER_NAME}/${clusterName}/g" create-dcluster.py
        sed -i "s/\${NODE_GROUP_NAME}/DefaultNodeGroup/g" create-dcluster.py
        sed -i "s/\${CORE_GROUP_NAME}/DefaultCoreGroup/g" create-dcluster.py
        ${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/wsadmin.sh -lang jython -f create-dcluster.py
    else
        echo "all nodes are managed, creating cluster..."
        nodes_string=$( IFS=,; echo "${nodes[*]}" )
        cp create-cluster.py create-cluster.py.bak
        sed -i "s/\${CELL_NAME}/${cellName}/g" create-cluster.py
        sed -i "s/\${CLUSTER_NAME}/${clusterName}/g" create-cluster.py
        sed -i "s/\${NODES_STRING}/${nodes_string}/g" create-cluster.py
        ${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/wsadmin.sh -lang jython -f create-cluster.py
    fi

    echo "cluster \"${clusterName}\" is successfully created!"
}

create_custom_profile() {
    profileName=$1
    hostName=$2
    nodeName=$3
    dmgrHostName=$4
    dmgrPort=$5
    dmgrAdminUserName=$6
    dmgrAdminPassword=$7
    
    curl $dmgrHostName:$dmgrPort --output - >/dev/null 2>&1
    while [ $? -ne 56 ]
    do
        sleep 5
        echo "dmgr is not ready"
        curl $dmgrHostName:$dmgrPort --output - >/dev/null 2>&1
    done
    sleep 60
    echo "dmgr is ready to add nodes"

    output=$(${WAS_ND_INSTALL_DIRECTORY}/bin/manageprofiles.sh -create -profileName $profileName -hostName $hostName -nodeName $nodeName \
        -profilePath ${WAS_ND_INSTALL_DIRECTORY}/profiles/$profileName -templatePath ${WAS_ND_INSTALL_DIRECTORY}/profileTemplates/managed \
        -dmgrHost $dmgrHostName -dmgrPort $dmgrPort -dmgrAdminUserName $dmgrAdminUserName -dmgrAdminPassword $dmgrAdminPassword 2>&1)
    while echo $output | grep -qv "SUCCESS"
    do
        sleep 10
        echo "adding node failed, retry it later..."
        rm -rf ${WAS_ND_INSTALL_DIRECTORY}/profiles/$profileName
        output=$(${WAS_ND_INSTALL_DIRECTORY}/bin/manageprofiles.sh -create -profileName $profileName -hostName $hostName -nodeName $nodeName \
            -profilePath ${WAS_ND_INSTALL_DIRECTORY}/profiles/$profileName -templatePath ${WAS_ND_INSTALL_DIRECTORY}/profileTemplates/managed \
            -dmgrHost $dmgrHostName -dmgrPort $dmgrPort -dmgrAdminUserName $dmgrAdminUserName -dmgrAdminPassword $dmgrAdminPassword 2>&1)
    done
    echo $output
}

while getopts "m:c:f:h:r:x:" opt; do
    case $opt in
        m)
            adminUserName=$OPTARG #User id for admimistrating WebSphere Admin Console
        ;;
        c)
            adminPassword=$OPTARG #Password for administrating WebSphere Admin Console
        ;;
        f)
            dmgr=$OPTARG #Flag indicating whether to install deployment manager
        ;;
        h)
            dmgrHostName=$OPTARG #Host name of deployment manager server
        ;;
        r)
            members=$OPTARG #Number of cluster members
        ;;
        x)
            dynamic=$OPTARG #Flag indicating whether to create a dynamic cluster or not
        ;;
    esac
done

# Check whether the user is entitled or not
while [ ! -f "/var/log/cloud-init-was.log" ]
do
    sleep 5
done

isDone=false
while [ $isDone = false ]
do
    result=`(tail -n1) </var/log/cloud-init-was.log`
    if [[ $result = Unentitled ]] || [[ $result = Entitled ]]; then
        isDone=true
    else
        sleep 5
    fi
done
echo "The input IBMid account is ${result}."

# Remove cloud-init artifacts and logs
cloud-init clean --logs

# Terminate the process for the un-entitled user
if [ ${result} = Unentitled ]; then
    exit 1
fi

# Update applications installed on the system
yum update -y

# Turn off firewall
systemctl stop firewalld
systemctl disable firewalld

# Get tWAS installation properties
source /datadrive/virtualimage.properties

# Create cluster by creating deployment manager, node agent & add nodes to be managed
if [ "$dmgr" = True ]; then
    create_dmgr_profile Dmgr001 $(hostname) Dmgr001Node Dmgr001NodeCell "$adminUserName" "$adminPassword"
    add_admin_credentials_to_soap_client_props Dmgr001 "$adminUserName" "$adminPassword"
    create_systemd_service was_dmgr "IBM WebSphere Application Server ND Deployment Manager" Dmgr001 dmgr
    ${WAS_ND_INSTALL_DIRECTORY}/profiles/Dmgr001/bin/startServer.sh dmgr
    create_cluster Dmgr001 Dmgr001Node Dmgr001NodeCell MyCluster $members $dynamic
else
    create_custom_profile Custom $(hostname) $(hostname)Node01 $dmgrHostName 8879 "$adminUserName" "$adminPassword"
    add_admin_credentials_to_soap_client_props Custom "$adminUserName" "$adminPassword"
    create_systemd_service was_nodeagent "IBM WebSphere Application Server ND Node Agent" Custom nodeagent
fi
