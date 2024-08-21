param functionapp string

var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var appserviceplan = '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Web/serverfarms/${functionapp}'

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${functionapp}-appinsights'
  location: resourceGroup().location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource functionapp_resource 'Microsoft.Web/sites@2023-12-01' = {
  name: functionapp
  location: resourceGroup().location
  tags: {
    'hidden-link: /app-insights-resource-id': appInsights.id
  }
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${functionapp}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${functionapp}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: appserviceplan
    reserved: true
    isXenon: false
    hyperV: false
    dnsConfiguration: {}
    vnetRouteAllEnabled: false
    vnetImagePullEnabled: false
    vnetContentShareEnabled: false
    siteConfig: {
      linuxFxVersion: 'python|3.11'  
      functionAppScaleLimit: 200  
      numberOfWorkers: 1  
      acrUseManagedIdentityCreds: false
      alwaysOn: false  
      http20Enabled: false
      minimumElasticInstanceCount: 0
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsights.properties.InstrumentationKey};IngestionEndpoint=https://${resourceGroup().location}-5.in.applicationinsights.azure.com/;LiveEndpoint=https://${resourceGroup().location}.livediagnostics.monitor.azure.com/'
        }
      ]
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    vnetBackupRestoreEnabled: false
    containerSize: 0
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    redundancyMode: 'None'
    storageAccountRequired: false
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
  dependsOn: [
    appInsights  // Ensures Application Insights is created before this Function App
  ]
}


resource functionapp_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: functionapp_resource
  name: 'ftp'
  location: resourceGroup().location
  dependsOn: [
    functionapp_resource  // Ensure this resource depends on the Function App being created first
  ]
  tags: {
    'hidden-link: /app-insights-resource-id': appInsights.id
 }
  properties: {
    allow: true
  }
}

resource basicPublishingCredentialsPoliciesScm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
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



resource functionapp_web 'Microsoft.Web/sites/config@2023-12-01' = {
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
    publishingUsername: '$${functionapp}'
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

resource functionapp_parse_email 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: functionapp_resource
  name: 'parse_email'
  location: resourceGroup().location
  properties: {
    script_root_path_href: 'https://${functionapp}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_email/'
    script_href: 'https://${functionapp}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_email/__init__.py'
    config_href: 'https://${functionapp}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_email/function.json'
    test_data_href: 'https://${functionapp}.azurewebsites.net/admin/vfs/tmp/FunctionsData/parse_email.dat'
    href: 'https://${functionapp}.azurewebsites.net/admin/functions/parse_email'
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
    invoke_url_template: 'https://${functionapp}.azurewebsites.net/api/parse_email'
    language: 'python'
    isDisabled: false
  }
}

resource functionapp_parse_virustotal_json 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: functionapp_resource
  name: 'parse_virustotal_json'
  location: resourceGroup().location
  properties: {
    script_root_path_href: 'https://${functionapp}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_virustotal_json/'
    script_href: 'https://${functionapp}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_virustotal_json/__init__.py'
    config_href: 'https://${functionapp}.azurewebsites.net/admin/vfs/home/site/wwwroot/parse_virustotal_json/function.json'
    test_data_href: 'https://${functionapp}.azurewebsites.net/admin/vfs/tmp/FunctionsData/parse_virustotal_json.dat'
    href: 'https://${functionapp}.azurewebsites.net/admin/functions/parse_virustotal_json'
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
    invoke_url_template: 'https://${functionapp}.azurewebsites.net/api/parse_virustotal_json'
    language: 'python'
    isDisabled: false
  }
}


resource functionapp_functionapp_azurewebsites_net 'Microsoft.Web/sites/hostNameBindings@2023-12-01' = {
  parent: functionapp_resource
  name: '${functionapp}.azurewebsites.net'
  location: resourceGroup().location
  properties: {
    siteName: functionapp
    hostNameType: 'Verified'
  }
}
