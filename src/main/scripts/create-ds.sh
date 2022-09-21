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

# Parameters
wasRootPath=$1                                      # Root path of WebSphere
wasProfileName=$2                                   # WAS profile name
wasClusterName=$3                                   # WAS cluster name
databaseType=$4                                     # Supported database types: db2
jdbcDataSourceName=$5                               # JDBC Datasource name
jdbcDataSourceJNDIName=$(echo "${6}" | base64 -d)   # JDBC Datasource JNDI name
dsConnectionURL=$(echo "${7}" | base64 -d)          # JDBC Datasource connection String
dbUser=$(echo "${8}" | base64 -d)                   # Database username
dbPassword=$(echo "${9}" | base64 -d)               # Database user password
jdbcDriverPath=${10}                                # JDBC driver path

echo "$(date): Start to create JDBC provider and data source."

# Copy data source creation template per database type
createDsTemplate=create-ds-${databaseType}.py.template
createDsScript=create-ds-${databaseType}.py
cp $createDsTemplate $createDsScript

if [ $databaseType == "db2" ]; then
    regex="^jdbc:db2://([^/]+):([0-9]+)/([[:alnum:]_-]+)"
    if [[ $dsConnectionURL =~ $regex ]]; then 
        db2ServerName="${BASH_REMATCH[1]}"
        db2ServerPortNumber="${BASH_REMATCH[2]}"
        db2DBName="${BASH_REMATCH[3]}"
    else
        echo "$dsConnectionURL doesn't match the required format of DB2 data source connection string."
        exit 1
    fi

    # Replace placeholder strings with user-input parameters
    sed -i "s/\${CLUSTER_NAME}/${wasClusterName}/g" $createDsScript
    sed -i "s#\${DB2UNIVERSAL_JDBC_DRIVER_PATH}#${jdbcDriverPath}#g" $createDsScript
    sed -i "s/\${DB2_DATABASE_USER_NAME}/${dbUser}/g" $createDsScript
    sed -i "s/\${DB2_DATABASE_USER_PASSWORD}/${dbPassword}/g" $createDsScript
    sed -i "s/\${DB2_DATABASE_NAME}/${db2DBName}/g" $createDsScript
    sed -i "s/\${DB2_DATASOURCE_NAME}/${jdbcDataSourceName}/g" $createDsScript
    sed -i "s#\${DB2_DATASOURCE_JNDI_NAME}#${jdbcDataSourceJNDIName}#g" $createDsScript
    sed -i "s/\${DB2_SERVER_NAME}/${db2ServerName}/g" $createDsScript
    sed -i "s/\${PORT_NUMBER}/${db2ServerPortNumber}/g" $createDsScript
fi

# Create JDBC provider and data source using jython file
"$wasRootPath"/profiles/${wasProfileName}/bin/wsadmin.sh -lang jython -f $createDsScript
sleep 60

# Restart active nodes which will restart all servers running on the nodes
"$wasRootPath"/profiles/${wasProfileName}/bin/wsadmin.sh -lang jython -c "AdminNodeManagement.restartActiveNodes()"
sleep 120

# Remove datasource creation script file
rm -rf $createDsScript

echo "$(date): Complete to create JDBC provider and data source."
