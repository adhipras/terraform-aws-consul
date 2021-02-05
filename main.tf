#-------------------------------------------------------------------------------
# Cloud Provider
#-------------------------------------------------------------------------------

provider "aws" {
  region = var.region
}

#-------------------------------------------------------------------------------
# VPC
#-------------------------------------------------------------------------------

resource "aws_vpc" "consul" {
  cidr_block = var.vpc_cidr_block

  tags = {
    "Name" = "${var.prefix}-vpc"
  }
}

#-------------------------------------------------------------------------------
# Availability Zones
#-------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

#-------------------------------------------------------------------------------
# Private Subnetworks
#-------------------------------------------------------------------------------

resource "aws_subnet" "private" {
  depends_on              = [aws_vpc.consul]
  count                   = length(var.private_subnet_cidr_block)
  vpc_id                  = aws_vpc.consul.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = var.private_subnet_cidr_block[count.index]
  map_public_ip_on_launch = false

  tags = {
    "Name" = "${var.prefix}-subnet-private-${var.zone[count.index]}"
  }
}

#-------------------------------------------------------------------------------
# Public Subnetworks
#-------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  depends_on              = [aws_vpc.consul]
  count                   = length(var.public_subnet_cidr_block)
  vpc_id                  = aws_vpc.consul.id
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = var.public_subnet_cidr_block[count.index]
  map_public_ip_on_launch = true

  tags = {
    "Name" = "${var.prefix}-subnet-public-${var.zone[count.index]}"
  }
}

#-------------------------------------------------------------------------------
# Internet Gateway
#-------------------------------------------------------------------------------

resource "aws_internet_gateway" "internet" {
  depends_on = [aws_vpc.consul]
  vpc_id     = aws_vpc.consul.id

  tags = {
    Name = "${var.prefix}-vpc-internet-gateway"
  }
}

resource "aws_route_table" "internet" {
  depends_on = [aws_internet_gateway.internet]
  vpc_id     = aws_vpc.consul.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet.id
  }

  tags = {
    Name = "${var.prefix}-route-internet-gateway"
  }
}

resource "aws_route_table_association" "internet" {
  depends_on     = [aws_route_table.internet]
  count          = length(aws_subnet.public)
  route_table_id = aws_route_table.internet.id
  subnet_id      = aws_subnet.public[count.index].id
}

#-------------------------------------------------------------------------------
# NAT Gateways
#-------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.internet]
  count      = length(aws_subnet.public)
  vpc        = true

  tags = {
    Name = "${var.prefix}-eip-nat-${var.zone[count.index]}"
  }
}

resource "aws_nat_gateway" "nat" {
  depends_on    = [aws_eip.nat]
  count         = length(aws_subnet.public)
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id

  tags = {
    Name = "${var.prefix}-nat-${var.zone[count.index]}"
  }
}

resource "aws_route_table" "nat" {
  depends_on = [aws_nat_gateway.nat]
  count      = length(aws_nat_gateway.nat)
  vpc_id     = aws_vpc.consul.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "${var.prefix}-route-nat-${var.zone[count.index]}"
  }
}

