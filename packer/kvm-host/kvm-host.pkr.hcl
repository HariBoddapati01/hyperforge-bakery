packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

# The build itself can run on a cheap non-metal instance; nested virt is only
# needed at test runtime (on .metal), not at bake time.
variable "build_instance_type" {
  type    = string
  default = "c6i.2xlarge"
}

source "amazon-ebs" "kvm_host" {
  region        = var.aws_region
  instance_type = var.build_instance_type
  ssh_username  = "ubuntu"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }

  ami_name = "hv-testbed-kvm-host-{{timestamp}}"

  tags = {
    project = "hv-testbed"
    role    = "kvm-host"
  }
}

build {
  sources = ["source.amazon-ebs.kvm_host"]

  provisioner "shell" {
    script = "${path.root}/provision.sh"
  }
}
