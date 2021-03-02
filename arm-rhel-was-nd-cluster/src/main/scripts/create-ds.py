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

# Reference: https://raw.githubusercontent.com/keensoft/was-db2-docker/master/was/assets/create-datasource.jython

# Get WAS cluster id as the parent ID for creating JDBC provider
cluster = AdminConfig.getid('/ServerCluster:${CLUSTER_NAME}/')

# JDBC Provider
n1 = ['name', 'DB2JDBCProvider']
implCN = ['implementationClassName', 'com.ibm.db2.jcc.DB2XADataSource']
cls = ['classpath', '${DB2UNIVERSAL_JDBC_DRIVER_PATH}/db2jcc.jar;${DB2UNIVERSAL_JDBC_DRIVER_PATH}/db2jcc_license_cu.jar;${DB2UNIVERSAL_JDBC_DRIVER_PATH}/db2jcc_license_cisuz.jar']
provider = ['providerType', 'DB2 Universal JDBC Driver Provider (XA)']
xa = ['xa', 'true']
jdbcAttrs = [n1,  implCN, cls, provider, xa]
jdbCProvider = AdminConfig.create('JDBCProvider', cluster, jdbcAttrs)

# JASS Auth entry
userAlias = 'wasnd-cluster/db2'
alias = ['alias', userAlias]
userid = ['userId', '${DB2_DATABASE_USER_NAME}']
password = ['password', '${DB2_DATABASE_USER_PASSWORD}']
jaasAttrs = [alias, userid, password]
security = AdminConfig.getid('/Security:/')
j2cUser = AdminConfig.create('JAASAuthData', security, jaasAttrs)

# Data Source
newjdbc = AdminConfig.getid('/JDBCProvider:DB2JDBCProvider/')
name = ['name', 'DB2DataSource']
jndi = ['jndiName', '${DB2_DATASOURCE_JNDI_NAME}']
auth = ['authDataAlias', userAlias]
authMechanism = ['authMechanismPreference', 'BASIC_PASSWORD']
helper = ['datasourceHelperClassname', 'com.ibm.websphere.rsadapter.DB2UniversalDataStoreHelper']
dsAttrs = [name, jndi, auth, authMechanism, helper]
newds = AdminConfig.create('DataSource', newjdbc, dsAttrs)

# Data Source properties
propSet = AdminConfig.create('J2EEResourcePropertySet', newds, [])
AdminConfig.create('J2EEResourceProperty', propSet, [["name", "driverType"], ["value", "4"]])
AdminConfig.create('J2EEResourceProperty', propSet, [["name", "databaseName"], ["value", "${DB2_DATABASE_NAME}"]])
AdminConfig.create('J2EEResourceProperty', propSet, [["name", "serverName"], ["value", "${DB2_SERVER_NAME}"]])
AdminConfig.create('J2EEResourceProperty', propSet, [["name", "portNumber"], ["value", "${PORT_NUMBER}"]])

# Create CMP Connection factory
rra = AdminConfig.getid("/ServerCluster:${CLUSTER_NAME}/J2CResourceAdapter:WebSphere Relational Resource Adapter/")
cmpAttrs = []
cmpAttrs.append(["name", "DB2DataSource_CF"])
cmpAttrs.append(["authMechanismPreference", "BASIC_PASSWORD"])
cmpAttrs.append(["authDataAlias", userAlias])
cmpAttrs.append(["cmpDatasource", newds])
cf = AdminConfig.create("CMPConnectorFactory", rra, cmpAttrs)

# Save configuratoin changes and sync to active nodes
AdminConfig.save()
AdminNodeManagement.syncActiveNodes()
