################################################################################
# Credentials
################################################################################

variable "access_key" {
  description = "The Amazon Web Service access key."
  type        = string
}

variable "secret_key" {
  description = "The Amazon Web Service secret key."
  type        = string
}

################################################################################
# Region
################################################################################

variable "region" {
  description = "The Amazon Web Service region."
  type        = string
  default     = "ap-southeast-1"
}

################################################################################
# Prefix
################################################################################

variable "prefix" {
  description = "The affix attached to the beginning of the resource name."
  type        = string
  default     = "aws"
}

################################################################################
# Map Index to Zone
################################################################################

variable "map_to_zone" {
  description = "Map count.index number to availability zone suffix."
  type        = map(string)
  default     = {
    "0" = "a",
    "1" = "b",
    "2" = "c"
  }
}

################################################################################
# VPC
################################################################################

variable "vpc_cidr" {
  description = "The CIDR of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

################################################################################
# Private Subnetwork(s)
################################################################################

variable "private_subnetwork_cidr" {
  description = "The list of private subnetwork(s) to create in CIDR block format."
  type        = list(string)
  default     = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
}

################################################################################
# Public Subnetwork(s)
################################################################################

variable "public_subnetwork_cidr" {
  description = "The list of public subnetwork(s) to create in CIDR block format."
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
}

################################################################################
# SSH
################################################################################

variable "ssh_port" {
  description = "The port number for SSH access."
  type        = number
  default     = 22
}

variable "ssh_key_name" {
  description = "The Amazon Web Service key pair to use for resource."
  type        = string
  default     = "aws-quickstart-consul"
}

variable "private_key" {
  description = "SSH key to use for the connection."
  type        = string
  sensitive   = true
  default     = "aws-quickstart-consul.pem"
}

################################################################################
# Bastion
################################################################################

variable "bastion_hosts_min" {
  description = "The minimum number of Bastion hosts that will be created."
  type        = number
  default     = 1
}

variable "bastion_hosts" {
  description = "The number of Bastion hosts that will be created."
  type        = number
  default     = 1
}

variable "bastion_hosts_max" {
  description = "The maxmum number of bastion hosts that will be created."
  type        = number
  default     = 3
}

variable "bastion_instance_type" {
  description = "The type of Bastion instance(s)."
  type        = string
  default     = "t3.micro"
}

################################################################################
# Consul
################################################################################

variable "consul_server_nodes" {
  description = "The number of Consul server nodes that will be created. You can choose 3, 5, or 7 nodes."
  type        = number
  default     = 3
}

variable "consul_instance_type" {
  description = "The type of Consul instance(s)."
  type        = string
  default     = "m5.large"
}

variable "consul_rpc_port" {
  description = "The port number for Consul RPC address."
  type        = number
  default     = 8300
}

variable "consul_serf_lan_port" {
  description = "The port number for Consul Serf LAN."
  type        = number
  default     = 8301
}

variable "consul_serf_wan_port" {
  description = "The port number for Consul Serf WAN."
  type        = number
  default     = 8302
}

variable "consul_ui_http_port" {
  description = "The port number for Consul UI (HTTP)."
  type        = number
  default     = 8500
}

variable "consul_ui_https_port" {
  description = "The port number for Consul UI (HTTPS)."
  type        = number
  default     = 8501
}

variable "consul_grpc_api_port" {
  description = "The port number for Consul gRPC API."
  type        = number
  default     = 8502
}

variable "consul_dns_port" {
  description = "The port number for Consul DNS server."
  type        = number
  default     = 8600
}

variable "consul_tag_key" {
  description = "The key of the tag to auto-join Consul cluster on."
  type        = string
  default     = "ConsulRole"
}

variable "consul_tag_value" {
  description = "The value of the tag to auto-join Consul cluster on."
  type        = string
  default     = "Server"
}