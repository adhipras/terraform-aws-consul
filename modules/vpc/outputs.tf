output "name" {
  description = "The name of the VPC specified as argument to this module."
  value       = var.name
}

output "id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}

output "arn" {
  description = "The Amazon Resource Name (ARN) of the VPC."
  value       = aws_vpc.this.arn
}

output "cidr_block" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}