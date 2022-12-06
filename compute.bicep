// Deploy:  az deployment group create -g <resource group name> --template-file compute.bicep --parameters parameters.compute.json
param location string
param vnet_name string
param vm_prefix string
param total_instances int
param vm_size string
param vm_gallery_image_id string
param modules_url string
param hostpool_name string

@secure()
param hostpool_token string
@secure()
param adminUsername string
@secure()
param adminPassword string

module createnic './modules/createnic.bicep' = [for i in range(0, total_instances): {
  name: 'createnic-${i+1}'
  params: {
    location: location
    vm_name: '${vm_prefix}-${i+1}'
    vnet_name: vnet_name
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

module addrdsh './modules/addrdsh.bicep' = [for i in range(0, total_instances): {
  name: 'addrdsh-${i+1}'
  params: {
    location: location
    vm_name: '${vm_prefix}-${i+1}'
    modules_url: modules_url
    hostpool_name: hostpool_name
    hostpool_token: hostpool_token
  }
  dependsOn: [
    azureadjoin[i]
  ]
}]
