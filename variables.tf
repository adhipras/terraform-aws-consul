################################################################################
# Credentials
################################################################################

variable "credentials" {
  description = "The path to the shared credentials file."
  type        = string
  default     = "$HOME/.aws/credentials"
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
  default     = "aws-quickstart-consul"
}

################################################################################
# Cluster Size
################################################################################

variable "cluster_size" {
  description = "The number of cluster(s) to create."
  type        = number
  default     = 3
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
# Private Subnetworks
################################################################################

variable "private_subnetworks_cidr" {
  description = "The list of private subnetworks to create in CIDR block format."
  type        = list(string)
  default     = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
}

################################################################################
# Public Subnetworks
################################################################################

variable "public_subnetworks_cidr" {
  description = "The list of public subnetworks to create in CIDR block format."
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
}