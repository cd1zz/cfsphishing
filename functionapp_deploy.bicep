param FunctionAppName string
var StorageAccountName = '${uniqueString(resourceGroup().id)}-funcApp-storageAcct'

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${FunctionAppName}-appinsights'
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    ApplicationId: FunctionAppName
  }
}
resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: StorageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
  properties: {
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2018-02-01' = {
  name: '${FunctionAppName}-appServicePlan' 
  location: resourceGroup().location
  sku: {
    name: 'Y1'  
    tier: 'Dynamic'
  }
  kind: 'functionapp,linux'
  properties: {
    reserved: true
    name: FunctionAppName
    workerSize: 0
    workerSizeId: 0
    numberOfWorkers: 1
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2019-06-01' = {
  parent: storageAccount
  name: 'default'
  dependsOn: [
    storageAccount
  ]
  properties: {
    cors: {
      corsRules: []
    }
    deleteRetentionPolicy: {
      enabled: false
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2019-06-01' = {
  parent: storageAccount
  name: 'default'
  dependsOn: [
    storageAccount
  ]
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource functionapp_resource 'Microsoft.Web/sites@2018-02-01' = {
  name: FunctionAppName
  location: resourceGroup().location
  dependsOn: [
    storageAccount
    appServicePlan
    appInsights
  ]
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: true
    alwaysOn: true
    reserved: true
    siteConfig: {
      linuxFxVersion: 'python|3.9'
    }
  }
  resource appSettings 'config' = {
    name: 'appsettings'
    dependsOn: [
      functionapp_resource
    ]
    properties: {
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'python'
      APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
      AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${toLower(StorageAccountName)};AccountKey=${listKeys(storageAccount.id, \'2019-06-01\').keys[0].value};EndpointSuffix=core.windows.net'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${toLower(StorageAccountName)};AccountKey=${listKeys(storageAccount.id, \'2019-06-01\').keys[0].value};EndpointSuffix=core.windows.net'
      WEBSITE_CONTENTSHARE: toLower(FunctionName)
      WEBSITE_RUN_FROM_PACKAGE: 'https://github.com/Yaniv-Shasha/SecurityCopilot/blob/main/Solutions/Userreportedphishingv2/parseemail.zip?raw=true'
    }
  }
}
  
resource functionapp_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2018-02-01' = {
  parent: functionapp_resource
  name: 'ftp'
  location: resourceGroup().location
  dependsOn: [
    functionapp_resource  
  ]
  tags: {
    'hidden-link: /app-insights-resource-id': appInsights.id
 }
  properties: {
    allow: true
  }
}

resource basicPublishingCredentialsPoliciesScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2018-02-01' = {
  parent: functionapp_resource
  name: 'scm'
  location: resourceGroup().location
  tags: {
    'hidden-link: /app-insights-resource-id': appInsights.id
  }
  properties: {
    allow: true
  }
}

resource functionapp_web 'Microsoft.Web/sites/config@2018-02-01' = {
  parent: functionapp_resource
  name: 'web'
  location: resourceGroup().location
  tags: {
    'hidden-link: /app-insights-resource-id': appInsights.id
  }
  properties: {
    numberOfWorkers: 1
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
    ]
    netFrameworkVersion: 'v4.0'
    linuxFxVersion: 'python|3.11'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    httpLoggingEnabled: false
    acrUseManagedIdentityCreds: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
    publishingUsername: '$${FunctionAppName}'
    scmType: 'None'
    use32BitWorkerProcess: false
    webSocketsEnabled: false
    alwaysOn: false
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: false
      }
    ]
    loadBalancing: 'LeastRequests'
    experiments: {
      rampUpRules: []
    }
    autoHealEnabled: false
    vnetRouteAllEnabled: false
    vnetPrivatePortsCount: 0
    localMySqlEnabled: false
    managedServiceIdentityId: 94581
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: false
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.2'
    ftpsState: 'FtpsOnly'
    preWarmedInstanceCount: 0
    functionAppScaleLimit: 200
    functionsRuntimeScaleMonitoringEnabled: false
    minimumElasticInstanceCount: 0
    azureStorageAccounts: {}
  }
}

resource functionapp_parse_email 'Microsoft.Web/sites/functions@2018-02-01' = {
  parent: functionapp_resource
  name: 'parse_email'
  location: resourceGroup().location
  properties: {
    script_root_path_href: 'https://${FunctionAppName}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_email/'
    script_href: 'https://${FunctionAppName}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_email/__init__.py'
    config_href: 'https://${FunctionAppName}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_email/function.json'
    test_data_href: 'https://${FunctionAppName}.azurewebsites.net/admin/vfs/tmp/FunctionsData/parse_email.dat'
    href: 'https://${FunctionAppName}.azurewebsites.net/admin/functions/parse_email'
    config: {
      bindings: [
        {
          authLevel: 'function'
          type: 'httpTrigger'
          direction: 'in'
          name: 'req'
          methods: [
            'post'
          ]
        }
        {
          type: 'http'
          direction: 'out'
          name: '$return'
        }
      ]
    }
    invoke_url_template: 'https://${FunctionAppName}.azurewebsites.net/api/parse_email'
    language: 'python'
    isDisabled: false
  }
}

resource functionapp_parse_virustotal_json 'Microsoft.Web/sites/functions@2018-02-01' = {
  parent: functionapp_resource
  name: 'parse_virustotal_json'
  location: resourceGroup().location
  properties: {
    script_root_path_href: 'https://${FunctionAppName}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_virustotal_json/'
    script_href: 'https://${FunctionAppName}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_virustotal_json/__init__.py'
    config_href: 'https://${FunctionAppName}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_virustotal_json/function.json'
    test_data_href: 'https://${FunctionAppName}.azurewebsites.net/admin/vfs/tmp/FunctionsData/parse_virustotal_json.dat'
    href: 'https://${FunctionAppName}.azurewebsites.net/admin/functions/parse_virustotal_json'
    config: {
      bindings: [
        {
          authLevel: 'function'
          type: 'httpTrigger'
          direction: 'in'
          name: 'req'
          methods: [
            'get'
            'post'
          ]
        }
        {
          type: 'http'
          direction: 'out'
          name: '$return'
        }
      ]
      scriptFile: '__init__.py'
    }
    invoke_url_template: 'https://${FunctionAppName}.azurewebsites.net/api/parse_virustotal_json'
    language: 'python'
    isDisabled: false
  }
}


resource functionapp_functionapp_azurewebsites_net 'Microsoft.Web/sites/hostNameBindings@2018-02-01' = {
  parent: functionapp_resource
  name: '${FunctionAppName}.azurewebsites.net'
  location: resourceGroup().location
  properties: {
    siteName: FunctionAppName
    hostNameType: 'Verified'
  }
}
