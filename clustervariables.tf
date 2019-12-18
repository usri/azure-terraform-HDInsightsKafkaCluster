variable "tier" {
  type        = string
  default     = "Standard"
  description = "HDInsight Cluster tier."
}

variable "clusterVersion" {
  type        = string
  default     = "4.0.1000.1"
  description = "Specifies the Version of HDInsights which should be used for this Cluster."
}

variable "kafkaVersion" {
  type        = string
  default     = "2.1"
  description = "Kafka version to use."
}

variable "webAdmin" {
  type        = string
  default     = "admin"
  description = "he username used for the Ambari Portal."
}

variable "webAdminPassword" {
  type        = string
  default     = "TerrAform123!"
  description = "WebAdmin password. It is recommended to use Environment variables to set this value. just set TF_VAR_webAdminPassword"
}

variable "VMSize" {
  type        = string
  default     = "Standard_D3_V2"
  description = "VM size to use in the cluster."
}

variable "userName" {
  type        = string
  default     = "acctestusrvm"
  description = "Username to use in order to access the Cluster using ssh."
}

variable "sshKeyPath" {
  type        = string
  default     = "~/.ssh/vm_ssh.pub"
  description = "Local SSH Key which should be used for the local administrator."
}

variable "numDisks" {
  type        = number
  default     = 3
  description = "The number of Data Disks which should be assigned to each Worker Node, which can be between 1 and 8. "
}

variable "targetNodeCount" {
  type        = number
  default     = 3
  description = "The number of instances which should be run for the Worker Nodes."
}

variable "minNodeCount" {
  type        = number
  default     = 1
  description = "The minimum number of instances which should be run for the Worker Nodes."
}
