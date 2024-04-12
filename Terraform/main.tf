locals {
  name = "rekrutacja"
  location = "westeurope"

  applicationGatewayIngressControllerEnabled = true
  monitoringEnabled = true

  acr = {
    SKU = "Basic"
    adminEnabled = true
  }

  AKS = {
    nodePool = {
      nodeCount = 1
      vmSize = "Standard_DS2_v2"
    }
    subnet = {
      cidr = "10.16.0.0/16"
    }
  }

  appgw = {
    subnet = {
      cidr = "10.17.0.0/24"
    }
  }

}

resource "random_string" "suffix" {
  length  = 6
  upper            = false  
  lower            = false  
  special          = false  
  override_special = "1234567890"   
}


resource "azurerm_resource_group" "rg" {
  name     = format("%s-rg", local.name)
  location = local.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = format("%s-vnet", local.name)
  address_space       = ["10.0.0.0/8"]
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "appgw" {
  count = local.applicationGatewayIngressControllerEnabled ? 1:0
  name                 = format("%s-appgw-subnet", local.name)
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.appgw.subnet.cidr]
}

resource "azurerm_subnet" "aks" {
  name                 = format("%s-aks-subnet", local.name)
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.AKS.subnet.cidr]
}

resource "azurerm_public_ip" "appgw" {
  count = local.applicationGatewayIngressControllerEnabled ? 1:0
  name                = format("%s-appgw-public-ip", local.name)
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = format("%sappgw", local.name)
}

resource "azurerm_application_gateway" "appgw" {
  count = local.applicationGatewayIngressControllerEnabled ? 1:0
  name                = format("%s-appgw", local.name)
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-configuration"
    subnet_id = azurerm_subnet.appgw[0].id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw[0].id
  }

  backend_address_pool {
    name = "appgw-backend-pool"
  }

  backend_http_settings {
    name                  = "appgw-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 20
  }

  http_listener {
    name                           = "appgw-http-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "appgw-rule"
    rule_type                  = "Basic"
    http_listener_name         = "appgw-http-listener"
    backend_address_pool_name  = "appgw-backend-pool"
    backend_http_settings_name = "appgw-http-settings"
    priority                   = 100
  }

}



resource "azurerm_container_registry" "acr" {
  name                = format("%s%s%s", local.name, "acr", random_string.suffix.result )
  resource_group_name = azurerm_resource_group.rg.name
  location            = local.location
  sku                 = local.acr.SKU
  admin_enabled       = local.acr.adminEnabled
}

resource "azurerm_log_analytics_workspace" "law" {
  count = local.monitoringEnabled ? 1:0
  name                = format("%s-law", local.name)
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}


# Tworzenie instancji Azure Container Instance
resource "azurerm_kubernetes_cluster" "aks" {
  name                = format("%s-aks", local.name)
  location            = local.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = format("%sClsuter", local.name)

  default_node_pool {
    name       = format("%s", local.name)
    node_count = local.AKS.nodePool.nodeCount
    vm_size    = local.AKS.nodePool.vmSize
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  identity {
    type = "SystemAssigned"
  }

  dynamic "ingress_application_gateway" {
    for_each = local.applicationGatewayIngressControllerEnabled ? [1] : []
    content {
      gateway_id = azurerm_application_gateway.appgw[0].id
    }
  }

  dynamic "oms_agent" {
    for_each = local.monitoringEnabled ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.law[0].id
    }
  }


}

resource "azurerm_role_assignment" "example" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "acr" {
  principal_id                     = "ddfd42e1-e9a2-44fb-aa12-036b044748d2"
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "appgw_reader" {
  count = local.applicationGatewayIngressControllerEnabled ? 1:0
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  role_definition_name = "Owner"
  scope                = azurerm_resource_group.rg.id
}

resource "azurerm_role_assignment" "appgw_contributor" {
  count = local.applicationGatewayIngressControllerEnabled ? 1:0
  principal_id         = azurerm_kubernetes_cluster.aks.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
  role_definition_name = "Owner"
  scope                = azurerm_application_gateway.appgw[0].id
}



