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

## License

[MIT License](https://opensource.org/licenses/MIT).

```
Copyright (c) 2021 Adhi Prasetia

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```