#!/bin/bash

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

set -Eeuo pipefail

# Update the IP configuration of network interface assigned to each worker node of the cluster by setting its private ip allocation method to Static
if [[ "${CONFIGURE_APPGW,,}" == "true" ]]; then
  for i in $(seq 1 $NUMBER_OF_WORKER_NODES); do
    nicName=${WORKER_NODE_PREFIX}${i}-if
    ipConfigName=$(az network nic show -g ${RESOURCE_GROUP_NAME} -n ${nicName} --query 'ipConfigurations[0].name' -o tsv)
    az network nic ip-config update -g ${RESOURCE_GROUP_NAME} --nic-name ${nicName} -n ${ipConfigName} --set privateIpAllocationMethod=Static
  done
fi
