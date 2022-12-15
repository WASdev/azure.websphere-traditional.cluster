/*
     Copyright (c) Microsoft Corporation.

 Licensed under the Apache License, Version 2.0 (the 'License');
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

          http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an 'AS IS' BASIS,
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
@secure()
param sslCertData string = newGuid()
param utcValue string = utcNow()
param appGatewayName string = 'twasclusterappgw'
param enableCookieBasedAffinity bool = false

var name_appGateway = appGatewayName
var const_appGatewayFrontEndHTTPPort = 80
var const_appGatewayFrontEndHTTPSPort = 443
var const_backendPort = 9080
var name_managedBackendAddressPool = 'managedNodeBackendPool'
var name_frontEndIPConfig = 'appGwPublicFrontendIp'
var name_httpListener = 'managedHttpListener'
var name_httpPort = 'managedHttpPort'
var name_httpSetting = 'managedHttpSetting'
var name_httpsListener = 'managedHttpsListener'
var name_httpsPort = 'managedHttpsPort'
var name_probe = 'HTTPHealthProbe'
var ref_backendAddressPool = resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name_appGateway, name_managedBackendAddressPool)
var ref_backendHttpSettings = resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name_appGateway, name_httpSetting)
var ref_backendProbe = resourceId('Microsoft.Network/applicationGateways/probes', name_appGateway, name_probe)
var ref_frontendHTTPPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpPort)
var ref_frontendHTTPSPort = resourceId('Microsoft.Network/applicationGateways/frontendPorts', name_appGateway, name_httpsPort)
var ref_frontendIPConfiguration = resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name_appGateway, name_frontEndIPConfig)
var ref_httpListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpListener)
var ref_httpsListener = resourceId('Microsoft.Network/applicationGateways/httpListeners', name_appGateway, name_httpsListener)
var ref_publicIPAddress = resourceId('Microsoft.Network/publicIPAddresses', gatewayPublicIPAddressName)
var ref_sslCertificate = resourceId('Microsoft.Network/applicationGateways/sslCertificates', name_appGateway, gatewaySslCertName)
var obj_frontendIPConfigurations1 = [
  {
    name: name_frontEndIPConfig
    properties: {
      publicIPAddress: {
        id: ref_publicIPAddress
      }
    }
  }
]

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: gatewayPublicIPAddressName
  sku: {
    name: 'Standard'
  }
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsNameforApplicationGateway
    }
  }
}

resource wafv2AppGateway 'Microsoft.Network/applicationGateways@2022-05-01' = {
  name: name_appGateway
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslCertificates: [
      {
        name: gatewaySslCertName
        properties: {
          data: sslCertData
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: gatewaySubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: obj_frontendIPConfigurations1
    frontendPorts: [
      {
        name: name_httpPort
        properties: {
          port: const_appGatewayFrontEndHTTPPort
        }
      }
      {
        name: name_httpsPort
        properties: {
          port: const_appGatewayFrontEndHTTPSPort
        }
      }
    ]
    backendAddressPools: [
      {
        name: name_managedBackendAddressPool
        properties: {}
      }
    ]
    httpListeners: [
      {
        name: name_httpListener
        properties: {
          protocol: 'Http'
          frontendIPConfiguration: {
            id: ref_frontendIPConfiguration
          }
          frontendPort: {
            id: ref_frontendHTTPPort
          }
        }
      }
      {
        name: name_httpsListener
        properties: {
          protocol: 'Https'
          frontendIPConfiguration: {
            id: ref_frontendIPConfiguration
          }
          frontendPort: {
            id: ref_frontendHTTPSPort
          }
          sslCertificate: {
            id: ref_sslCertificate
          }
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: name_httpSetting
        properties: {
          port: const_backendPort
          protocol: 'Http'
          cookieBasedAffinity: enableCookieBasedAffinity ? 'Enabled' :'Disabled'
          pickHostNameFromBackendAddress: true
          probe: {
            id: ref_backendProbe
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'managedNodeHttpRoutingRule'
        properties: {
          priority: 3
          httpListener: {
            id: ref_httpListener
          }
          backendAddressPool: {
            id: ref_backendAddressPool
          }
          backendHttpSettings: {
            id: ref_backendHttpSettings
          }
        }
      }
      {
        name: 'managedNodeHttpsRoutingRule'
        properties: {
          priority: 4
          httpListener: {
            id: ref_httpsListener
          }
          backendAddressPool: {
            id: ref_backendAddressPool
          }
          backendHttpSettings: {
            id: ref_backendHttpSettings
          }
        }
      }
    ]
    probes: [
      {
        name: name_probe
        properties: {
          protocol: 'Http'
          pickHostNameFromBackendHttpSettings: true
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          match: {
            statusCodes: [
              '200-399'
              '404'
            ]
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
    }
    enableHttp2: false
    autoscaleConfiguration: {
      minCapacity: 2
      maxCapacity: 3
    }
  }
  dependsOn: [
    gatewayPublicIP
  ]
}

output appGatewayAlias string = reference(gatewayPublicIP.id).dnsSettings.fqdn
output appGatewayId string = wafv2AppGateway.id
output appGatewayName string = name_appGateway
output appGatewayURL string = reference(gatewayPublicIP.id).dnsSettings.fqdn
output appGatewaySecuredURL string = reference(gatewayPublicIP.id).dnsSettings.fqdn
