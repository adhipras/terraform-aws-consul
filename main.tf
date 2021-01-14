################################################################################
# Cloud Provider
################################################################################

provider "aws" {
  shared_credentials_file = var.credentials
  region                  = var.region
}

################################################################################
# Availability Zones Data Source
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

################################################################################
# Private Subnetworks
################################################################################

resource "aws_subnet" "private" {
  count             = var.cluster_size
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.private_subnetworks_cidr[count.index]

  tags = {
    Name = "${var.prefix}-subnet-private-${var.map_to_zone[count.index]}"
  }
}

################################################################################
# Public Subnetworks
################################################################################

resource "aws_subnet" "public" {
  count                   = var.cluster_size
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = var.public_subnetworks_cidr[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-public-${var.map_to_zone[count.index]}"
  }
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.prefix}-vpc-internet-gateway"
  }
}

################################################################################
# Elastic IP Addresses
################################################################################

resource "aws_eip" "nat_gateway" {
  depends_on = [aws_internet_gateway.internet_gateway]
  count      = var.cluster_size
  vpc        = true

  tags = {
    Name = "${var.prefix}-eip-nat-${var.map_to_zone[count.index]}"
  }
}

################################################################################
# NAT Gateways
################################################################################

resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_internet_gateway.internet_gateway]
  count         = var.cluster_size
  allocation_id = element(aws_eip.nat_gateway.*.id, count.index)
  subnet_id     = element(aws_subnet.public.*.id, count.index)

  tags = {
    Name = "${var.prefix}-nat-gateway-${var.map_to_zone[count.index]}"
  }
}