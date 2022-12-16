/*
     Copyright (c) Microsoft Corporation.

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

@description('DNS for ApplicationGateway')
param dnsNameforApplicationGateway string = take('twasclustergw${uniqueString(utcValue)}', 63)
@description('Public IP Name for the Application Gateway')
param gatewayPublicIPAddressName string = 'gwip'
param gatewaySubnetId string = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/resourcegroupname/providers/Microsoft.Network/virtualNetworks/vnetname/subnets/subnetname'
param gatewaySslCertName string = 'appGatewaySslCert'
param location string
param utcValue string = utcNow()
param appGatewayName string = 'twasclusterappgw'
param keyVaultName string = 'keyVaultName'
param sslCertDataSecretName string = 'sslCertDataSecretName'
param enableCookieBasedAffinity bool = true

var name_appGateway = appGatewayName

// get key vault object from a resource group
resource existingKeyvault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup()
}

module appgwDeployment1 './_azure-resources/_appGateway.bicep' = {
  name: 'app-gateway-deployment-with-self-signed-cert'
  params: {
    appGatewayName: name_appGateway
    dnsNameforApplicationGateway: dnsNameforApplicationGateway
    gatewayPublicIPAddressName: gatewayPublicIPAddressName
    gatewaySubnetId: gatewaySubnetId
    gatewaySslCertName: gatewaySslCertName
    location: location
    sslCertData: existingKeyvault.getSecret(sslCertDataSecretName)
    enableCookieBasedAffinity: enableCookieBasedAffinity
  }
  dependsOn: [
    existingKeyvault
  ]
}

output appGatewayAlias string = appgwDeployment1.outputs.appGatewayAlias
output appGatewayId string = appgwDeployment1.outputs.appGatewayId
output appGatewayName string = appgwDeployment1.outputs.appGatewayName
output appGatewayURL string = appgwDeployment1.outputs.appGatewayURL
output appGatewaySecuredURL string = appgwDeployment1.outputs.appGatewaySecuredURL
