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

# Parameters
wasRootPath=$1                                      # Root path of WebSphere
wasProfileName=$2                                   # WAS profile name
wasClusterName=$3                                   # WAS cluster name
dbType=$4                                           # Supported database types: [db2, oracle]
jdbcDataSourceName=$5                               # JDBC Datasource name
jdbcDSJNDIName=$(echo "${6}" | base64 -d)           # JDBC Datasource JNDI name
dsConnectionString=$(echo "${7}" | base64 -d)       # JDBC Datasource connection String
databaseUser=$(echo "${8}" | base64 -d)             # Database username
databasePassword=$(echo "${9}" | base64 -d)         # Database user password
enablePswlessConnection=${10}                       # If passwordless connection to database is enabled
uamiClientId=${11}                                  # Managed identity client ID
jdbcDriverPath=${12}                                # JDBC driver path
jdbcDriverClassPath=${13}                           # JDBC driver class path

echo "$(date): Start to create JDBC provider and data source."

# Copy data source creation template per database type
createDsTemplate=create-ds-${dbType}.py.template
createDsScript=create-ds-${dbType}.py
cp $createDsTemplate $createDsScript

if [ $dbType == "db2" ]; then
    regex="^jdbc:db2://([^/]+):([0-9]+)/([[:alnum:]_-]+)"
    if [[ "$dsConnectionString" =~ $regex ]]; then 
        db2ServerName="${BASH_REMATCH[1]}"
        db2ServerPortNumber="${BASH_REMATCH[2]}"
        db2DBName="${BASH_REMATCH[3]}"
    else
        echo "$dsConnectionString doesn't match the required format of DB2 data source connection string."
        exit 1
    fi

    # Replace placeholder strings with user-input parameters
    sed -i "s/\${CLUSTER_NAME}/${wasClusterName}/g" $createDsScript
    sed -i "s#\${DB2UNIVERSAL_JDBC_DRIVER_PATH}#${jdbcDriverPath}#g" $createDsScript
    sed -i "s/\${DB2_DATABASE_USER_NAME}/${databaseUser}/g" $createDsScript
    sed -i "s/\${DB2_DATABASE_USER_PASSWORD}/${databasePassword}/g" $createDsScript
    sed -i "s/\${DB2_DATABASE_NAME}/${db2DBName}/g" $createDsScript
    sed -i "s/\${DB2_DATASOURCE_NAME}/${jdbcDataSourceName}/g" $createDsScript
    sed -i "s#\${DB2_DATASOURCE_JNDI_NAME}#${jdbcDSJNDIName}#g" $createDsScript
    sed -i "s/\${DB2_SERVER_NAME}/${db2ServerName}/g" $createDsScript
    sed -i "s/\${DB2_PORT_NUMBER}/${db2ServerPortNumber}/g" $createDsScript
elif [ $dbType == "oracle" ]; then
    # Replace placeholder strings with user-input parameters
    sed -i "s/\${CLUSTER_NAME}/${wasClusterName}/g" $createDsScript
    sed -i "s#\${ORACLE_JDBC_DRIVER_CLASS_PATH}#${jdbcDriverClassPath}#g" $createDsScript
    sed -i "s/\${ORACLE_DATABASE_USER_NAME}/${databaseUser}/g" $createDsScript
    sed -i "s/\${ORACLE_DATABASE_USER_PASSWORD}/${databasePassword}/g" $createDsScript
    sed -i "s/\${ORACLE_DATASOURCE_NAME}/${jdbcDataSourceName}/g" $createDsScript
    sed -i "s#\${ORACLE_DATASOURCE_JNDI_NAME}#${jdbcDSJNDIName}#g" $createDsScript
    sed -i "s#\${ORACLE_DATABASE_URL}#${dsConnectionString}#g" $createDsScript
elif [ $dbType == "sqlserver" ]; then
    regex="^jdbc:sqlserver://([^/]+):([0-9]+);database=([[:alnum:]_-]+)"
    if [[ "$dsConnectionString" =~ $regex ]]; then 
        sqlServerServerName="${BASH_REMATCH[1]}"
        sqlServerPortNumber="${BASH_REMATCH[2]}"
        sqlServerDBName="${BASH_REMATCH[3]}"
    else
        echo "$dsConnectionString doesn't match the required format of Microsoft SQL Server data source connection string."
        exit 1
    fi

    # Replace placeholder strings with user-input parameters
    sed -i "s/\${CLUSTER_NAME}/${wasClusterName}/g" $createDsScript
    sed -i "s#\${SQLSERVER_JDBC_DRIVER_CLASS_PATH}#${jdbcDriverClassPath}#g" $createDsScript
    sed -i "s/\${SQLSERVER_DATABASE_USER_NAME}/${databaseUser}/g" $createDsScript
    sed -i "s/\${SQLSERVER_DATABASE_USER_PASSWORD}/${databasePassword}/g" $createDsScript
    sed -i "s/\${SQLSERVER_DATABASE_NAME}/${sqlServerDBName}/g" $createDsScript
    sed -i "s/\${SQLSERVER_DATASOURCE_NAME}/${jdbcDataSourceName}/g" $createDsScript
    sed -i "s#\${SQLSERVER_DATASOURCE_JNDI_NAME}#${jdbcDSJNDIName}#g" $createDsScript
    sed -i "s/\${SQLSERVER_SERVER_NAME}/${sqlServerServerName}/g" $createDsScript
    sed -i "s/\${SQLSERVER_PORT_NUMBER}/${sqlServerPortNumber}/g" $createDsScript
    sed -i "s/\${ENABLE_PASSWORDLESS_CONNECTION}/${enablePswlessConnection}/g" $createDsScript
    sed -i "s/\${MSI_CLIENT_ID}/${uamiClientId}/g" $createDsScript
elif [ $dbType == "postgres" ]; then
    # Replace placeholder strings with user-input parameters
    sed -i "s/\${CLUSTER_NAME}/${wasClusterName}/g" $createDsScript
    sed -i "s#\${POSTGRESQL_JDBC_DRIVER_CLASS_PATH}#${jdbcDriverClassPath}#g" $createDsScript
    sed -i "s/\${POSTGRESQL_DATABASE_USER_NAME}/${databaseUser}/g" $createDsScript
    sed -i "s/\${POSTGRESQL_DATABASE_USER_PASSWORD}/${databasePassword}/g" $createDsScript
    sed -i "s/\${POSTGRESQL_DATASOURCE_NAME}/${jdbcDataSourceName}/g" $createDsScript
    sed -i "s#\${POSTGRESQL_DATASOURCE_JNDI_NAME}#${jdbcDSJNDIName}#g" $createDsScript
    sed -i "s#\${POSTGRESQL_DATABASE_URL}#${dsConnectionString}#g" $createDsScript
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
