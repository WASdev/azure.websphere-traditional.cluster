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

# Create dynamic cluster
properties = ('[-membershipPolicy "node_nodegroup = \'${NODE_GROUP_NAME}\'" '
'-dynamicClusterProperties "[[operationalMode automatic][minInstances 1][maxInstances -1][numVerticalInstances 1][serverInactivityTime 1440]]" '
'-clusterProperties "[[preferLocal false][createDomain false][templateName default][coreGroup ${CORE_GROUP_NAME}]]"]')
AdminTask.createDynamicCluster('${CLUSTER_NAME}', properties)

# Save changes and synchronize to active nodes
AdminConfig.save()
AdminNodeManagement.syncActiveNodes()
