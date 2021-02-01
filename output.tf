
output "amsv3function_id" {
  value = azurerm_template_deployment.advanced_workflow_01.outputs.function_app_id
}

/*
output "publish_callback_url" {
  value = azurerm_template_deployment.publish_workflow_01.outputs.endpointUrl
}


output "function_hostname" {
  value = azurerm_function_app.example.default_hostname 
}

output "access_endpoint" {
  value = azurerm_logic_app_workflow.telegram.access_endpoint 
}

output "customConnector_connector_id" {
  value = azurerm_template_deployment.custom_connector.outputs.connection_id
}

output "customConnector_customApi_id" {
  value = azurerm_template_deployment.custom_connector.outputs.customApi_id
}

output "customConnector_name" {
  value = azurerm_template_deployment.custom_connector.outputs.connector_name
}

output "logicApp_managed_identity" {
  value = module.telegram-connector.logicApp_managed_identity
}

output "logicApp_https_url" {
  value = module.telegram-connector.logicApp_https_url
}
*/


