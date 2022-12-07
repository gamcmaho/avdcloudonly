// Deploy:  az deployment group create -g <resource group name> --template-file main.bicep --parameters parameters.json
param location string
param token_expiration_time string
param bastion_name string
param vnet_hub_name string
param vnet_avd_name string
param azfw_policy_name string
param azfw_name string
param avd_rt_name string
param workspace_name string
param hostpool_name string
param dag_name string
param vnet_hub_cidr string
param azfw_subnet_cidr string
param bastion_subnet_cidr string
param vnet_avd_cidr string
param avd_subnet_name string
param avd_subnet_cidr string
param vm_prefix string
param total_instances int
param vm_size string
param vm_gallery_image_id string
param modules_url string

@secure()
param adminUsername string
@secure()
param adminPassword string

resource azfwpolicy 'Microsoft.Network/firewallPolicies@2022-01-01' = {
  name: azfw_policy_name
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Off'
  }
}

resource netrulecollectiongroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-01-01' = {
  parent: azfwpolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'netRuleCollection1'
        priority: 200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'allowHttpHttpsOut'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              avd_subnet_cidr
            ]
            sourceIpGroups: []
            destinationAddresses: [
              '*'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '80'
              '443'
            ]
          }
        ]
      }
    ]
  }
}

resource azfw 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: azfw_name
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Off'
    additionalProperties: {}
    ipConfigurations: [
      {
        name: '${azfw_name}Ipconf'
        properties: {
          publicIPAddress: {
            id: azfwpip.id
          }
          subnet: {
            id: '${vnethub.id}/subnets/AzureFirewallSubnet'
          }
        }
      }
    ]
    networkRuleCollections: []
    applicationRuleCollections: []
    natRuleCollections: []
    firewallPolicy: {
      id: azfwpolicy.id
    }
  }
  dependsOn: [
    netrulecollectiongroup
  ]
}

resource azfwpip 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'pip-${azfw_name}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionpip 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'pip-${bastion_name}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

resource avd_rt 'Microsoft.Network/routeTables@2022-01-01' = {
  name: avd_rt_name
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'override-default-system-route'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azfw.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource avddefaultroute 'Microsoft.Network/routeTables/routes@2022-01-01' = {
  parent: avd_rt
  name: 'override-default-system-route'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: azfw.properties.ipConfigurations[0].properties.privateIPAddress
    hasBgpOverride: false
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: bastion_name
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: '${bastion_name}-ipconfig'
        properties: {
          publicIPAddress: {
            id: bastionpip.id
          }
          subnet: {
            id: vnethub.properties.subnets[1].id
          }
        }
      }
    ]
  }
}

resource vnetavd 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: vnet_avd_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_avd_cidr
      ]
    }
    subnets: [
      {
        name: avd_subnet_name
        properties: {
          addressPrefix: avd_subnet_cidr
          routeTable: {
            id: avd_rt.id
          }
        }
      }
    ]
  }
}

resource vnethub 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnet_hub_name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet_hub_cidr
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: azfw_subnet_cidr
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastion_subnet_cidr
        }
      }
    ]
  }
}

resource hubtoavdpeer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = {
  name: '${vnethub.name}/hub-to-avd-peer'
  properties: {
    remoteVirtualNetwork: {
      id: vnetavd.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource avdtohubpeer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2022-01-01' = {
  name: '${vnetavd.name}/avd-to-hub-peer'
  properties: {
    remoteVirtualNetwork: {
      id: vnethub.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
  dependsOn: [
    hubtoavdpeer
  ]
}

resource hostpool 'Microsoft.DesktopVirtualization/hostPools@2021-07-12' = {
  name: hostpool_name
  location: location
  properties: {
    hostPoolType: 'Personal'
    customRdpProperty: 'targetisaadjoined:i:1;drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;'
    loadBalancerType: 'Persistent'
    validationEnvironment: false
    preferredAppGroupType: 'Desktop'
    startVMOnConnect: false
    registrationInfo: {
      expirationTime: token_expiration_time
      token: null
      registrationTokenOperation: 'Update'
    }
  }
}

resource dag 'Microsoft.DesktopVirtualization/applicationgroups@2021-07-12' = {
  name: dag_name
  location: location
  kind: 'Desktop'
  properties: {
    hostPoolArmPath: hostpool.id
    friendlyName: 'Default Desktop'
    applicationGroupType: 'Desktop'
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2021-07-12' = {
  name: workspace_name
  location: location
  properties: {
    applicationGroupReferences: [
      dag.id
    ]
  }
}

module createnic './modules/createnic.bicep' = [for i in range(0, total_instances): {
  name: 'createnic-${i+1}'
  params: {
    location: location
    vm_name: '${vm_prefix}-${i+1}'
    vnet_name: vnetavd.name
  }
}]

module createvm './modules/createvm.bicep' = [for i in range(0, total_instances): {
  name: 'createvm-${i+1}'
  params: {
    location: location
    vm_name: '${vm_prefix}-${i+1}'
    vm_size: vm_size
    adminUsername: adminUsername
    adminPassword: adminPassword
    vm_gallery_image_id: vm_gallery_image_id
  }
  dependsOn: [
    createnic[i]
  ]
}]

module azureadjoin './modules/azureadjoin.bicep' = [for i in range(0, total_instances): {
  name: 'azureadjoin-${i+1}'
  params: {
    location: location
    vm_name: '${vm_prefix}-${i+1}'
  }
  dependsOn: [
    createvm[i]
  ]
}]

module gethostpooltoken './modules/gethostpooltoken.bicep' = {
  name: 'gethostpooltoken'
  params: {
    location: location
    hostpool_name: hostpool_name
  }
}

module addrdsh './modules/addrdsh.bicep' = [for i in range(0, total_instances): {
  name: 'addrdsh-${i+1}'
  params: {
    location: location
    vm_name: '${vm_prefix}-${i+1}'
    modules_url: modules_url
    hostpool_name: hostpool_name
    hostpool_token: gethostpooltoken.outputs.token
  }
  dependsOn: [
    azureadjoin[i]
  ]
}]
