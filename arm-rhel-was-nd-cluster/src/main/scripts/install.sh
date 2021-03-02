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

    /opt/IBM/WebSphere/ND/V9/bin/manageprofiles.sh -create -profileName ${profileName} -hostName $hostName \
        -templatePath /opt/IBM/WebSphere/ND/V9/profileTemplates/management -serverType DEPLOYMENT_MANAGER \
        -nodeName ${nodeName} -cellName ${cellName} -enableAdminSecurity true -adminUserName ${adminUserName} -adminPassword ${adminPassword}
}

add_admin_credentials_to_soap_client_props() {
    profileName=$1
    adminUserName=$2
    adminPassword=$3
    soapClientProps=/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/properties/soap.client.props

    # Add admin credentials
    sed -i "s/com.ibm.SOAP.securityEnabled=false/com.ibm.SOAP.securityEnabled=true/g" "$soapClientProps"
    sed -i "s/com.ibm.SOAP.loginUserid=/com.ibm.SOAP.loginUserid=${adminUserName}/g" "$soapClientProps"
    sed -i "s/com.ibm.SOAP.loginPassword=/com.ibm.SOAP.loginPassword=${adminPassword}/g" "$soapClientProps"

    # Encrypt com.ibm.SOAP.loginPassword
    /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/PropFilePasswordEncoder.sh "$soapClientProps" com.ibm.SOAP.loginPassword
}

