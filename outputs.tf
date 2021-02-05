output "consul_url" {
  value = "http://${aws_elb.consul.dns_name}/ui"
}

output "bastion_public_ip" {
  value = aws_instance.bastion.*.public_ip
}

output "consul_private_ip" {
  value = aws_instance.consul.*.private_ip
}