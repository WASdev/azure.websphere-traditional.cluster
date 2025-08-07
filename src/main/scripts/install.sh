#!/bin/sh

#      Copyright (c) Microsoft Corporation.
#      Copyright (c) IBM Corporation. 
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
    # Open ports for deployment manager
    firewall-cmd --zone=public --add-port=9060/tcp --permanent
    firewall-cmd --zone=public --add-port=9043/tcp --permanent
    firewall-cmd --zone=public --add-port=9809/tcp --permanent
    firewall-cmd --zone=public --add-port=7277/tcp --permanent
    firewall-cmd --zone=public --add-port=9402/tcp --permanent
    firewall-cmd --zone=public --add-port=9403/tcp --permanent
    firewall-cmd --zone=public --add-port=9352/tcp --permanent
    firewall-cmd --zone=public --add-port=9632/tcp --permanent
    firewall-cmd --zone=public --add-port=9100/tcp --permanent
    firewall-cmd --zone=public --add-port=9401/tcp --permanent
    firewall-cmd --zone=public --add-port=8879/tcp --permanent
    firewall-cmd --zone=public --add-port=5555/tcp --permanent
    firewall-cmd --zone=public --add-port=7060/tcp --permanent
    firewall-cmd --zone=public --add-port=11005/udp --permanent
    firewall-cmd --zone=public --add-port=11006/tcp --permanent
    firewall-cmd --zone=public --add-port=9420/tcp --permanent
    
    firewall-cmd --reload

    profileName=$1
    hostName=$2
    nodeName=$3
    cellName=$4
    adminUserName=$5
    adminPassword=$6

    echo "$(date): Start to create deployment manager profile."
    ${WAS_ND_INSTALL_DIRECTORY}/bin/manageprofiles.sh -create -profileName ${profileName} -hostName $hostName \
        -templatePath ${WAS_ND_INSTALL_DIRECTORY}/profileTemplates/management -serverType DEPLOYMENT_MANAGER \
        -nodeName ${nodeName} -cellName ${cellName} -enableAdminSecurity true -adminUserName ${adminUserName} -adminPassword ${adminPassword}
    echo "$(date): Deployment manager profile created."
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

create_was_service() {
    serverName=$1
    serviceName=${serverName}
    profileName=$2
    profilePath=${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}
    
    # Configure SELinux so systemctl has access on server start/stop script files 
    semanage fcontext -a -t bin_t "${profilePath}/bin(/.*)?"
    restorecon -r -v ${profilePath}/bin

    # Add service
    ${profilePath}/bin/wasservice.sh -add ${serviceName} -serverName ${serverName} -profilePath ${profilePath}
}

