locals {
  la_name = format("%s%s", "${var.LOGIC_APP_NAME}", "${var.ENVIRONMENT}")
  rg_name = format("%s%s", "${var.RG_NAME}", "${var.ENVIRONMENT}")
}

terraform {
  required_version = "= 1.9.8"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.9.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-logicappghdeploy-eus"
    storage_account_name = "stterraformstateeus"
    container_name       = "tfstate"
    key                  = "tf-example" # can be anything
    use_oidc             = true # To use OIDC to authenticate to the backend
    client_id            = "9af55caa-2954-4505-b792-8b94027b1e39" # The client ID of the Managed Identity
    subscription_id      = "bc3ba08c-ec7c-49c9-b917-29f77a23a41b" # The subscription ID where the storage account exists
    tenant_id            = "595eb399-d3f9-418f-a37e-8f0d0b8b00a0" # The tenant ID where the subscription and the Managed Identity are
  }
}

provider "azurerm" {
  features {}

  use_oidc         = true # Use OIDC to authenticate to Azure
  subscription_id  = "${var.ARM_SUBSCRIPTION_ID}"
}

resource "azurerm_resource_group" "rg" {
    name     = local.rg_name
    location = "${var.RG_LOCATION}"
}

resource "azurerm_api_connection" "logic_app_api_connection" {
  managed_api_id      = "/subscriptions/${var.ARM_SUBSCRIPTION_ID}/providers/Microsoft.Web/locations/${var.RG_LOCATION}/managedApis/documentdb"
  name                = "documentdb"
  resource_group_name = local.rg_name

  depends_on = [
    azurerm_resource_group.rg,
  ]
}

resource "azurerm_logic_app_workflow" "logic_app_workflow" {
  location = "${var.RG_LOCATION}"
  name     = local.la_name
    parameters = {
    "$connections" = format("%s%s%s", "{\"documentdb\":{\"connectionId\":\"/subscriptions/${var.ARM_SUBSCRIPTION_ID}/resourceGroups/", local.rg_name, "/providers/Microsoft.Web/connections/documentdb\",\"connectionName\":\"documentdb\",\"id\":\"/subscriptions/${var.ARM_SUBSCRIPTION_ID}/providers/Microsoft.Web/locations/${var.RG_LOCATION}/managedApis/documentdb\"}}")
  }
  resource_group_name = local.rg_name
  workflow_parameters = {
    "$connections" = "{\"defaultValue\":{},\"type\":\"Object\"}"
  }
  depends_on = [
    azurerm_resource_group.rg,
    azurerm_api_connection.logic_app_api_connection,
  ]
}

resource "azurerm_logic_app_action_custom" "logic_app_cosmosdb_createorupdatedocumentv3" {
  body = jsonencode({
    inputs = {
      body = "@addProperty(triggerBody(), 'id', guid())"
      host = {
        connection = {
          name = "@parameters('$connections')['documentdb']['connectionId']"
        }
      }
      method = "post"
      path   = "/v2/cosmosdb/@{encodeURIComponent('${var.COSMOS_DB_ACCOUNT}')}/dbs/@{encodeURIComponent('${var.COSMOS_DB_DATABASE}')}/colls/@{encodeURIComponent('${var.COSMOS_DB_CONTAINER}')}/docs"
    }
    runAfter = {}
    type     = "ApiConnection"
  })
  logic_app_id = format("%s%s%s%s", "/subscriptions/${var.ARM_SUBSCRIPTION_ID}/resourceGroups/", local.rg_name, "/providers/Microsoft.Logic/workflows/", local.la_name)
  name         = "Create_or_update_document_(V3)"
  depends_on = [
    azurerm_logic_app_workflow.logic_app_workflow,
  ]
}

resource "azurerm_logic_app_trigger_http_request" "logic_app_trigger_http_request" {
  logic_app_id = format("%s%s%s%s", "/subscriptions/${var.ARM_SUBSCRIPTION_ID}/resourceGroups/", local.rg_name, "/providers/Microsoft.Logic/workflows/", local.la_name)
  method       = "POST"
  name         = "When_a_HTTP_request_is_received"
  schema = jsonencode({
    properties = {
      alarm_detail = {
        items = {
          type = "string"
        }
        type = "array"
      }
      alarm_name = {
        type = "string"
      }
      alarm_status = {
        type = "string"
      }
      alarm_value = {
        type = "string"
      }
      alarm_value_unit = {
        type = "string"
      }
      device_ip = {
        type = "string"
      }
      device_name = {
        type = "string"
      }
      environment = {
        type = "string"
      }
      gateway_ip = {
        type = "string"
      }
      gateway_name = {
        type = "string"
      }
      message_type = {
        type = "string"
      }
      source = {
        type = "string"
      }
      timestamp = {
        type = "string"
      }
    }
    type = "object"
  })
  depends_on = [
    azurerm_logic_app_workflow.logic_app_workflow,    
  ]
}

output "debug_logic_app_name" {
  value = local.la_name
}

output "debug_rg_name" {
  value = local.rg_name
}