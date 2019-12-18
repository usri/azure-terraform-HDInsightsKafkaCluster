resource "azurerm_hdinsight_kafka_cluster" "cluster" {
  name                = lower("${var.suffix}swimhdinsightskafka")
  resource_group_name = azurerm_resource_group.genericRG.name
  location            = azurerm_resource_group.genericRG.location
  cluster_version     = var.clusterVersion
  tier                = var.tier

  component_version {
    kafka = var.kafkaVersion
  }

  gateway {
    enabled  = true
    username = var.webAdmin
    password = var.webAdminPassword
  }

  storage_account {
    storage_container_id = azurerm_storage_container.container.id
    storage_account_key  = azurerm_storage_account.genericSA.primary_access_key
    is_default           = true
  }

  roles {
    head_node {
      vm_size  = var.VMSize
      username = var.userName
      ssh_keys = [file(var.sshKeyPath)]

      virtual_network_id = azurerm_virtual_network.genericVNet.id
      subnet_id          = azurerm_subnet.subnets["headnodes"].id
    }

    worker_node {
      vm_size                  = var.VMSize
      username                 = var.userName
      ssh_keys                 = [file(var.sshKeyPath)]
      number_of_disks_per_node = var.numDisks
      target_instance_count    = var.targetNodeCount
      min_instance_count       = var.minNodeCount

      virtual_network_id = azurerm_virtual_network.genericVNet.id
      subnet_id          = azurerm_subnet.subnets["workers"].id
    }

    zookeeper_node {
      vm_size  = var.VMSize
      username = var.userName
      ssh_keys = [file(var.sshKeyPath)]

      virtual_network_id = azurerm_virtual_network.genericVNet.id
      subnet_id          = azurerm_subnet.subnets["zookeeper"].id
    }
  }

  lifecycle {
    ignore_changes = [roles]
  }

  tags = var.tags
}
