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

# Create cluster
s1 = AdminConfig.getid('/Cell:${CELL_NAME}/')
cluster = AdminConfig.create('ServerCluster', s1, '[[name ${CLUSTER_NAME}]]')

# Add cluster members
nodes = [${NODES_STRING}]
for node in nodes:
  id = AdminConfig.getid('/Node:%s/' % node)
  clusterMemberName = '${CLUSTER_NAME}_%s' % node
  AdminConfig.createClusterMember(cluster, id, [['memberName', clusterMemberName]])
  server = AdminConfig.getid('/Server:%s/' % clusterMemberName)
  mp = AdminConfig.list('MonitoringPolicy', server)
  AdminConfig.modify(mp, '[[nodeRestartState RUNNING]]')
AdminConfig.save()
AdminNodeManagement.syncActiveNodes()

# Start cluster
clusterMgr = AdminControl.completeObjectName('cell=${CELL_NAME},type=ClusterMgr,*')
AdminControl.invoke(clusterMgr, 'retrieveClusters')
cluster = AdminControl.completeObjectName('cell=${CELL_NAME},type=Cluster,name=${CLUSTER_NAME},*')
AdminControl.invoke(cluster, 'start')