create_systemd_service() {
    srvName=$1
    srvDescription=$2
    profileName=$3
    serverName=$4
    srvPath=/etc/systemd/system/${srvName}.service

    # Add systemd unit file
    echo "[Unit]" > "$srvPath"
    echo "Description=${srvDescription}" >> "$srvPath"
    echo "[Service]" >> "$srvPath"
    echo "Type=forking" >> "$srvPath"
    echo "ExecStart=/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/startServer.sh ${serverName}" >> "$srvPath"
    echo "ExecStop=/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/stopServer.sh ${serverName}" >> "$srvPath"
    echo "PIDFile=/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/logs/${serverName}/${serverName}.pid" >> "$srvPath"
    echo "SuccessExitStatus=143 0" >> "$srvPath"
    echo "[Install]" >> "$srvPath"
    echo "WantedBy=default.target" >> "$srvPath"

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

    nodes=( $(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "AdminConfig.list('Node')" \
        | grep -Po "(?<=\/nodes\/)[^|]*(?=|.*)" | grep -v $dmgrNode | sed 's/^/"/;s/$/"/') )
    while [ ${#nodes[@]} -ne $members ]
    do
        sleep 5
        echo "adding more nodes..."
        nodes=( $(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "AdminConfig.list('Node')" \
            | grep -Po "(?<=\/nodes\/)[^|]*(?=|.*)" | grep -v $dmgrNode | sed 's/^/"/;s/$/"/') )
    done
    sleep 60

    if [ "$dynamic" = True ]; then
        echo "all nodes are managed, creating dynamic cluster..."
        cp create-dcluster.py create-dcluster.py.bak
        sed -i "s/\${CLUSTER_NAME}/${clusterName}/g" create-dcluster.py
        sed -i "s/\${NODE_GROUP_NAME}/DefaultNodeGroup/g" create-dcluster.py
        sed -i "s/\${CORE_GROUP_NAME}/DefaultCoreGroup/g" create-dcluster.py
        /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f create-dcluster.py
    else
        echo "all nodes are managed, creating cluster..."
        nodes_string=$( IFS=,; echo "${nodes[*]}" )
        cp create-cluster.py create-cluster.py.bak
        sed -i "s/\${CELL_NAME}/${cellName}/g" create-cluster.py
        sed -i "s/\${CLUSTER_NAME}/${clusterName}/g" create-cluster.py
        sed -i "s/\${NODES_STRING}/${nodes_string}/g" create-cluster.py
        /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f create-cluster.py
    fi

    echo "cluster \"${clusterName}\" is successfully created!"
}

create_data_source() {
    profileName=$1
    clusterName=$2
    db2ServerName=$3
    db2ServerPortNumber=$4
    db2DBName=$5
    db2DBUserName=$6
    db2DBUserPwd=$7
    db2DSJndiName=${8:-jdbc/Sample}
    jdbcDriverPath=/opt/IBM/WebSphere/ND/V9/db2/java

    if [ -z "$db2ServerName" ] || [ -z "$db2ServerPortNumber" ] || [ -z "$db2DBName" ] || [ -z "$db2DBUserName" ] || [ -z "$db2DBUserPwd" ]; then
        echo "quit due to DB2 connectoin info is not provided"
        return 0
    fi

    # Get jython file template & replace placeholder strings with user-input parameters
    cp create-ds.py create-ds.py.bak
    sed -i "s/\${CLUSTER_NAME}/${clusterName}/g" create-ds.py
    sed -i "s#\${DB2UNIVERSAL_JDBC_DRIVER_PATH}#${jdbcDriverPath}#g" create-ds.py
    sed -i "s/\${DB2_DATABASE_USER_NAME}/${db2DBUserName}/g" create-ds.py
    sed -i "s/\${DB2_DATABASE_USER_PASSWORD}/${db2DBUserPwd}/g" create-ds.py
    sed -i "s/\${DB2_DATABASE_NAME}/${db2DBName}/g" create-ds.py
    sed -i "s#\${DB2_DATASOURCE_JNDI_NAME}#${db2DSJndiName}#g" create-ds.py
    sed -i "s/\${DB2_SERVER_NAME}/${db2ServerName}/g" create-ds.py
    sed -i "s/\${PORT_NUMBER}/${db2ServerPortNumber}/g" create-ds.py

    # Create JDBC provider and data source using jython file
    /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f create-ds.py
    sleep 60
    # Restart active nodes which will restart all servers running on the nodes
    /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "AdminNodeManagement.restartActiveNodes()"
    echo "DB2 JDBC provider and data source are successfully created!"
}

enable_hpel() {
    wasProfilePath=/opt/IBM/WebSphere/ND/V9/profiles/$1 #WAS ND profile path
    nodeName=$2 #Node name
    wasServerName=$3 #WAS ND server name
    outLogPath=$4 #Log output path
    logViewerSvcName=$5 #Name of log viewer service

    # Enable HPEL service
    cp enable-hpel.template enable-hpel-${wasServerName}.py
    sed -i "s/\${WAS_SERVER_NAME}/${wasServerName}/g" enable-hpel-${wasServerName}.py
    sed -i "s/\${NODE_NAME}/${nodeName}/g" enable-hpel-${wasServerName}.py
    "$wasProfilePath"/bin/wsadmin.sh -lang jython -f enable-hpel-${wasServerName}.py

# Add systemd unit file for log viewer service
    cat <<EOF > /etc/systemd/system/${logViewerSvcName}.service
[Unit]
Description=IBM WebSphere Application Log Viewer
[Service]
Type=simple
ExecStart=${wasProfilePath}/bin/logViewer.sh -repositoryDir ${wasProfilePath}/logs/${wasServerName} -outLog ${outLogPath} -resumable -resume -format json -monitor
[Install]
WantedBy=default.target
EOF

    # Enable log viewer service
    systemctl daemon-reload
    systemctl enable "$logViewerSvcName"
}

setup_filebeat() {
    # Parameters
    outLogPaths=$1 #Log output paths
    IFS=',' read -r -a array <<< "$outLogPaths"
    cloudId=$2 #Cloud ID of Elasticsearch Service on Elastic Cloud
    cloudAuthUser=$3 #User name of Elasticsearch Service on Elastic Cloud
    cloudAuthPwd=$4 #Password of Elasticsearch Service on Elastic Cloud

    # Install Filebeat
    rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
    cat <<EOF > /etc/yum.repos.d/elastic.repo
[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
    yum install filebeat -y

    # Configure Filebeat
    mv /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak
    fbConfigFilePath=/etc/filebeat/filebeat.yml
    echo "filebeat.inputs:" > "$fbConfigFilePath"
    echo "- type: log" >> "$fbConfigFilePath"
    echo "  paths:" >> "$fbConfigFilePath"
    for outLogPath in "${array[@]}"
    do
        echo "    - ${outLogPath}" >> "$fbConfigFilePath"
    done
    echo "  json.message_key: message" >> "$fbConfigFilePath"
    echo "  json.keys_under_root: true" >> "$fbConfigFilePath"
    echo "  json.add_error_key: true" >> "$fbConfigFilePath"
    echo "processors:" >> "$fbConfigFilePath"
    echo "- add_cloud_metadata: ~" >> "$fbConfigFilePath"
    echo "cloud.id: ${cloudId}" >> "$fbConfigFilePath"
    echo "cloud.auth: ${cloudAuthUser}:${cloudAuthPwd}" >> "$fbConfigFilePath"

    # Enable & start filebeat
    systemctl daemon-reload
    systemctl enable filebeat
    systemctl start filebeat
}

create_custom_profile() {
    profileName=$1
    hostName=$2
    nodeName=$3
    dmgrHostName=$4
    dmgrPort=$5
    dmgrAdminUserName=$6
    dmgrAdminPassword=$7
    
    curl $dmgrHostName:$dmgrPort >/dev/null 2>&1
    while [ $? -ne 0 ]
    do
        sleep 5
        echo "dmgr is not ready"
        curl $dmgrHostName:$dmgrPort >/dev/null 2>&1
    done
    sleep 60
    echo "dmgr is ready to add nodes"

    output=$(/opt/IBM/WebSphere/ND/V9/bin/manageprofiles.sh -create -profileName $profileName -hostName $hostName -nodeName $nodeName \
        -profilePath /opt/IBM/WebSphere/ND/V9/profiles/$profileName -templatePath /opt/IBM/WebSphere/ND/V9/profileTemplates/managed \
        -dmgrHost $dmgrHostName -dmgrPort $dmgrPort -dmgrAdminUserName $dmgrAdminUserName -dmgrAdminPassword $dmgrAdminPassword 2>&1)
    while echo $output | grep -qv "SUCCESS"
    do
        sleep 10
        echo "adding node failed, retry it later..."
        rm -rf /opt/IBM/WebSphere/ND/V9/profiles/$profileName
        output=$(/opt/IBM/WebSphere/ND/V9/bin/manageprofiles.sh -create -profileName $profileName -hostName $hostName -nodeName $nodeName \
            -profilePath /opt/IBM/WebSphere/ND/V9/profiles/$profileName -templatePath /opt/IBM/WebSphere/ND/V9/profileTemplates/managed \
            -dmgrHost $dmgrHostName -dmgrPort $dmgrPort -dmgrAdminUserName $dmgrAdminUserName -dmgrAdminPassword $dmgrAdminPassword 2>&1)
    done
    echo $output
}

copy_db2_drivers() {
    wasRootPath=/opt/IBM/WebSphere/ND/V9
    jdbcDriverPath="$wasRootPath"/db2/java

    mkdir -p "$jdbcDriverPath"
    find "$wasRootPath" -name "db2jcc*.jar" | xargs -I{} cp {} "$jdbcDriverPath"
}

elk_logging_ready_check() {
    cellName=$1
    profileName=$2

    output=$(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f get_custom_property.py ${cellName} enableClusterELKLogging 2>&1)
    while echo $output | grep -qv "enableClusterELKLogging:true"
    do
        sleep 10
        echo "Setup cluster ELK logging is not ready, retry it later..."
        output=$(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f get_custom_property.py ${cellName} enableClusterELKLogging 2>&1)
    done
    echo "Ready to setup cluster ELK logging now"
}

cluster_member_running_state() {
    profileName=$1
    nodeName=$2
    serverName=$3

    output=$(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "mbean=AdminControl.queryNames('type=Server,node=${nodeName},name=${serverName},*');print 'STARTED' if mbean else 'RESTARTING'" 2>&1)
    if echo $output | grep -q "STARTED"; then
	    return 0
    else
        return 1
    fi
}

while getopts "m:c:f:h:r:x:n:t:d:i:s:j:g:o:k:" opt; do
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
        n)
            db2ServerName=$OPTARG #Host name/IP address of IBM DB2 Server
        ;;
        t)
            db2ServerPortNumber=$OPTARG #Server port number of IBM DB2 Server
        ;;
        d)
            db2DBName=$OPTARG #Database name of IBM DB2 Server
        ;;
        i)
            db2DBUserName=$OPTARG #Database user name of IBM DB2 Server
        ;;
        s)
            db2DBUserPwd=$OPTARG #Database user password of IBM DB2 Server
        ;;
        j)
            db2DSJndiName=$OPTARG #Datasource JNDI name
        ;;
        g)
            cloudId=$OPTARG #Cloud ID of Elasticsearch Service on Elastic Cloud
        ;;
        o)
            cloudAuthUser=$OPTARG #User name of Elasticsearch Service on Elastic Cloud
        ;;
        k)
            cloudAuthPwd=$OPTARG #Password of Elasticsearch Service on Elastic Cloud
        ;;
    esac
