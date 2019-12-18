output "rgName" {
  value = "${azurerm_resource_group.genericRG.name}"
}

output "storageAccountName" {
  value = "${azurerm_storage_account.genericSA.name}"
}

output "storageAccountConnectionString" {
  value = "${azurerm_storage_account.genericSA.primary_connection_string}"
}

output "containerName" {
  value = "${azurerm_storage_container.container.name}"
}


output "edgeNode" {
  value = "${lookup(azurerm_template_deployment.edgeNode.outputs, "applicationName")}"
}
/*
output "edge_ssh_endpoint" {
  value = "${azurerm_hdinsight_kafka_cluster.cluster.edge_ssh_endpoint}"
}*/

output "https_endpoint" {
  value = "${azurerm_hdinsight_kafka_cluster.cluster.https_endpoint}"
}

output "ssh_endpoint" {
  value = "${azurerm_hdinsight_kafka_cluster.cluster.ssh_endpoint}"
}

output "subnets" {
  value = {
    for subnet in azurerm_subnet.subnets :
    subnet.name => subnet.address_prefix
  }
}

output "dataBricksSubnets" {
  value = {
    for subnet in azurerm_subnet.dbSubnets :
    subnet.name => subnet.address_prefix
  }
}
