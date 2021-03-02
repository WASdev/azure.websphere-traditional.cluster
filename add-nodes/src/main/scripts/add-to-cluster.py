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

# Get cluster id
cluster = AdminConfig.getid('/ServerCluster:${CLUSTER_NAME}/')

# Add node as cluster member
node = AdminConfig.getid('/Node:${NODE_NAME}/')
AdminConfig.createClusterMember(cluster, node, [['memberName', '${CLUSTER_MEMBER_NAME}']])
AdminConfig.save()

# Modify nodeRestartState of cluster member as RUNNING
server = AdminConfig.getid('/Server:${CLUSTER_MEMBER_NAME}/')
mp = AdminConfig.list('MonitoringPolicy', server)
AdminConfig.modify(mp, '[[nodeRestartState RUNNING]]')
AdminConfig.save()

AdminNodeManagement.syncActiveNodes()
