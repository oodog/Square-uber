// Azure Container Apps deployment - cheapest option (~$0-5/month on consumption plan)
// Deploy with: bash azure/deploy.sh

param location string = 'australiaeast'
param appName string = 'mangkok-menu-sync'
param containerImage string
param acrName string = 'mangkokcr'
param nextauthUrl string = 'https://square.mangkokavenue.com'

@secure()
param nextauthSecret string

@secure()
param googleClientId string = ''

@secure()
param googleClientSecret string = ''

@secure()
param githubClientSecret string = ''

// Existing ACR (created by deploy.sh step 3)
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// Container Apps Environment (shared, free tier)
resource environment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: '${appName}-env'
  location: location
  properties: {}  // No log analytics config = free tier defaults
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: appName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
        transport: 'http'
        // Custom domain: app.mangkokavenue.com
      }
      secrets: [
        { name: 'nextauth-secret', value: nextauthSecret }
        { name: 'google-client-id', value: googleClientId }
        { name: 'google-client-secret', value: googleClientSecret }
        { name: 'github-client-secret', value: githubClientSecret }
        { name: 'acr-password', value: acr.listCredentials().passwords[0].value }
      ]
      registries: [
        {
          server: '${acrName}.azurecr.io'
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: appName
          image: containerImage
          resources: {
            cpu: json('0.25')   // Minimum CPU - cheapest
            memory: '0.5Gi'    // Minimum memory - cheapest
          }
          env: [
            { name: 'NODE_ENV', value: 'production' }
            { name: 'DATABASE_URL', value: 'file:./prisma/data/prod.db' }
            { name: 'NEXTAUTH_URL', value: nextauthUrl }
            { name: 'UBER_REDIRECT_URI', value: '${nextauthUrl}/uber-redirect/' }
            { name: 'NEXTAUTH_SECRET', secretRef: 'nextauth-secret' }
            { name: 'GOOGLE_CLIENT_ID', secretRef: 'google-client-id' }
            { name: 'GOOGLE_CLIENT_SECRET', secretRef: 'google-client-secret' }
            { name: 'GITHUB_CLIENT_SECRET', secretRef: 'github-client-secret' }
          ]
          volumeMounts: [
            { volumeName: 'sqlite-vol', mountPath: '/app/prisma/data' }  // matches DATABASE_URL file:./prisma/data/prod.db
          ]
        }
      ]
      scale: {
        minReplicas: 1   // Always-on = no cold-start stream timeout
        maxReplicas: 1
        rules: [
          {
            name: 'http-rule'
            http: { metadata: { concurrentRequests: '10' } }
          }
        ]
      }
      volumes: [
        {
          name: 'sqlite-vol'
          storageType: 'EmptyDir'  // Note: Use Azure Files for persistence in prod
        }
      ]
    }
  }
}

output appUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
