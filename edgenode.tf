resource "azurerm_template_deployment" "edgeNode" {
  name                = "${var.suffix}_edgeNode"
  resource_group_name = azurerm_resource_group.genericRG.name

  template_body = file("edgenode.json")

  # these key-value pairs are passed into the ARM Template's `parameters` block
  parameters = {
    "clusterName" = "${azurerm_hdinsight_kafka_cluster.cluster.name}"
  }

  deployment_mode = "Incremental"

}
