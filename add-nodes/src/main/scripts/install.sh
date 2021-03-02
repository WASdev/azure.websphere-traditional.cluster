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

add_node() {
    profileName=$1
    hostName=$2
    nodeName=$3
    userName=$4
    password=$5    
    dmgrHostName=$6
    dmgrPort=${7:-8879}
    nodeGroupName=${8:-DefaultNodeGroup}
    coreGroupName=${9:-DefaultCoreGroup}
    
    curl $dmgrHostName:$dmgrPort >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "dmgr is not available, exiting now..."
        exit 1
    fi
    echo "dmgr is ready to add nodes"

    /opt/IBM/WebSphere/ND/V9/bin/manageprofiles.sh -create -profileName $profileName -hostName $hostName -nodeName $nodeName \
        -profilePath /opt/IBM/WebSphere/ND/V9/profiles/$profileName -templatePath /opt/IBM/WebSphere/ND/V9/profileTemplates/managed
    output=$(/opt/IBM/WebSphere/ND/V9/bin/addNode.sh $dmgrHostName $dmgrPort -username $userName -password $password \
        -nodegroupname "$nodeGroupName" -coregroupname "$coreGroupName" -profileName $profileName 2>&1)
    while echo $output | grep -qv "has been successfully federated"
    do
        sleep 10
        echo "adding node failed, retry it later..."
        output=$(/opt/IBM/WebSphere/ND/V9/bin/addNode.sh $dmgrHostName $dmgrPort -username $userName -password $password \
            -nodegroupname "$nodeGroupName" -coregroupname "$coreGroupName" -profileName $profileName 2>&1)
    done
    echo $output
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

copy_db2_drivers() {
    wasRootPath=/opt/IBM/WebSphere/ND/V9
    jdbcDriverPath="$wasRootPath"/db2/java

    mkdir -p "$jdbcDriverPath"
    find "$wasRootPath" -name "db2jcc*.jar" | xargs -I{} cp {} "$jdbcDriverPath"
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

add_to_cluster() {
    profileName=$1
    nodeName=$2
    clusterName=${3:-MyCluster}
    clusterMemberName=${clusterName}_${nodeName}

    # Validation check
    dynamic=0
    output=$(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "AdminConfig.getid('/DynamicCluster:${clusterName}')" 2>&1)
    if echo $output | grep -q "/dynamicclusters/${clusterName}|"; then
        dynamic=1
    fi

    output=$(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "AdminConfig.getid('/ServerCluster:${clusterName}')" 2>&1)
    if echo $output | grep -qv "/clusters/${clusterName}|"; then
        echo "${clusterName} is not a valid cluster, quit"
        exit 1
    fi

    if [ $dynamic -eq 0 ]; then
        # Add node to cluster
        cp add-to-cluster.py add-to-cluster.py.bak
        sed -i "s/\${NODE_NAME}/${nodeName}/g" add-to-cluster.py
        sed -i "s/\${CLUSTER_NAME}/${clusterName}/g" add-to-cluster.py
        sed -i "s/\${CLUSTER_MEMBER_NAME}/${clusterMemberName}/g" add-to-cluster.py
        /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f add-to-cluster.py
    fi

    cellName=$(echo $output | grep -Po "(?<=cells\/)[^\/]*(?=\/.*)")
    cloudId=$(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f get_custom_property.py ${cellName} cloudId 2>&1 | grep -Po "(?<=\[cloudId\:)[^\]]*(?=\].*)")
    cloudAuthUser=$(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f get_custom_property.py ${cellName} cloudAuthUser 2>&1 | grep -Po "(?<=\[cloudAuthUser\:)[^\]]*(?=\].*)")
    cloudAuthPwd=$(/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -f get_custom_property.py ${cellName} cloudAuthPwd 2>&1 | grep -Po "(?<=\[cloudAuthPwd\:)[^\]]*(?=\].*)")
    if { [ "$cloudId" != None ] && [ "$cloudAuthUser" != None ] && [ "$cloudAuthPwd" != None ]; } || [ "$dynamic" -eq 0 ]; then
        if [ "$cloudId" != None ] && [ "$cloudAuthUser" != None ] && [ "$cloudAuthPwd" != None ]; then
            enable_hpel $profileName $nodeName nodeagent /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/logs/nodeagent/hpelOutput.log was_na_logviewer
            enable_hpel $profileName $nodeName $clusterMemberName /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/logs/${clusterMemberName}/hpelOutput.log was_cm_logviewer
        fi

        # Start cluster member and then restart all servers running on cluster member node
        /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/startServer.sh ${clusterMemberName}
        /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/wsadmin.sh -lang jython -c "na=AdminControl.queryNames('type=NodeAgent,node=${nodeName},*');AdminControl.invoke(na,'restart','true true')"
    
        if [ "$cloudId" != None ] && [ "$cloudAuthUser" != None ] && [ "$cloudAuthPwd" != None ]; then
            cluster_member_running_state $profileName $nodeName $clusterMemberName
            while [ $? -ne 0 ]
            do
                echo "Restarting node agent & cluster member..."
                cluster_member_running_state $profileName $nodeName $clusterMemberName
            done
            echo "Node agent & cluster member are both restarted now"

            systemctl start was_na_logviewer
            systemctl start was_cm_logviewer
            setup_filebeat "/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/logs/nodeagent/hpelOutput*.log,/opt/IBM/WebSphere/ND/V9/profiles/${profileName}/logs/${clusterMemberName}/hpelOutput*.log" "$cloudId" "$cloudAuthUser" "$cloudAuthPwd"
            
            if [ $dynamic -eq 1 ]; then
                /opt/IBM/WebSphere/ND/V9/profiles/${profileName}/bin/stopServer.sh $clusterMemberName
            fi            
        fi
    fi
    
    echo "Node ${nodeName} is successfully added to cluster ${clusterName}"
}

while getopts "m:c:s:d:r:h:o:" opt; do
    case $opt in
        m)
            adminUserName=$OPTARG #User id for admimistrating WebSphere Admin Console
        ;;
        c)
            adminPassword=$OPTARG #Password for administrating WebSphere Admin Console
        ;;
        s)
            clusterName=$OPTARG #Name of the existing cluster
        ;;
        d)
            nodeGroupName=$OPTARG #Name of the existing node group created in deployment manager server
        ;;
        r)
            coreGroupName=$OPTARG #Name of the existing core group created in deployment manager server
        ;;
        h)
            dmgrHostName=$OPTARG #Host name of the existing deployment manager server
        ;;
        o)
            dmgrPort=$OPTARG #Port number of the existing deployment manager server
        ;;
    esac
done

# Turn off firewall
systemctl stop firewalld
systemctl disable firewalld

# Add nodes to existing cluster
add_node Custom $(hostname) $(hostname)Node01 "$adminUserName" "$adminPassword" "$dmgrHostName" "$dmgrPort" "$nodeGroupName" "$coreGroupName"
add_admin_credentials_to_soap_client_props Custom "$adminUserName" "$adminPassword"
create_systemd_service was_nodeagent "IBM WebSphere Application Server ND Node Agent" Custom nodeagent
copy_db2_drivers
add_to_cluster Custom $(hostname)Node01 "$clusterName"
