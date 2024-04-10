output "resource_group_name" {
  value = azurerm_resource_group.rg.name
  description = "Nazwa grupy zasobów."
}

output "resource_group_location" {
  value = azurerm_resource_group.rg.location
  description = "Lokalizacja grupy zasobów."
}

output "container_registry_login_server" {
  value = azurerm_container_registry.acr.login_server
  description = "Adres serwera logowania dla Azure Container Registry."
}

output "container_registry_name" {
  value = azurerm_container_registry.acr.name
  description = "Nazwa Azure Container Registry."
}

output "container_registry_admin_username" {
  value = azurerm_container_registry.acr.admin_username
  description = "Nazwa użytkownika admina dla Azure Container Registry (jeśli włączono)."
}

output "container_registry_admin_password" {
  value = azurerm_container_registry.acr.admin_password
  description = "Hasło admina dla Azure Container Registry (jeśli włączono)."
  sensitive = true
}

output "kubernetes_cluster_id" {
  value = azurerm_kubernetes_cluster.aks.id
  description = "ID klastra Kubernetes."
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
  description = "Nazwa klastra Kubernetes."
}

output "kubernetes_cluster_node_resource_group" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
  description = "Nazwa grupy zasobów dla węzłów klastra Kubernetes."
}

output "kubernetes_cluster_fqdn" {
  value = azurerm_kubernetes_cluster.aks.fqdn
  description = "Pełna nazwa domenowa (FQDN) klastra Kubernetes."
}