resource "aws_route_table_association" "nat" {
  depends_on     = [aws_route_table.nat]
  count          = length(aws_route_table.nat)
  route_table_id = aws_route_table.nat[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}

#-------------------------------------------------------------------------------
# Ubuntu AMI
#-------------------------------------------------------------------------------

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

#-------------------------------------------------------------------------------
# SSH Key Pair
#-------------------------------------------------------------------------------

resource "aws_key_pair" "ssh" {
  key_name   = "${var.prefix}-ssh-key"
  public_key = file(var.ssh_public_key)
}

#-------------------------------------------------------------------------------
# Bastion Security Group
#-------------------------------------------------------------------------------

resource "aws_security_group" "bastion" {
  depends_on  = [aws_vpc.consul]
  name        = "${var.prefix}-sg-bastion"
  description = "Allow SSH inbound traffic."
  vpc_id      = aws_vpc.consul.id

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

#-------------------------------------------------------------------------------
# Bastion Host Instances
#-------------------------------------------------------------------------------

resource "aws_instance" "bastion" {
  depends_on             = [aws_security_group.bastion, aws_key_pair.ssh]
  count                  = length(aws_subnet.public)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion_instance_type
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name               = aws_key_pair.ssh.key_name

  tags = {
    Name   = "${var.prefix}-bastion-host-${count.index + 1}"
  }
}

#-------------------------------------------------------------------------------
# SSH Security Group
#-------------------------------------------------------------------------------

resource "aws_security_group" "ssh" {
  depends_on  = [aws_instance.bastion]
  name        = "${var.prefix}-sg-ssh"
  description = "Allow SSH inbound traffic."
  vpc_id      = aws_vpc.consul.id

  ingress {
    description = "SSH from Bastion host instance(s)."
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

#-------------------------------------------------------------------------------
# Consul IAM
#-------------------------------------------------------------------------------

resource "aws_iam_role" "consul" {
  name               = "${var.prefix}-auto-join"
  assume_role_policy = file("${path.module}/templates/assume-role.json")
}

resource "aws_iam_policy" "consul" {
  name        = "${var.prefix}-auto-join"
  description = "Allows Consul nodes to describe instances for joining."
  policy      = file("${path.module}/templates/describe-instances.json")
}

resource "aws_iam_policy_attachment" "consul" {
  name       = "${var.prefix}-auto-join"
  roles      = [aws_iam_role.consul.name]
  policy_arn = aws_iam_policy.consul.arn
}

resource "aws_iam_instance_profile" "consul" {
  name = "${var.prefix}-auto-join"
  role = aws_iam_role.consul.name
}

#-------------------------------------------------------------------------------
# Consul Security Group
#-------------------------------------------------------------------------------

resource "aws_security_group" "consul" {
  depends_on  = [aws_vpc.consul]
  name        = "${var.prefix}-sg-server"
  description = "Allow inbound traffic to Consul instances."
  vpc_id      = aws_vpc.consul.id

  ingress {
    description = "Consul RPC."
    from_port   = var.consul_rpc_port
    to_port     = var.consul_rpc_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidr_block
  }

  ingress {
    description = "Consul Serf LAN (TCP)."
    from_port   = var.consul_serf_lan_port
    to_port     = var.consul_serf_lan_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidr_block
  }

  ingress {
    description = "Consul Serf LAN (UDP)."
    from_port   = var.consul_serf_lan_port
    to_port     = var.consul_serf_lan_port
    protocol    = "udp"
    cidr_blocks = var.private_subnet_cidr_block
  }

  ingress {
    description = "Consul Serf WAN (TCP)."
    from_port   = var.consul_serf_wan_port
    to_port     = var.consul_serf_wan_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidr_block
  }

  ingress {
    description = "Consul Serf WAN (UDP)."
    from_port   = var.consul_serf_wan_port
    to_port     = var.consul_serf_wan_port
    protocol    = "udp"
    cidr_blocks = var.private_subnet_cidr_block
  }

  ingress {
    description = "Consul UI (HTTP)."
    from_port   = var.consul_ui_http_port
    to_port     = var.consul_ui_http_port
    protocol    = "tcp"
    cidr_blocks = var.public_subnet_cidr_block
  }

  ingress {
    description = "Consul DNS (TCP)."
    from_port   = var.consul_dns_port
    to_port     = var.consul_dns_port
    protocol    = "tcp"
    cidr_blocks = var.private_subnet_cidr_block
  }

  ingress {
    description = "Consul DNS (UDP)."
    from_port   = var.consul_dns_port
    to_port     = var.consul_dns_port
    protocol    = "udp"
    cidr_blocks = var.private_subnet_cidr_block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-------------------------------------------------------------------------------
# Consul Instances
#-------------------------------------------------------------------------------

resource "aws_instance" "consul" {
  depends_on             = [aws_instance.bastion, aws_nat_gateway.nat, aws_route_table.nat, aws_route_table_association.nat]
  count                  = var.consul_server_nodes
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.consul_instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.ssh.id, aws_security_group.consul.id]
  iam_instance_profile   = aws_iam_instance_profile.consul.name
  key_name               = aws_key_pair.ssh.key_name

  root_block_device {
    volume_size = 50
  }

  tags = map(
    "Name", "${var.prefix}-server-${count.index + 1}",
    var.consul_tag_key, var.consul_tag_value
  )

  connection {
    type         = "ssh"
    bastion_host = aws_instance.bastion[count.index].public_ip
    host         = self.private_ip
    user         = "ubuntu"
    private_key  = file(var.ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt install --yes software-properties-common",
      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo apt install --yes ansible"
    ]
  }

  provisioner "file" {
    source      = "ansible"
    destination = "/home/ubuntu"
  }

  provisioner "remote-exec" {
    inline = ["ansible-playbook /home/ubuntu/ansible/consul.yml --extra-vars \"consul_region=${var.region} consul_server_nodes=${var.consul_server_nodes} consul_server_address=${self.private_ip} consul_server_name=${var.prefix}-server-${count.index + 1} consul_tag_key=${var.consul_tag_key} consul_tag_value=${var.consul_tag_value}\""]
  }
}

#-------------------------------------------------------------------------------
# Consul Elastic Load Balancer Security Group
#-------------------------------------------------------------------------------

resource "aws_security_group" "elb" {
  depends_on  = [aws_vpc.consul]
  name        = "${var.prefix}-sg-elb"
  description = "Allow HTTP inbound traffic."
  vpc_id      = aws_vpc.consul.id

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

#-------------------------------------------------------------------------------
# Consul Elastic Load Balancer
#-------------------------------------------------------------------------------

resource "aws_elb" "consul" {
  depends_on      = [aws_instance.consul]
  name            = "${var.prefix}-elb"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.elb.id]
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
    Name = "${var.prefix}-elb"
  }
}