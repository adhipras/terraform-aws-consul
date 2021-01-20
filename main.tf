################################################################################
# Cloud Provider
################################################################################

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
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
# Private Subnetworks
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
# Public Subnetworks
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

resource "aws_internet_gateway" "internet" {
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id

  tags = {
    Name = "${var.prefix}-vpc-internet-gateway"
  }
}

resource "aws_route_table" "internet" {
  depends_on = [aws_internet_gateway.internet]
  vpc_id     = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet.id
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

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.internet]
  count      = length(aws_subnet.public)
  vpc        = true

  tags = {
    Name = "${var.prefix}-eip-nat-${var.map_to_zone[count.index]}"
  }
}

resource "aws_nat_gateway" "nat" {
  depends_on    = [aws_eip.nat]
  count         = length(aws_subnet.public)
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.nat.*.id, count.index)

  tags = {
    Name = "${var.prefix}-nat-${var.map_to_zone[count.index]}"
  }
}

resource "aws_route_table" "nat" {
  depends_on = [aws_nat_gateway.nat]
  count      = length(aws_nat_gateway.nat)
  vpc_id     = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
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
# Ubuntu AMI
################################################################################

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

################################################################################
# Bastion Security Group
################################################################################

resource "aws_security_group" "bastion" {
  name        = "${var.prefix}-sg-bastion"
  description = "Allow SSH inbound traffic."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH from the Internet."
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

################################################################################
# Bastion Host Instances
################################################################################

resource "aws_instance" "bastion" {
  depends_on             = [aws_security_group.bastion]
  count                  = length(var.public_subnetwork_cidr)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = var.ssh_key_name

  tags = {
    Name   = "${var.prefix}-bastion-host-${count.index + 1}"
  }
}

################################################################################
# SSH Security Group
################################################################################

resource "aws_security_group" "ssh" {
  depends_on  = [aws_instance.bastion]
  name        = "${var.prefix}-sg-ssh"
  description = "Allow SSH inbound traffic."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "SSH from Bastion host(s)."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = formatlist("%s%s", aws_instance.bastion.*.private_ip, "/32")
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# Consul Security Group
################################################################################

resource "aws_security_group" "consul" {
  name        = "${var.prefix}-sg-consul"
  description = "Allow inbound traffic to Consul instances."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Consul RPC."
    from_port   = var.consul_rpc_port
    to_port     = var.consul_rpc_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnetwork_cidr
  }

  ingress {
    description = "Consul Serf LAN (TCP)."
    from_port   = var.consul_serf_lan_port
    to_port     = var.consul_serf_lan_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnetwork_cidr
  }

  ingress {
    description = "Consul Serf LAN (UDP)."
    from_port   = var.consul_serf_lan_port
    to_port     = var.consul_serf_lan_port
    protocol    = "udp"
    cidr_blocks = var.private_subnetwork_cidr
  }

  ingress {
    description = "Consul Serf WAN (TCP)."
    from_port   = var.consul_serf_wan_port
    to_port     = var.consul_serf_wan_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnetwork_cidr
  }

  ingress {
    description = "Consul Serf WAN (UDP)."
    from_port   = var.consul_serf_wan_port
    to_port     = var.consul_serf_wan_port
    protocol    = "udp"
    cidr_blocks = var.private_subnetwork_cidr
  }

  ingress {
    description = "Consul UI (HTTP)."
    from_port   = var.consul_ui_http_port
    to_port     = var.consul_ui_http_port
    protocol    = "tcp"
    cidr_blocks = var.public_subnetwork_cidr
  }

  ingress {
    description = "Consul DNS (TCP)."
    from_port   = var.consul_dns_port
    to_port     = var.consul_dns_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnetwork_cidr
  }

  ingress {
    description = "Consul DNS (UDP)."
    from_port   = var.consul_dns_port
    to_port     = var.consul_dns_port
    protocol    = "udp"
    cidr_blocks = var.private_subnetwork_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

################################################################################
# Consul Instances
################################################################################

resource "aws_instance" "consul" {
  depends_on             = [aws_instance.bastion, aws_nat_gateway.nat, aws_route_table.nat, aws_route_table_association.nat]
  count                  = var.consul_server_nodes
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.consul_instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.consul.id]
  key_name               = var.ssh_key_name

  root_block_device {
    volume_size = 50
  }

  tags = {
    Name       = "${var.prefix}-consul-server-${count.index + 1}"
    ConsulRole = var.consul_tag_value
  }

  connection {
    type         = "ssh"
    bastion_host = aws_instance.bastion[count.index].public_ip
    host         = self.private_ip
    user         = "ubuntu"
    private_key  = file(var.private_key)
  }

  provisioner "file" {
    source      = "consul.sh"
    destination = "/tmp/consul.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/consul.sh",
      "/tmp/consul.sh ${var.access_key} ${var.secret_key} ${var.region} ${var.consul_server_nodes} ${self.private_ip} ${var.prefix}-consul-server-${count.index + 1} ${var.consul_tag_key} ${var.consul_tag_value}"
    ]
  }
}

################################################################################
# Consul Elastic Load Balancer Security Group
################################################################################

resource "aws_security_group" "elb_consul" {
  name        = "${var.prefix}-sg-elb-consul"
  description = "Allow HTTP inbound traffic."
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "HTTP from the Internet."
    from_port   = 80
    to_port     = 80
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

################################################################################
# Consul Elastic Load Balancer
################################################################################

resource "aws_elb" "consul" {
  depends_on      = [aws_instance.consul]
  name            = "${var.prefix}-elb-consul"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.elb_consul.id]
  instances       = aws_instance.consul.*.id

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = var.consul_ui_http_port
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:8500/v1/status/leader"
    interval            = 30
  }

  tags = {
    Name = "${var.prefix}-elb-consul"
  }
}