create_cluster() {
    profileName=$1
    dmgrNode=$2
    cellName=$3
    clusterName=$4
    members=$5
    dynamic=$6

    echo "$(date): Check if all nodes are managed."
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
        echo "$(date): All nodes are managed, start to create dynamic cluster."
        cp create-dcluster.py create-dcluster.py.bak
        sed -i "s/\${CLUSTER_NAME}/${clusterName}/g" create-dcluster.py
        sed -i "s/\${NODE_GROUP_NAME}/DefaultNodeGroup/g" create-dcluster.py
        sed -i "s/\${CORE_GROUP_NAME}/DefaultCoreGroup/g" create-dcluster.py
        ${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/wsadmin.sh -lang jython -f create-dcluster.py
    else
        echo "$(date): All nodes are managed, start to create cluster."
        nodes_string=$( IFS=,; echo "${nodes[*]}" )
        cp create-cluster.py create-cluster.py.bak
        sed -i "s/\${CELL_NAME}/${cellName}/g" create-cluster.py
        sed -i "s/\${CLUSTER_NAME}/${clusterName}/g" create-cluster.py
        sed -i "s/\${NODES_STRING}/${nodes_string}/g" create-cluster.py
        ${WAS_ND_INSTALL_DIRECTORY}/profiles/${profileName}/bin/wsadmin.sh -lang jython -f create-cluster.py
    fi

    echo "$(date): Cluster \"${clusterName}\" is successfully created."
}

create_custom_profile() {
    # Open ports for federated application server
    firewall-cmd --zone=public --add-port=9080/tcp --permanent
    firewall-cmd --zone=public --add-port=9443/tcp --permanent
    firewall-cmd --zone=public --add-port=2809/tcp --permanent
    firewall-cmd --zone=public --add-port=9405/tcp --permanent
    firewall-cmd --zone=public --add-port=9406/tcp --permanent
    firewall-cmd --zone=public --add-port=9353/tcp --permanent
    firewall-cmd --zone=public --add-port=9633/tcp --permanent
    firewall-cmd --zone=public --add-port=5558/tcp --permanent
    firewall-cmd --zone=public --add-port=5578/tcp --permanent
    firewall-cmd --zone=public --add-port=9100/tcp --permanent
    firewall-cmd --zone=public --add-port=9404/tcp --permanent
    firewall-cmd --zone=public --add-port=7276/tcp --permanent
    firewall-cmd --zone=public --add-port=7286/tcp --permanent
    firewall-cmd --zone=public --add-port=5060/tcp --permanent
    firewall-cmd --zone=public --add-port=5061/tcp --permanent
    firewall-cmd --zone=public --add-port=8880/tcp --permanent
    firewall-cmd --zone=public --add-port=11003/udp --permanent
    firewall-cmd --zone=public --add-port=11004/tcp --permanent

    # Open ports for node agent server
    firewall-cmd --zone=public --add-port=2810/tcp --permanent
    firewall-cmd --zone=public --add-port=9201/tcp --permanent
    firewall-cmd --zone=public --add-port=9202/tcp --permanent
    firewall-cmd --zone=public --add-port=9354/tcp --permanent
    firewall-cmd --zone=public --add-port=9626/tcp --permanent
    firewall-cmd --zone=public --add-port=9629/tcp --permanent
    firewall-cmd --zone=public --add-port=7272/tcp --permanent
    firewall-cmd --zone=public --add-port=5001/tcp --permanent
    firewall-cmd --zone=public --add-port=5000/tcp --permanent
    firewall-cmd --zone=public --add-port=9900/tcp --permanent
    firewall-cmd --zone=public --add-port=9901/tcp --permanent
    firewall-cmd --zone=public --add-port=8878/tcp --permanent
    firewall-cmd --zone=public --add-port=7061/tcp --permanent
    firewall-cmd --zone=public --add-port=7062/tcp --permanent
    firewall-cmd --zone=public --add-port=11001/udp --permanent
    firewall-cmd --zone=public --add-port=11002/tcp --permanent

    # Open ports for cluster member
    firewall-cmd --zone=public --add-port=9809/tcp --permanent
    firewall-cmd --zone=public --add-port=9402/tcp --permanent
    firewall-cmd --zone=public --add-port=9403/tcp --permanent
    firewall-cmd --zone=public --add-port=9352/tcp --permanent
    firewall-cmd --zone=public --add-port=9632/tcp --permanent
    firewall-cmd --zone=public --add-port=9401/tcp --permanent
    firewall-cmd --zone=public --add-port=11005/udp --permanent
    firewall-cmd --zone=public --add-port=11006/tcp --permanent
    firewall-cmd --zone=public --add-port=8879/tcp --permanent
    firewall-cmd --zone=public --add-port=9060/tcp --permanent
    firewall-cmd --zone=public --add-port=9043/tcp --permanent

    # Open ports for dynamic cluster member
    firewall-cmd --zone=public --add-port=9810/tcp --permanent
    firewall-cmd --zone=public --add-port=9101/tcp --permanent
    firewall-cmd --zone=public --add-port=11007/udp --permanent
    firewall-cmd --zone=public --add-port=11008/tcp --permanent
    firewall-cmd --zone=public --add-port=9061/tcp --permanent
    firewall-cmd --zone=public --add-port=9044/tcp --permanent

    firewall-cmd --reload

    profileName=$1
    hostName=$2
    nodeName=$3
    dmgrHostName=$4
    dmgrPort=$5
    dmgrAdminUserName=$6
    dmgrAdminPassword=$7
    
    echo "$(date): Check if dmgr is ready."
    curl --http0.9 $dmgrHostName:$dmgrPort --output - >/dev/null 2>&1
    rtnCode=$?
    while [ $rtnCode -ne 0 ] && [ $rtnCode -ne 56 ]
    do
        sleep 5
        echo "dmgr is not ready"
        curl --http0.9 $dmgrHostName:$dmgrPort --output - >/dev/null 2>&1
        rtnCode=$?
    done
    sleep 60
    echo "$(date): Dmgr is ready, start to create custom profile."

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
    echo "$(date): Custom profile created."
}

# retry attempt for curl command
retryMaxAttempt=5

copy_jdbc_drivers() {
    jdbcDriverPath=$1
    dbType=$2

    mkdir -p "$jdbcDriverPath"

    if [ $dbType == "db2" ]; then
        find ${WAS_ND_INSTALL_DIRECTORY} -name "db2jcc*.jar" | xargs -I{} cp {} "$jdbcDriverPath"
    elif [ $dbType == "oracle" ]; then
        # Download jdbc drivers
        curl --retry ${retryMaxAttempt} -Lo ${jdbcDriverPath}/ojdbc8.jar https://download.oracle.com/otn-pub/otn_software/jdbc/1916/ojdbc8.jar
        JDBC_DRIVER_CLASS_PATH=$(realpath "$jdbcDriverPath"/ojdbc8.jar)
    elif [ $dbType == "sqlserver" ]; then
        # Download jdbc drivers
        curl --retry ${retryMaxAttempt} -Lo ${jdbcDriverPath}/mssql-jdbc-11.2.1.jre8.jar https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/11.2.1.jre8/mssql-jdbc-11.2.1.jre8.jar
        JDBC_DRIVER_CLASS_PATH=$(realpath "$jdbcDriverPath"/mssql-jdbc-11.2.1.jre8.jar)
    elif [ $dbType == "postgres" ]; then
        # Download jdbc drivers
        curl --retry ${retryMaxAttempt} -Lo ${jdbcDriverPath}/postgresql-42.5.0.jar https://jdbc.postgresql.org/download/postgresql-42.5.0.jar
        JDBC_DRIVER_CLASS_PATH=$(realpath "$jdbcDriverPath"/postgresql-42.5.0.jar)
    fi
}

# Get tWAS installation properties
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
if [ "$7" = True ] && [ "${15}" = True ] && [ "${20}" == "" ]; then 
  echo "Usage:"
  echo "  ./install.sh [dmgr] [adminUserName] [adminPassword] [dmgrHostName] [members] [dynamic] True [dbType] [jdbcDSJNDIName] [dsConnectionString] [databaseUser] [databasePassword] [enablePswlessConnection] [uamiClientId] True [storageAccountName] [storageAccountKey] [fileShareName] [mountpointPath] [storageAccountPrivateIp]"
  exit 1
elif [ "${15}" == "" ]; then 
  echo "Usage:"
  echo "  ./install.sh [dmgr] [adminUserName] [adminPassword] [dmgrHostName] [members] [dynamic] <True|False> [dbType] [jdbcDSJNDIName] [dsConnectionString] [databaseUser] [databasePassword] [enablePswlessConnection] [uamiClientId] False"
  exit 1
fi
dmgr=$1
adminUserName=$2
adminPassword=$3
dmgrHostName=$4
members=$5
dynamic=$6

enableDB=$7
dbType=$8
jdbcDSJNDIName=$9
dsConnectionString=${10}
databaseUser=${11}
databasePassword=${12}
enablePswlessConnection=${13}
uamiClientId=${14}

configureIHS=${15}
storageAccountName=${16}
storageAccountKey=${17}
fileShareName=${18}
mountpointPath=${19}
storageAccountPrivateIp=${20}

# Jdbc driver path/class path
jdbcDriverPath=${WAS_ND_INSTALL_DIRECTORY}/${dbType}/java
JDBC_DRIVER_CLASS_PATH=

# Create cluster by creating deployment manager, node agent & add nodes to be managed
if [ "$dmgr" = True ]; then
    create_dmgr_profile Dmgr001 $(hostname -A) Dmgr001Node Dmgr001NodeCell "$adminUserName" "$adminPassword"
    add_admin_credentials_to_soap_client_props Dmgr001 "$adminUserName" "$adminPassword"
    create_was_service dmgr Dmgr001
    ${WAS_ND_INSTALL_DIRECTORY}/profiles/Dmgr001/bin/startServer.sh dmgr
    create_cluster Dmgr001 Dmgr001Node Dmgr001NodeCell MyCluster $members $dynamic

    # Configure IHS if required
    if [ "$configureIHS" = True ]; then
        ./configure-ihs-on-dmgr.sh Dmgr001 "$adminUserName" "$adminPassword" "$storageAccountName" "$storageAccountKey" "$fileShareName" "$mountpointPath" "$storageAccountPrivateIp"
    fi

    # Configure JDBC provider and data source
    if [ "$enableDB" == "True" ]; then
        copy_jdbc_drivers $jdbcDriverPath $dbType

        jdbcDataSourceName=dataSource-$dbType
        ./create-ds.sh ${WAS_ND_INSTALL_DIRECTORY} Dmgr001 MyCluster "$dbType" "$jdbcDataSourceName" "$jdbcDSJNDIName" "$dsConnectionString" "$databaseUser" "$databasePassword" "$enablePswlessConnection" "$uamiClientId" "$jdbcDriverPath" "$JDBC_DRIVER_CLASS_PATH"

        # Test connection for the created data source
        ${WAS_ND_INSTALL_DIRECTORY}/profiles/Dmgr001/bin/wsadmin.sh -lang jython -c "AdminControl.testConnection(AdminConfig.getid('/DataSource:${jdbcDataSourceName}/'))"
        rtnCode=$?
        if [[ $rtnCode != 0 ]]; then
            echo "$(date): Test data source connection failed with return code ${rtnCode}."
            exit 1
        fi
    fi
else
    create_custom_profile Custom $(hostname -A) $(hostname)Node01 $dmgrHostName.$(hostname -A | cut -d'.' -f2-) 8879 "$adminUserName" "$adminPassword"
    add_admin_credentials_to_soap_client_props Custom "$adminUserName" "$adminPassword"
    create_was_service nodeagent Custom

    # Copy JDBC drivers
    if [ "$enableDB" == "True" ]; then
        copy_jdbc_drivers $jdbcDriverPath $dbType
    fi
fi
