data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "DELETEME-AMSWORKFLOW-DEMO"
  location = "koreacentral"
}

resource "random_string" "random_postfix" {
    length  = 3
    upper   = false
    special = false
}

resource "azurerm_storage_account" "demo" {
  name                     = "demoamsaccount${random_string.random_postfix.result}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_media_services_account" "demo" {
  name                = "demoamsaccount${random_string.random_postfix.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  storage_account {
    id         = azurerm_storage_account.demo.id
    is_primary = true
  }
}


# Generate a random secret fo the service principal
resource "random_string" "secret" {
  length  = 32
  upper   = true
  special = true
  number  = true
}

# storage account for video upload
resource "azurerm_storage_account" "upload" {
  name                     = "mediauploadstore${random_string.random_postfix.result}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "mezzanine" {
  name                  = "mezzanine"
  storage_account_name  = azurerm_storage_account.upload.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "processed" {
  name                  = "mezzanine-processed"
  storage_account_name  = azurerm_storage_account.upload.name
  container_access_type = "private"
}


resource "azurerm_storage_container" "logs" {
  name                  = "mezzanine-processlogs"
  storage_account_name  = azurerm_storage_account.upload.name
  container_access_type = "private"
}

resource "azurerm_key_vault" "kv" {
  lifecycle {
    ignore_changes = [network_acls]
  }

  name                        = "keyvault${random_string.random_postfix.result}"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name

  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  network_acls {
    default_action            = "Allow" # for demo purpose only. not advised for production
    bypass                    = "AzureServices"
  }
}

# add this terraform to the key vault access policy to import certificate
resource "azurerm_key_vault_access_policy" "policy" {
  key_vault_id    = azurerm_key_vault.kv.id

  tenant_id       = data.azurerm_client_config.current.tenant_id
  object_id       = data.azurerm_client_config.current.object_id
  
  secret_permissions = [
    "get",
    "purge",
    "list",
    "set",
    "delete",
    "recover",
    "backup",
    "restore",
  ]
}

# this template deploys a function app along with app service plan and storage account.
#
resource "azurerm_template_deployment" "advanced_workflow_01" {
  name                  = "advanced_workflow_01"
  resource_group_name   = azurerm_resource_group.example.name

  template_body         = file("${path.cwd}/${var.function_advancedworkflow_template_path}")

  parameters = {
    "functionsAppName"        = var.function_app_name
    "functionKey"             = var.function_key
    "project"                 = var.project
    "sourceCodeRepositoryURL" = var.git_repository_url
    "sourceCodeBranch"        = "master"
    "mediaServicesAccountSubscriptionId"  = data.azurerm_client_config.current.subscription_id
    "mediaServicesAccountRegion"          = azurerm_media_services_account.demo.location
    "mediaServicesAccountResourceGroup"   = azurerm_media_services_account.demo.resource_group_name
    "mediaServicesAccountName"            = azurerm_media_services_account.demo.name
    "mediaServicesAccountAzureActiveDirectoryTenantId"  = data.azurerm_client_config.current.tenant_id

    # For demo only. Use Key Vault secret instead
    "mediaServicesAccountServicePrincipalClientId"      = var.client_id
    "mediaServicesAccountServicePrincipalClientSecret"  = var.client_secret
  }

  deployment_mode       = "Incremental"
}

resource "azurerm_template_deployment" "publish_workflow_02" {
  name                  = "mediaservices-publish_workflow_02"
  resource_group_name   = azurerm_resource_group.example.name

  template_body         = file("${path.cwd}/${var.logicapp_publishworkflow_template_path}")

  parameters = {
    "location"                = azurerm_resource_group.example.location
    "workflows_name"          = var.logicapp_publishworkflow_name
    "sites_amsv3functions_id" = azurerm_template_deployment.advanced_workflow_01.outputs.function_app_id
  }

  deployment_mode       = "Incremental"
}

# this template deploys a logic app for upload workflow
resource "azurerm_template_deployment" "logicapp_workflow_03" {
  name                  = "mediaservices-uploadworflow-03"
  resource_group_name   = azurerm_resource_group.example.name

  template_body         = file("${path.cwd}/${var.logicapp_uploadworkflow_template_path}")

  parameters = {
    "location"                = azurerm_resource_group.example.location
    "workflows_name"          = var.logicapp_uploadworkflow_name
    "sites_amsv3functions_id" = azurerm_template_deployment.advanced_workflow_01.outputs.function_app_id
    "azureBlobConnectionName" = "mediaupload-storage-connection"
    "azureBlobAccountName"    = azurerm_storage_account.upload.name
    "azureBlobAccessKey"      = azurerm_storage_account.upload.primary_access_key
    
    "mediaServiceStorageName"             = azurerm_storage_account.demo.name
    "mediaServiceAccountName"             = azurerm_media_services_account.demo.name
    "mediaServiceResourceGroupName"       = azurerm_media_services_account.demo.resource_group_name
  }

  deployment_mode       = "Incremental"
}