done

# Turn off firewall
systemctl stop firewalld
systemctl disable firewalld

# Create cluster by creating deployment manager, node agent & add nodes to be managed
if [ "$dmgr" = True ]; then
    create_dmgr_profile Dmgr001 $(hostname) Dmgr001Node Dmgr001NodeCell "$adminUserName" "$adminPassword"
    add_admin_credentials_to_soap_client_props Dmgr001 "$adminUserName" "$adminPassword"
    create_systemd_service was_dmgr "IBM WebSphere Application Server ND Deployment Manager" Dmgr001 dmgr
    /opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/bin/startServer.sh dmgr
    create_cluster Dmgr001 Dmgr001Node Dmgr001NodeCell MyCluster $members $dynamic
    create_data_source Dmgr001 MyCluster "$db2ServerName" "$db2ServerPortNumber" "$db2DBName" "$db2DBUserName" "$db2DBUserPwd" "$db2DSJndiName"
    if [ ! -z "$cloudId" ] && [ ! -z "$cloudAuthUser" ] && [ ! -z "$cloudAuthPwd" ]; then
        enable_hpel Dmgr001 Dmgr001Node dmgr /opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/logs/dmgr/hpelOutput.log was_dmgr_logviewer
        /opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/bin/stopServer.sh dmgr
        /opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/bin/startServer.sh dmgr
        systemctl start was_dmgr_logviewer
        setup_filebeat "/opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/logs/dmgr/hpelOutput*.log" "$cloudId" "$cloudAuthUser" "$cloudAuthPwd"
        /opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/bin/wsadmin.sh -lang jython -f set_custom_property.py Dmgr001NodeCell cloudId "$cloudId"
        /opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/bin/wsadmin.sh -lang jython -f set_custom_property.py Dmgr001NodeCell cloudAuthUser "$cloudAuthUser"
        /opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/bin/wsadmin.sh -lang jython -f set_custom_property.py Dmgr001NodeCell cloudAuthPwd "$cloudAuthPwd"
        /opt/IBM/WebSphere/ND/V9/profiles/Dmgr001/bin/wsadmin.sh -lang jython -f set_custom_property.py Dmgr001NodeCell enableClusterELKLogging true
    fi
