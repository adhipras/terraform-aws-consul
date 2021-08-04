# HashiCorp's Consul Cluster Deployment on Amazon Web Service

[Terraform](https://www.terraform.io/) configuration files for deploying [HashiCorp](https://www.hashicorp.com/)'s [Consul](https://www.hashicorp.com/products/consul) cluster based on [Amazon Web Service](https://aws.amazon.com/)'s [Quick Start guidelines](https://aws.amazon.com/quickstart/architecture/consul/).

## Prerequisites

1. [Terraform](https://www.terraform.io/)
2. [Amazon Web Service account](https://aws.amazon.com/free/)
3. [Identity and Access Management (IAM) for your Terraform service account](https://blog.gruntwork.io/an-introduction-to-terraform-f17df9c6d180#a9b0)
4. [Amazon Web Service Command Line Interface (CLI)](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)

## Usage

1. Clone the Git repository.
```sh
$ git clone git@github.com:adhipras/terraform-aws-consul.git
```

2. Go to the `terraform-aws-consul` directory.
```sh
$ cd terraform-aws-consul
```

3. Execute the Terraform commands.
```sh
$ terraform init
$ terraform plan
$ terraform apply
```

## References

1. [Consul Deployment Guide](https://learn.hashicorp.com/tutorials/consul/deployment-guide?in=consul/production-deploy)
2. [Consul Auto-Join Example](https://github.com/hashicorp/consul-ec2-auto-join-example)