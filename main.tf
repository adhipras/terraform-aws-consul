################################################################################
# Cloud Provider
################################################################################

provider "aws" {
  shared_credentials_file = var.credentials
  region                  = var.region
}

################################################################################
# Availability Zones
################################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

################################################################################
# Private Subnetwork(s)
################################################################################

resource "aws_subnet" "private" {
  depends_on        = [aws_vpc.vpc]
  count             = length(var.private_subnetwork_cidr)
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = var.private_subnetwork_cidr[count.index]

  tags = {
    Name = "${var.prefix}-subnet-private-${var.map_to_zone[count.index]}"
  }
}

################################################################################
# Public Subnetwork(s)
################################################################################

resource "aws_subnet" "public" {
  depends_on              = [aws_vpc.vpc]
  count                   = length(var.public_subnetwork_cidr)
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = var.public_subnetwork_cidr[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-public-${var.map_to_zone[count.index]}"
  }
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "internet_gateway" {
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = "${var.prefix}-vpc-internet-gateway"
  }
}

resource "aws_route_table" "internet" {
  depends_on = [aws_internet_gateway.internet_gateway]
  vpc_id     = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.prefix}-route-internet"
  }
}

resource "aws_route_table_association" "internet" {
  depends_on     = [aws_route_table.internet]
  count          = length(aws_subnet.public)
  route_table_id = aws_route_table.internet.id
  subnet_id      = aws_subnet.public[count.index].id
}

################################################################################
# NAT Gateways
################################################################################

resource "aws_eip" "nat_gateway" {
  depends_on = [aws_internet_gateway.internet_gateway]
  count      = length(aws_subnet.public)
  vpc        = true

  tags = {
    Name = "${var.prefix}-eip-nat-${var.map_to_zone[count.index]}"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_eip.nat_gateway]
  count         = length(aws_subnet.public)
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.nat_gateway.*.id, count.index)

  tags = {
    Name = "${var.prefix}-nat-gateway-${var.map_to_zone[count.index]}"
  }
}

resource "aws_route_table" "nat" {
  depends_on = [aws_nat_gateway.nat_gateway]
  count      = length(aws_nat_gateway.nat_gateway)
  vpc_id     = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }

  tags = {
    Name = "${var.prefix}-route-nat-${var.map_to_zone[count.index]}"
  }
}

resource "aws_route_table_association" "nat" {
  depends_on     = [aws_route_table.nat]
  count          = length(aws_route_table.nat)
  route_table_id = aws_route_table.nat[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}

################################################################################
# Security Groups
################################################################################

resource "aws_security_group" "ssh_public" {
  name        = "${var.prefix}-sg-ssh-public"
  description = "Allow SSH inbound traffic."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH from public network."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssh_private" {
  name        = "${var.prefix}-sg-ssh-private"
  description = "Allow SSH inbound traffic."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH to private network."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.public_subnetwork_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# AWS AMI
################################################################################

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################################################################
# AWS EC2 Bastion Instance Template
################################################################################

resource "aws_launch_configuration" "bastion" {
  name_prefix            = "${var.prefix}-bastion-template-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  security_groups        = [aws_security_group.ssh_public.id]
  key_name               = var.ssh_key_name

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# AWS Bastion Autoscalling Group
################################################################################

resource "aws_autoscaling_group" "bastion" {
  launch_configuration = aws_launch_configuration.bastion.name
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1

  vpc_zone_identifier  = [
    aws_subnet.public[0].id,
    aws_subnet.public[1].id,
    aws_subnet.public[2].id
  ]

  tag {
    key                 = "Name"
    value               = "${var.prefix}-bastion-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}