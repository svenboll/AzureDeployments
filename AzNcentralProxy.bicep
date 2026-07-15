@description('Base name for resource in Azure')
param BaseName string = 'AzNcentralProxy'

@description('Your current N-Central JWT Key')
@secure()
param JWTKey string = ''

@description('Your current N-Central Hostname')
param NCentralHostname string = 'ncentral.yourdomain.com'

var suffix = substring(toLower(uniqueString(resourceGroup().id, resourceGroup().location)), 0, 5)
var funcAppName = toLower('${BaseName}-${suffix}')
var funcStorageName = toLower('${substring(BaseName,0,min(length(BaseName),16))}stg${suffix}')
var serverFarmName = '${substring(BaseName,0,min(length(BaseName),14))}-srv-${suffix}'
var GitHubRepo = 'https://github.com/svenboll/AzNcentralProxy.git'
var GitHubBranch = 'main'

resource funcStorage 'Microsoft.Storage/storageAccounts@2026-04-01' = {
  name: funcStorageName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
  }
}

resource serverFarm 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: serverFarmName
  location: resourceGroup().location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    perSiteScaling: false
    hyperV: false
    isXenon: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    maximumElasticWorkerCount: 1    
  }
}

resource funcApp 'Microsoft.Web/sites@2025-03-01' = {
  name: funcAppName
  location: resourceGroup().location
  kind: 'functionapp'
  properties: {
    httpsOnly: true
    serverFarmId: serverFarm.id
    siteConfig: {
      autoHealEnabled: true
      minTlsVersion: '1.2'
      powerShellVersion: '7.6'
      appSettings: [
        {
          name: 'JWTKey'
          value: JWTKey
        }
        {
          name: 'NCentralHostname'
          value: NCentralHostname
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '0'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcStorageName};AccountKey=${funcStorage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
      ]
    }
  }
}

resource sourcecontrol 'Microsoft.Web/sites/sourcecontrols@2025-03-01' = {
  parent: funcApp
  name: 'web'
  properties: {
    repoUrl: GitHubRepo
    branch: GitHubBranch
    isManualIntegration: true
  }
}
