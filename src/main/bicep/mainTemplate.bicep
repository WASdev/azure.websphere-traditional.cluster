/*
     Copyright (c) Microsoft Corporation.
     Copyright (c) IBM Corporation.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

          http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

@description('The base URI where artifacts required by this template are located. When the template is deployed using the accompanying scripts, a private location in the subscription will be used and this value will be automatically generated.')
param _artifactsLocation string = deployment().properties.templateLink.uri

@description('The sasToken required to access _artifactsLocation.  When the template is deployed using the accompanying scripts, a sasToken will be automatically generated. Use the defaultValue if the staging location is not secured.')
@secure()
param _artifactsLocationSasToken string = ''

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Boolean value indicating, if user wants to deploy a tWAS cluster for evaluation only.')
param useTrial bool

@description('Username of your IBMid account.')
param ibmUserId string = ''

@description('Password of your IBMid account.')
@secure()
param ibmUserPwd string = ''

@description('Boolean value indicating, if user agrees to IBM contacting my company or organization.')
param shareCompanyName bool = false

@description('Boolean value indicating, if the cluster is a dynamic one or not.')
param dynamic bool = false

@description('The number of VMs to create, with one deployment manager and multiple worker nodes for the remainings.')
param numberOfNodes int

@description('The size of virtual machine to provision for each node of the cluster.')
param vmSize string

@description('The string to prepend to the name of the deployment manager server.')
param dmgrVMPrefix string

@description('The string to prepend to the name of the managed server.')
param managedVMPrefix string

@description('The string to prepend to the DNS label.')
param dnsLabelPrefix string

@description('Username for the Virtual Machine.')
param adminUsername string

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string

@description('Username for WebSphere admin.')
param wasUsername string

@description('Password for WebSphere admin.')
@secure()
param wasPassword string

@description('Type of load balancer to deploy.')
@allowed([
  'appgw'
  'ihs'
  'none'
])
param selectLoadBalancer string

@description('true to enable cookie based affinity.')
param enableCookieBasedAffinity bool = true

@description('The size of virtual machine to provision for each node of the cluster.')
param ihsVmSize string = 'Standard_D2_v3'

@description('The string to prepend to the name of the IBM HTTP Server.')
param ihsVMPrefix string = 'ihs'

@description('The string to prepend to the DNS label of the IBM HTTP Server.')
param ihsDnsLabelPrefix string = 'ihs'

@description('Username for the Virtual Machine of IBM HTTP Server.')
param ihsUnixUsername string = 'ihsadmin'

@description('SSH Key or password for the Virtual Machine of IBM HTTP Server. SSH key is recommended.')
@secure()
param ihsUnixPasswordOrKey string = ''

@description('Type of authentication to use on the Virtual Machine of IBM HTTP Server. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param ihsAuthenticationType string = 'password'

@description('Username for IBM HTTP Server admin.')
param ihsAdminUsername string = 'ihsadmin'

@description('Password for IBM HTTP Server admin.')
@secure()
param ihsAdminPassword string = ''

@description('VNET for cluster.')
param vnetForCluster object = {
  name: 'twascluster-vnet'
  resourceGroup: resourceGroup().name
  addressPrefixes: selectLoadBalancer == 'appgw' ? ['10.0.0.0/23'] : ['10.0.0.32/27']
  addressPrefix: selectLoadBalancer == 'appgw' ? '10.0.0.0/23' : '10.0.0.32/27'
  newOrExisting: 'new'
  subnets: selectLoadBalancer == 'appgw' ? {
    gatewaySubnet: {
      name: 'twascluster-appgw-subnet'
      addressPrefix: '10.0.0.0/24'
      startAddress: '10.0.0.4'
    }
    clusterSubnet: {
      name: 'twascluster-subnet'
      addressPrefix: '10.0.1.0/27'
      startAddress: '10.0.1.4'
    }
  } : {
    clusterSubnet: {
      name: 'twascluster-subnet'
      addressPrefix: '10.0.0.32/27'
      startAddress: '10.0.0.36'
    }
  }
}
@description('To mitigate ARM-TTK error: Control Named vnetForCluster must output the newOrExisting property when hideExisting is false')
param newOrExistingVnetForCluster string = 'new'
@description('To mitigate ARM-TTK error: Control Named vnetForCluster must output the resourceGroup property when hideExisting is false')
param vnetRGNameForCluster string = resourceGroup().name

@description('Boolean value indicating, if user wants to enable database connection.')
param enableDB bool = false
@allowed([
  'db2'
  'oracle'
  'sqlserver'
  'postgres'
])
@description('One of the supported database types')
param databaseType string = 'db2'
@description('JNDI Name for JDBC Datasource')
param jdbcDataSourceJNDIName string = 'jdbc/contoso'
@description('JDBC Connection String')
param dsConnectionURL string = 'jdbc:db2://contoso.db2.database:50000/sample'
@description('User id of Database')
param dbUser string = 'contosoDbUser'
@secure()
@description('Password for Database')
param dbPassword string = newGuid()
@description('Enable passwordless datasource connection.')
param enablePswlessConnection bool = false
@description('Managed identity that has access to database')
param dbIdentity object = {}

@description('${label.tagsLabel}')
param tagsByResource object = {}

param guidValue string = take(replace(newGuid(), '-', ''), 6)
param guidTag string = newGuid()

var uamiClientId = enablePswlessConnection ? reference(items(dbIdentity.userAssignedIdentities)[0].key, '${azure.apiVersionForIdentity}', 'full').properties.clientId : 'NA'
var const_arguments = format(' {0} {1} {2} {3} {4} {5} {6} {7} {8} {9} {10} {11} {12} {13}', wasUsername, wasPassword, name_dmgrVM, numberOfNodes - 1, dynamic, enableDB, databaseType, base64(jdbcDataSourceJNDIName), base64(dsConnectionURL), base64(dbUser), base64(dbPassword), enablePswlessConnection, uamiClientId, const_configureIHS)
var const_dnsLabelPrefix = format('{0}{1}', dnsLabelPrefix, guidValue)
var const_ihsArguments1 = format(' {0} {1} {2} {3} {4}', name_dmgrVM, ihsUnixUsername, ihsAdminUsername, ihsAdminPassword, name_storageAccount)
var const_ihsArguments2 = format(' {0} {1}', name_share, const_mountPointPath)
var const_ihsDnsLabelPrefix = format('{0}{1}', ihsDnsLabelPrefix, guidValue)
var const_ihsLinuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: format('/home/{0}/.ssh/authorized_keys', ihsUnixUsername)
        keyData: ihsUnixPasswordOrKey
      }
    ]
  }
}
var const_linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: format('/home/{0}/.ssh/authorized_keys', adminUsername)
        keyData: adminPasswordOrKey
      }
    ]
  }
}
var const_managedVMPrefix = format('{0}{1}VM', managedVMPrefix, guidValue)
var const_mountPointPath = '/mnt/${name_share}'
var const_newVNet = (newOrExistingVnetForCluster == 'new') ? true : false
var const_scriptLocation = uri(_artifactsLocation, 'scripts/')
var name_dmgrVM = format('{0}{1}VM', dmgrVMPrefix, guidValue)
var name_ihsPublicIPAddress = '${name_ihsVM}-ip'
var name_ihsVM = format('{0}{1}VM', ihsVMPrefix, guidValue)
var name_networkSecurityGroup = '${const_dnsLabelPrefix}-nsg'
var name_publicIPAddress = '${name_dmgrVM}-ip'
var name_share = 'wasshare'
var name_storageAccount = 'storage${guidValue}'
var name_storageAccountPrivateEndpoint = 'storagepe${guidValue}'
var ref_storageAccountPrivateEndpoint = const_configureIHS ? reference(name_storageAccountPrivateEndpoint, '${azure.apiVersionForPrivateEndpoint}').customDnsConfigs[0].ipAddresses[0] : ''

var obj_uamiForDeploymentScript = {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${uamiDeployment.outputs.uamiIdForDeploymentScript}': {}
  }
}
var const_azureSubjectName = format('{0}.{1}.{2}', name_domainLabelforApplicationGateway, location, 'cloudapp.azure.com')
var const_configureAppGw = selectLoadBalancer == 'appgw' ? true : false
var const_configureIHS = selectLoadBalancer == 'ihs' ? true : false
var name_keyVaultName = format('twasclusterkv{0}', guidValue)
var name_dnsNameforApplicationGateway = format('twasclustergw{0}', guidValue)
var name_rgNameWithoutSpecialCharacter = replace(replace(replace(replace(resourceGroup().name, '.', ''), '(', ''), ')', ''), '_', '') // remove . () _ from resource group name
var name_domainLabelforApplicationGateway = take('${name_dnsNameforApplicationGateway}-${toLower(name_rgNameWithoutSpecialCharacter)}', 63)
var name_appgwFrontendSSLCertName = 'appGatewaySslCert'
var name_appGateway = format('appgw{0}', guidValue)
var name_appGatewayPublicIPAddress = '${name_appGateway}-ip'
var name_appGWPostDeploymentDsName = format('appgwpostdeploymentds{0}', guidValue)
var name_clusterPostDeploymentDsName = format('clusterpostdeploymentds{0}', guidValue)

// Work around arm-ttk test "Variables Must Be Referenced"
var configBase64 = loadFileAsBase64('config.json')
var config = base64ToJson(configBase64)

var _objTagsByResource = {
  '${identifier.virtualMachines}': contains(tagsByResource, '${identifier.virtualMachines}') ? tagsByResource['${identifier.virtualMachines}'] : json('{}')
  '${identifier.virtualMachinesExtensions}': contains(tagsByResource, '${identifier.virtualMachinesExtensions}') ? tagsByResource['${identifier.virtualMachinesExtensions}'] : json('{}')
  '${identifier.virtualNetworks}': contains(tagsByResource, '${identifier.virtualNetworks}') ? tagsByResource['${identifier.virtualNetworks}'] : json('{}')
  '${identifier.networkInterfaces}': contains(tagsByResource, '${identifier.networkInterfaces}') ? tagsByResource['${identifier.networkInterfaces}'] : json('{}')
  '${identifier.networkSecurityGroups}': contains(tagsByResource, '${identifier.networkSecurityGroups}') ? tagsByResource['${identifier.networkSecurityGroups}'] : json('{}')
  '${identifier.publicIPAddresses}': contains(tagsByResource, '${identifier.publicIPAddresses}') ? tagsByResource['${identifier.publicIPAddresses}'] : json('{}')
  '${identifier.deploymentScripts}': contains(tagsByResource, '${identifier.deploymentScripts}') ? tagsByResource['${identifier.deploymentScripts}'] : json('{}')
  '${identifier.storageAccounts}': contains(tagsByResource, '${identifier.storageAccounts}') ? tagsByResource['${identifier.storageAccounts}'] : json('{}')
  '${identifier.vaults}': contains(tagsByResource, '${identifier.vaults}') ? tagsByResource['${identifier.vaults}'] : json('{}')
  '${identifier.userAssignedIdentities}': contains(tagsByResource, '${identifier.userAssignedIdentities}') ? tagsByResource['${identifier.userAssignedIdentities}'] : json('{}') 
  '${identifier.applicationGateways}': contains(tagsByResource, '${identifier.applicationGateways}') ? tagsByResource['${identifier.applicationGateways}'] : json('{}')
  '${identifier.privateEndpoints}': contains(tagsByResource, '${identifier.privateEndpoints}') ? tagsByResource['${identifier.privateEndpoints}'] : json('{}') 

}

module partnerCenterPid './modules/_pids/_empty.bicep' = {
  name: 'pid-83c32565-42aa-43d9-92e9-9c02289c7fbd-partnercenter'
  params: {
  }
}

module shareCompanyNamePid './modules/_pids/_empty.bicep' = if (useTrial && shareCompanyName) {
  name: config.shareCompanyNamePid
  params: {}
}

module clusterStartPid './modules/_pids/_empty.bicep' = {
  name: (useTrial ? config.clusterTrialStart : config.clusterStart)
  params: {}
}

module uamiDeployment 'modules/_uami/_uamiAndRoles.bicep' = {
  name: 'uami-deployment'
  params: {
    location: location
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@${azure.apiVersionForStorage}' = {
  name: name_storageAccount
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: _objTagsByResource['${identifier.storageAccounts}']
}

resource storageAccountPrivateEndpoint 'Microsoft.Network/privateEndpoints@${azure.apiVersionForPrivateEndpoint}' = if (const_configureIHS) {
  name: name_storageAccountPrivateEndpoint
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: name_storageAccountPrivateEndpoint
        properties: {
          privateLinkServiceId: resourceId('Microsoft.Storage/storageAccounts/', name_storageAccount)
          groupIds: [
            'file'
          ]
        }
      }
    ]
    subnet: {
      id: const_newVNet ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetForCluster.name, vnetForCluster.subnets.clusterSubnet.name) : existingClusterSubnet.id
    }
  }
  dependsOn: [
    storageAccount
    virtualNetwork
    existingClusterSubnet
  ]
}

resource storageAccountFileSvc 'Microsoft.Storage/storageAccounts/fileServices@${azure.apiVersionForStorageFileService}' = if (const_configureIHS) {
  parent: storageAccount
  name: 'default'
}

resource storageAccountFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@${azure.apiVersionForStorageFileService}' = if (const_configureIHS) {
  parent: storageAccountFileSvc
  name: name_share
  properties: {
    shareQuota: 1
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@${azure.apiVersionForNetworkSecurityGroups}' = if (const_newVNet) {
  name: name_networkSecurityGroup
  location: location
  properties: {
    securityRules: const_configureAppGw ? [
      {
        name: 'ALLOW_APPGW'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
      {
        name: 'ALLOW_HTTP_ACCESS'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 310
          direction: 'Inbound'
          destinationPortRanges: [
            '9060'
            '9080'
            '9043'
            '9443'
            '80'
            '443'
          ]
        }
      }
    ]: [
      {
        name: 'ALLOW_HTTP_ACCESS'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
          destinationPortRanges: [
            '9060'
            '9080'
            '9043'
            '9443'
            '80'
          ]
        }
      }
    ]
  }
  tags: _objTagsByResource['${identifier.networkSecurityGroups}']
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' = if (const_newVNet) {
  name: vnetForCluster.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vnetForCluster.addressPrefixes
    }
    subnets: const_configureAppGw ? [
      {
        name: vnetForCluster.subnets.gatewaySubnet.name
        properties: {
          addressPrefix: vnetForCluster.subnets.gatewaySubnet.addressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
      {
        name: vnetForCluster.subnets.clusterSubnet.name
        properties: {
          addressPrefix: vnetForCluster.subnets.clusterSubnet.addressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ] : [
      {
        name: vnetForCluster.subnets.clusterSubnet.name
        properties: {
          addressPrefix: vnetForCluster.subnets.clusterSubnet.addressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
  tags: _objTagsByResource['${identifier.virtualNetworks}']  
}

resource existingVNet 'Microsoft.Network/virtualNetworks@${azure.apiVersionForVirtualNetworks}' existing = if (!const_newVNet) {
  name: vnetForCluster.name
  scope: resourceGroup(vnetRGNameForCluster)
}

resource existingAppGwSubnet 'Microsoft.Network/virtualNetworks/subnets@${azure.apiVersionForVirtualNetworks}' existing = if (!const_newVNet && const_configureAppGw) {
  parent: existingVNet
  name: vnetForCluster.subnets.gatewaySubnet.name
}

resource existingClusterSubnet 'Microsoft.Network/virtualNetworks/subnets@${azure.apiVersionForVirtualNetworks}' existing = if (!const_newVNet) {
  parent: existingVNet
  name: vnetForCluster.subnets.clusterSubnet.name
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@${azure.apiVersionForPublicIPAddresses}' = {
  name: name_publicIPAddress
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: concat(toLower(const_dnsLabelPrefix))
    }
  }
  tags: const_newVNet ? _objTagsByResource['${identifier.publicIPAddresses}'] : union(_objTagsByResource['${identifier.publicIPAddresses}'], {
    '${guidTag}': ''
  })
}

resource dmgrVMNetworkInterface 'Microsoft.Network/networkInterfaces@${azure.apiVersionForNetworkInterfaces}' = {
  name: '${name_dmgrVM}-if'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddress.id
          }
          subnet: {
            id: const_newVNet ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetForCluster.name, vnetForCluster.subnets.clusterSubnet.name) : existingClusterSubnet.id
          }
        }
      }
    ]
    dnsSettings: {
      internalDnsNameLabel: name_dmgrVM
    }
  }
  dependsOn: [
    virtualNetwork
    existingClusterSubnet
  ]
  tags: _objTagsByResource['${identifier.networkInterfaces}']  
}

resource managedVMPublicIPAddresses 'Microsoft.Network/publicIPAddresses@${azure.apiVersionForPublicIPAddresses}' = [for i in range(0, (numberOfNodes - 1)): {
  name: '${const_managedVMPrefix}${(i + 1)}-ip'
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: concat(toLower('${const_dnsLabelPrefix}${(i + 1)}'))
    }
  }
  tags: union(_objTagsByResource['${identifier.networkInterfaces}'], {
    '${guidTag}': ''
  })
}]

resource managedVMNetworkInterfaces 'Microsoft.Network/networkInterfaces@${azure.apiVersionForNetworkInterfaces}' = [for i in range(0, (numberOfNodes - 1)): {
  name: '${const_managedVMPrefix}${(i + 1)}-if'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', '${const_managedVMPrefix}${(i + 1)}-ip')
          }
          subnet: {
            id: const_newVNet ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetForCluster.name, vnetForCluster.subnets.clusterSubnet.name) : existingClusterSubnet.id
          }
        }
      }
    ]
    dnsSettings: {
      internalDnsNameLabel: '${const_managedVMPrefix}${(i + 1)}'
    }
  }
  dependsOn: [
    virtualNetwork
    existingClusterSubnet
    managedVMPublicIPAddresses
  ]
  tags: _objTagsByResource['${identifier.networkInterfaces}']    
}]

module appGatewayStartPid './modules/_pids/_empty.bicep' = if (const_configureAppGw) {
  name: config.appGatewayStart
  params: {}
  dependsOn: [
    uamiDeployment
  ]
}

module appgwSecretDeployment 'modules/_azure-resources/_keyvaultForGateway.bicep' = if (const_configureAppGw) {
  name: 'appgateway-certificates-secrets-deployment'
  params: {
    identity: const_configureAppGw ? obj_uamiForDeploymentScript : {}
    location: location
    sku: 'Standard'
    subjectName: format('CN={0}', const_azureSubjectName)
    keyVaultName: name_keyVaultName
  }
  dependsOn: [
    uamiDeployment
  ]
}

module appgwDeployment 'modules/_appgateway.bicep' = if (const_configureAppGw) {
  name: 'app-gateway-deployment'
  params: {
    appGatewayName: name_appGateway
    dnsNameforApplicationGateway: name_dnsNameforApplicationGateway
    gatewayPublicIPAddressName: name_appGatewayPublicIPAddress
    gatewaySubnetId: const_newVNet ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetForCluster.name, vnetForCluster.subnets.gatewaySubnet.name) : existingAppGwSubnet.id
    gatewaySslCertName: name_appgwFrontendSSLCertName
    location: location
    sslCertDataSecretName: const_configureAppGw ? appgwSecretDeployment.outputs.sslCertDataSecretName : 'kv-ssl-data'
    keyVaultName: name_keyVaultName
    enableCookieBasedAffinity: enableCookieBasedAffinity
    numberOfWorkerNodes: numberOfNodes - 1
    workerNodePrefix: const_managedVMPrefix
  }
  dependsOn: [
    appgwSecretDeployment
    existingAppGwSubnet
    managedVMNetworkInterfaces
  ]
}

module appgwPostDeployment 'modules/_deployment-scripts/_dsAppGWPostDeployment.bicep' = if (const_configureAppGw) {
  name: name_appGWPostDeploymentDsName
  params: {
    name: name_appGWPostDeploymentDsName
    location: location
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    identity: const_configureAppGw ? obj_uamiForDeploymentScript : {}
    configureAppGw: const_configureAppGw
    resourceGroupName: resourceGroup().name
    numberOfWorkerNodes: numberOfNodes - 1
    workerNodePrefix: const_managedVMPrefix
  }
  dependsOn: [
    appgwDeployment
  ]
}

module appGatewayEndPid './modules/_pids/_empty.bicep' = if (const_configureAppGw) {
  name: config.appGatewayEnd
  params: {}
  dependsOn: [
    appgwPostDeployment
  ]
}

resource clusterVMs 'Microsoft.Compute/virtualMachines@${azure.apiVersionForVirtualMachines}' = [for i in range(0, numberOfNodes): {
  name: i == 0 ? name_dmgrVM : '${const_managedVMPrefix}${i}'
  location: location
  identity: enablePswlessConnection ? dbIdentity : null
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: config.imagePublisher
        offer: config.twasNdImageOffer
        sku: config.twasNdImageSku
        version: config.twasNdImageVersion
      }
      osDisk: {
        name: format('{0}-disk', i == 0 ? name_dmgrVM : '${const_managedVMPrefix}${i}')
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: i == 0 ? name_dmgrVM : '${const_managedVMPrefix}${i}'
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? json('null') : const_linuxConfiguration)
      customData: base64(useTrial ? ' ' : format('{0} {1}', ibmUserId, ibmUserPwd))
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', format('{0}-if', i == 0 ? name_dmgrVM : '${const_managedVMPrefix}${i}'))
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(storageAccount.id, '${azure.apiVersionForStorage}').primaryEndpoints.blob
      }
    }
  }
  plan: {
    name: config.twasNdImageSku
    publisher: config.imagePublisher
    product: config.twasNdImageOffer
  }
  dependsOn: [
    dmgrVMNetworkInterface
    managedVMNetworkInterfaces
  ]
  tags: _objTagsByResource['${identifier.virtualMachines}']  
}]

module clusterVMsCreated './modules/_pids/_empty.bicep' = {
  name: 'clusterVMsCreated'
  params: {
  }
  dependsOn: [
    clusterVMs
  ]
}

module dbConnectionStartPid './modules/_pids/_empty.bicep' = if (enableDB) {
  name: config.dbConnectionStart
  params: {}
  dependsOn: [
    clusterVMs
  ]
}

resource clusterVMsExtension 'Microsoft.Compute/virtualMachines/extensions@${azure.apiVersionForVirtualMachineExtensions}' = [for i in range(0, numberOfNodes): {
  name: format('{0}/install', i == 0 ? name_dmgrVM : '${const_managedVMPrefix}${i}')
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    settings: {
      fileUris: [
        uri(const_scriptLocation, 'install.sh${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-cluster.py${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-dcluster.py${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'configure-ihs-on-dmgr.sh${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'configure-im.py${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'pluginutil.sh${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-ds.sh${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-ds-db2.py.template${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-ds-oracle.py.template${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-ds-sqlserver.py.template${_artifactsLocationSasToken}')
        uri(const_scriptLocation, 'create-ds-postgres.py.template${_artifactsLocationSasToken}')
      ]
    }
    protectedSettings: {
      commandToExecute: format('sh install.sh {0}{1}{2}', i == 0, const_arguments, const_configureIHS ? format(' {0} {1}{2} {3}', name_storageAccount, listKeys(storageAccount.id, '${azure.apiVersionForStorage}').keys[0].value, const_ihsArguments2, ref_storageAccountPrivateEndpoint) : '')
    }
  }
  dependsOn: [
    storageAccountFileShare
    clusterVMs
  ]
  tags: _objTagsByResource['${identifier.virtualMachinesExtensions}']  
}]

module dbConnectionEndPid './modules/_pids/_empty.bicep' = if (enableDB) {
  name: config.dbConnectionEnd
  params: {}
  dependsOn: [
    clusterVMsExtension
  ]
}

module clusterEndPid './modules/_pids/_empty.bicep' = {
  name: (useTrial ? config.clusterTrialEnd : config.clusterEnd)
  params: {
  }
  dependsOn: [
    clusterVMsExtension
  ]
}

module ihsStartPid './modules/_pids/_empty.bicep' = if (const_configureIHS) {
  name: (useTrial ? config.ihsTrialStart : config.ihsStart)
  params: {
  }
}

resource ihsPublicIPAddress 'Microsoft.Network/publicIPAddresses@${azure.apiVersionForPublicIPAddresses}' = if (const_configureIHS) {
  name: name_ihsPublicIPAddress
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: concat(toLower(const_ihsDnsLabelPrefix))
    }
  }
  tags: const_newVNet ? _objTagsByResource['${identifier.publicIPAddresses}'] : union(_objTagsByResource['${identifier.publicIPAddresses}'], {
    '${guidTag}': ''
  })
}

resource ihsVMNetworkInterface 'Microsoft.Network/networkInterfaces@${azure.apiVersionForNetworkInterfaces}' = if (const_configureIHS) {
  name: '${name_ihsVM}-if'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: ihsPublicIPAddress.id
          }
          subnet: {
            id: const_newVNet ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetForCluster.name, vnetForCluster.subnets.clusterSubnet.name) : existingClusterSubnet.id
          }
        }
      }
    ]
    dnsSettings: {
      internalDnsNameLabel: name_ihsVM
    }
  }
  dependsOn: [
    virtualNetwork
    existingClusterSubnet
  ]
  tags: _objTagsByResource['${identifier.networkInterfaces}']  
}

resource ihsVMNetworkInterfaceNoPubIp 'Microsoft.Network/networkInterfaces@${azure.apiVersionForNetworkInterfaces}' = if (const_configureIHS && !const_newVNet) {
  name: '${name_ihsVM}-no-pub-ip-if'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: existingClusterSubnet.id
          }
        }
      }
    ]
  }
  tags: _objTagsByResource['${identifier.networkInterfaces}']   
}

resource ihsVM 'Microsoft.Compute/virtualMachines@${azure.apiVersionForVirtualMachines}' = if (const_configureIHS) {
  name: name_ihsVM
  location: location
  properties: {
    hardwareProfile: {
      vmSize: ihsVmSize
    }
    storageProfile: {
      imageReference: {
        publisher: config.imagePublisher
        offer: config.ihsImageOffer
        sku: config.ihsImageSku
        version: config.ihsImageVersion
      }
      osDisk: {
        name: '${name_ihsVM}-disk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: name_ihsVM
      adminUsername: ihsUnixUsername
      adminPassword: ihsUnixPasswordOrKey
      linuxConfiguration: ((ihsAuthenticationType == 'password') ? json('null') : const_ihsLinuxConfiguration)
      customData: base64(useTrial ? ' ' : format('{0} {1}', ibmUserId, ibmUserPwd))
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: ihsVMNetworkInterface.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: reference(storageAccount.id, '${azure.apiVersionForStorage}').primaryEndpoints.blob
      }
    }
  }
  plan: {
    name: config.ihsImageSku
    publisher: config.imagePublisher
    product: config.ihsImageOffer
  }
  tags: _objTagsByResource['${identifier.virtualMachines}']  
}

module ihsVMCreated './modules/_pids/_empty.bicep' = if (const_configureIHS) {
  name: 'ihsVMCreated'
  params: {
  }
  dependsOn: [
    ihsVM
  ]
}

resource ihsVMExtension 'Microsoft.Compute/virtualMachines/extensions@${azure.apiVersionForVirtualMachineExtensions}' = if (const_configureIHS) {
  parent: ihsVM
  name: 'install'
  location: location
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.0'
    settings: {
      fileUris: [
        uri(const_scriptLocation, 'configure-ihs.sh${_artifactsLocationSasToken}')
      ]
    }
    protectedSettings: {
      commandToExecute: format('sh configure-ihs.sh{0} {1}{2} {3}', const_ihsArguments1, listKeys(storageAccount.id, '${azure.apiVersionForStorage}').keys[0].value, const_ihsArguments2, ref_storageAccountPrivateEndpoint)
    }
  }
  dependsOn: [
    storageAccountFileShare
  ]
  tags: _objTagsByResource['${identifier.virtualMachinesExtensions}']  
}

module ihsEndPid './modules/_pids/_empty.bicep' = if (const_configureIHS) {
  name: (useTrial ? config.ihsTrialEnd : config.ihsEnd)
  params: {
  }
  dependsOn: [
    ihsVMExtension
  ]
}

module clusterPostDeployment 'modules/_deployment-scripts/_dsClusterPostDeployment.bicep' = {
  name: name_clusterPostDeploymentDsName
  params: {
    name: name_clusterPostDeploymentDsName
    location: location
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    identity: obj_uamiForDeploymentScript
    resourceGroupName: resourceGroup().name
    guidTag: guidTag
  }
  dependsOn: [
    appgwPostDeployment
    clusterVMsExtension
    ihsVMExtension
  ]
}

output resourceGroupName string = resourceGroup().name
output region string = location
output clusterName string = 'MyCluster'
output nodeGroupName string = 'DefaultNodeGroup'
output coreGroupName string = 'DefaultCoreGroup'
output dmgrHostName string = name_dmgrVM
output dmgrPort string = '8879'
output virtualNetworkName string = vnetForCluster.name
output subnetName string = vnetForCluster.subnets.clusterSubnet.name
output adminSecuredConsole string = uri(format('https://{0}:9043/', const_newVNet ? publicIPAddress.properties.dnsSettings.fqdn : reference('${name_dmgrVM}-if').ipConfigurations[0].properties.privateIPAddress), 'ibm/console/logon.jsp')
output ihsConsole string = const_configureIHS ? uri(format('http://{0}', const_newVNet ? ihsPublicIPAddress.properties.dnsSettings.fqdn : reference('${name_ihsVM}-if').ipConfigurations[0].properties.privateIPAddress), '') : 'N/A'
output appGatewayHttpURL string = const_configureAppGw ? uri(format('http://{0}/', appgwDeployment.outputs.appGatewayURL), '/') : 'N/A'
output appGatewayHttpsURL string = const_configureAppGw ? uri(format('https://{0}/', appgwDeployment.outputs.appGatewaySecuredURL), '/') : 'N/A'