else
    create_custom_profile Custom $(hostname) $(hostname)Node01 $dmgrHostName 8879 "$adminUserName" "$adminPassword"
    add_admin_credentials_to_soap_client_props Custom "$adminUserName" "$adminPassword"
    create_systemd_service was_nodeagent "IBM WebSphere Application Server ND Node Agent" Custom nodeagent
    copy_db2_drivers
    if [ ! -z "$cloudId" ] && [ ! -z "$cloudAuthUser" ] && [ ! -z "$cloudAuthPwd" ]; then
        elk_logging_ready_check Dmgr001NodeCell Custom
        
        cluster_member_running_state Custom $(hostname)Node01 MyCluster_$(hostname)Node01
        running=$?
        if [ $running -ne 0 ]; then
	        /opt/IBM/WebSphere/ND/V9/profiles/Custom/bin/startServer.sh MyCluster_$(hostname)Node01
        fi

        enable_hpel Custom $(hostname)Node01 nodeagent /opt/IBM/WebSphere/ND/V9/profiles/Custom/logs/nodeagent/hpelOutput.log was_na_logviewer
        enable_hpel Custom $(hostname)Node01 MyCluster_$(hostname)Node01 /opt/IBM/WebSphere/ND/V9/profiles/Custom/logs/MyCluster_$(hostname)Node01/hpelOutput.log was_cm_logviewer
        
        /opt/IBM/WebSphere/ND/V9/profiles/Custom/bin/wsadmin.sh -lang jython -c "na=AdminControl.queryNames('type=NodeAgent,node=$(hostname)Node01,*');AdminControl.invoke(na,'restart','true true')"
        cluster_member_running_state Custom $(hostname)Node01 MyCluster_$(hostname)Node01
        while [ $? -ne 0 ]
        do
            echo "Restarting node agent & cluster member..."
            cluster_member_running_state Custom $(hostname)Node01 MyCluster_$(hostname)Node01
        done
        echo "Node agent & cluster member are both restarted now"

        systemctl start was_na_logviewer
        systemctl start was_cm_logviewer

        if [ $running -ne 0 ]; then
            /opt/IBM/WebSphere/ND/V9/profiles/Custom/bin/stopServer.sh MyCluster_$(hostname)Node01
        fi

        setup_filebeat "/opt/IBM/WebSphere/ND/V9/profiles/Custom/logs/nodeagent/hpelOutput*.log,/opt/IBM/WebSphere/ND/V9/profiles/Custom/logs/MyCluster_$(hostname)Node01/hpelOutput*.log" "$cloudId" "$cloudAuthUser" "$cloudAuthPwd"
    fi
fi
