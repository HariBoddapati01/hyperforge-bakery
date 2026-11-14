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

# k3s install and manifest staging need no /dev/kvm, so the bake runs on a
# cheap non-metal instance; KubeVirt itself is applied at runtime on metal.
variable "build_instance_type" {
  type    = string
  default = "c6i.2xlarge"
}

variable "kubevirt_version" {
  type    = string
  default = "v1.6.0"
}

source "amazon-ebs" "kubevirt_host" {
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

  ami_name = "hyperforge-kubevirt-host-{{timestamp}}"

  tags = {
    project = "hyperforge"
    role    = "kubevirt-host"
  }
}

build {
  sources = ["source.amazon-ebs.kubevirt_host"]

  provisioner "shell" {
    environment_vars = ["KUBEVIRT_VERSION=${var.kubevirt_version}"]
    script           = "${path.root}/provision.sh"
  }
}
