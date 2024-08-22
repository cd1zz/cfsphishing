param FunctionAppName string

var serverfarm_FunctionAppName = '${FunctionAppName}-app-service-plan'
var applicationInsightsName  = '${FunctionAppName}-app-insights'
var resourceGroupName  = resourceGroup().name
var subscriptionId  = subscription().subscriptionId
var appInsightsResourceId = resourceId('Microsoft.Insights/components', applicationInsightsName)
var appInsightsInstrumentationKey = applicationInsights.properties.InstrumentationKey
var appInsightsConnString = applicationInsights.properties.ConnectionString
var serverfarmid_appservice_plan = '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Web/serverfarms/${FunctionAppName}'

//App service plan
resource serverfarms_appserviceplan 'Microsoft.Web/serverfarms@2018-02-01' = {
  name: serverfarm_FunctionAppName
  location: resourceGroup().location
  kind: 'functionapp,linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
    perSiteScaling: false
    maximumElasticWorkerCount: 1
    isXenon: false
    hyperV: false
  }
  tags: {
    displayName: 'App Service Plan for ${FunctionAppName}'
  }
}

//App insights
resource applicationInsights 'Microsoft.Insights/components@2015-05-01' = {
  name: applicationInsightsName
  location: resourceGroup().location
  kind: 'web'
  dependsOn: [
    serverfarms_appserviceplan
  ]
  properties: {
    Application_Type: 'web'
  }
  tags: {
    displayName: 'Application Insights for Function App'
  }
}


resource FunctionAppName_resource 'Microsoft.Web/sites@2023-12-01' = {
  name: FunctionAppName
  location: resourceGroup().location
  dependsOn: [
    applicationInsights
  ]
  tags: {
    'hidden-link: /app-insights-resource-id': appInsightsResourceId
   }
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${FunctionAppName}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${FunctionAppName}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    serverFarmId: serverfarmid_appservice_plan
    reserved: true
    isXenon: false
    hyperV: false
    dnsConfiguration: {}
    vnetRouteAllEnabled: false
    vnetImagePullEnabled: false
    vnetContentShareEnabled: false
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: 'python|3.11'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(FunctionAppName)
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE' 
          value: 'https://github.com/cd1zz/cfsphishing/blob/main/FunctionApp.zip?raw=true'
        }
      ]
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      FunctionAppNameScaleLimit: 200
      minimumElasticInstanceCount: 0
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
}

resource FunctionAppName_web 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: FunctionAppName_resource
  name: 'web'
  location: resourceGroup().location
  dependsOn: [
    applicationInsights
  ]
  tags: {
    'hidden-link: /app-insights-resource-id': appInsightsResourceId
    'hidden-link: /app-insights-instrumentation-key': appInsightsInstrumentationKey
    'hidden-link: /app-insights-conn-string': appInsightsConnString
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
    FunctionAppNameScaleLimit: 200
    functionsRuntimeScaleMonitoringEnabled: false
    minimumElasticInstanceCount: 0
    azureStorageAccounts: {}
  }
}

resource FunctionAppName_parse_email 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: FunctionAppName_resource
  name: 'parse_email'
  location: resourceGroup().location
  dependsOn: [
    applicationInsights
  ]
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

resource FunctionAppName_parse_virustotal_json 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: FunctionAppName_resource
  name: 'parse_virustotal_json'
  location: resourceGroup().location
  dependsOn: [
    applicationInsights
  ]
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

resource FunctionAppName_FunctionAppName_azurewebsites_net 'Microsoft.Web/sites/hostNameBindings@2023-12-01' = {
  parent: FunctionAppName_resource
  name: '${FunctionAppName}.azurewebsites.net'
  dependsOn: [
    applicationInsights
  ]
  location: resourceGroup().location
  properties: {
    siteName: '${FunctionAppName}'
    hostNameType: 'Verified'
  }
}
