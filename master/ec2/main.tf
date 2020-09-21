
data "terraform_remote_state" "vault" {
  backend = ""
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create AWS EC2 Instance
resource "aws_instance" "this" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  key_name = var.key_name

  tags = {
    Name  =  var.name
    TTL   =  var.ttl
    owner =  "${var.name}-guide"
  }
}

module "ansible" {
  source           = "github.com/insight-infrastructure/terraform-aws-ansible-playbook.git?ref=v0.11.0"
  ip               = join("", aws_instance.this.*.public_ip)
  user             = "ubuntu"

  private_key_path = var.private_key_path

  playbook_file_path = "${path.module}/ansible/main.yml"
  playbook_vars = {
    local_build = var.cachet_local_build
    db_username = var.db_username
    db_password = var.db_password
    db_host     = var.db_host
    fqdn        = local.fqdn
    env_file    = var.env_file == "" ? "${path.module}/config.env.defaults" : var.env_file
  }

  requirements_file_path = "${path.module}/ansible/requirements.yml"

  module_depends_on = [join("", aws_route53_record.this.*.id)]
}