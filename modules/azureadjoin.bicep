param location string
param vm_name string

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: vm_name
}

resource azureadjoin 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: vm
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}
