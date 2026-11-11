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

# Enabling the Hyper-V role requires real virtualization extensions, so the
# bake itself must run on a .metal instance (slow + pricey — rebuild this AMI
# rarely, only when the base image or tooling changes).
variable "build_instance_type" {
  type    = string
  default = "m6i.metal"
}

source "amazon-ebs" "hyperv_host" {
  region        = var.aws_region
  instance_type = var.build_instance_type

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_use_ssl  = true
  winrm_insecure = true

  source_ami_filter {
    filters = {
      name                = "Windows_Server-2022-English-Full-Base-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  user_data_file = "${path.root}/bootstrap-winrm.ps1"
  ami_name       = "hv-testbed-hyperv-host-{{timestamp}}"

  tags = {
    project = "hv-testbed"
    role    = "hyperv-host"
  }
}

build {
  sources = ["source.amazon-ebs.hyperv_host"]

  provisioner "powershell" {
    script = "${path.root}/provision.ps1"
  }

  # Hyper-V role install needs a reboot before the AMI is snapshotted.
  provisioner "windows-restart" {}

  provisioner "powershell" {
    inline = [
      "if ((Get-WindowsFeature Hyper-V).InstallState -ne 'Installed') { throw 'Hyper-V role not installed' }",
      "Write-Host 'Hyper-V role verified'",
    ]
  }
}
