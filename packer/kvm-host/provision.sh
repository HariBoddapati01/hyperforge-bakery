#!/usr/bin/env bash
# Bake the KVM/VME host AMI: hypervisor stack + tooling preinstalled so the
# ephemeral instance only has to pull the guest image and start it.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
# qemu-system-x86, not qemu-kvm: the latter is an ambiguous virtual package
# on Ubuntu 25.10+ and apt refuses to resolve it
sudo apt-get install -y \
  qemu-system-x86 \
  libvirt-daemon-system \
  libvirt-clients \
  virtinst \
  bridge-utils \
  cloud-image-utils \
  awscli \
  jq

# Default libvirt NAT network on at boot so virt-install works immediately.
sudo virsh net-autostart default || true

# NOTE: /dev/kvm will not exist on this (non-metal) build instance — that's
# expected. The test runtime uses .metal instances where KVM is native.
# Sanity-check the stack is installed rather than that KVM is usable here.
virsh --version
virt-install --version

echo "kvm-host provisioning complete"
