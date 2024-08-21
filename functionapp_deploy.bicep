param resourceGroupName string
param sites_FunctionApp string
param location string

var subscriptionId = subscription().subscriptionId
var zipBlobUri = 'https://github.com/cd1zz/cfsphishing/raw/main/FunctionApp.zip'

// Optional: You can add more parameters if users need to customize these values
param appInsightsName string = '${sites_FunctionApp}-appInsights'
param serverFarmName string = '${sites_FunctionApp}-plan'

// Application Insights resource ID with subscriptionId
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
  tags: {
    'hidden-link: /app-insights-resource-id': '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Insights/components/${appInsightsName}'
  }
}

// App Service Plan (Server Farm)
resource serverFarm 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: serverFarmName
  location: location
  sku: {
    name: 'Y1' 
    tier: 'Dynamic'
    size: 'Y1'
  }
  properties: {
    reserved: true
  }
}

// Function App resource
resource sites_FunctionApp_resource 'Microsoft.Web/sites@2023-12-01' = {
  name: sites_FunctionApp
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    serverFarmId: serverFarm.id
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: 'python|3.11'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: zipBlobUri
        }
      ]
    }
    httpsOnly: true
  }
}

// FTP policies
resource sites_FunctionApp_ftp 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_FunctionApp_resource
  name: 'ftp'
  properties: {
    allow: true
  }
}

// SCM policies
resource sites_FunctionApp_scm 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-12-01' = {
  parent: sites_FunctionApp_resource
  name: 'scm'
  properties: {
    allow: true
  }
}

// Web configuration
resource sites_FunctionApp_web 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: sites_FunctionApp_resource
  name: 'web'
  properties: {
    numberOfWorkers: 1
    linuxFxVersion: 'python|3.11'
    ftpsState: 'FtpsOnly'
  }
}

// Function resources (parse_email)
resource sites_FunctionApp_parse_email 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_FunctionApp_resource
  name: 'parse_email'
  properties: {
    config: {
      bindings: [
        {
          authLevel: 'function'
          type: 'httpTrigger'
          direction: 'in'
          name: 'req'
          methods: ['post']
        }
        {
          type: 'http'
          direction: 'out'
          name: '$return'
        }
      ]
    }
    isDisabled: false
  }
}

// Function resources (parse_virustotal_json)
resource sites_FunctionApp_parse_virustotal_json 'Microsoft.Web/sites/functions@2023-12-01' = {
  parent: sites_FunctionApp_resource
  name: 'parse_virustotal_json'
  properties: {
    config: {
      bindings: [
        {
          authLevel: 'function'
          type: 'httpTrigger'
          direction: 'in'
          name: 'req'
          methods: ['get', 'post']
        }
        {
          type: 'http'
          direction: 'out'
          name: '$return'
        }
      ]
    }
    isDisabled: false
  }
}

// Hostname binding
resource hostNameBinding 'Microsoft.Web/sites/hostNameBindings@2023-12-01' = {
  parent: sites_FunctionApp_resource
  name: '${sites_FunctionApp}.azurewebsites.net'
  properties: {
    siteName: sites_FunctionApp
    hostNameType: 'Verified'
  }
}
