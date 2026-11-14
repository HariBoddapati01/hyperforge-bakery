#!/usr/bin/env bash
# Bake the KubeVirt host AMI: k3s installed and enabled, the pinned KubeVirt
# operator manifests and virtctl staged under /opt/hyperforge. The operator
# is NOT applied here — virt-handler needs /dev/kvm, which this non-metal
# build instance lacks; runtime cloud-init applies it on the metal host.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
KUBEVIRT_VERSION="${KUBEVIRT_VERSION:?set by packer}"

sudo apt-get update
sudo apt-get install -y curl jq awscli

# k3s — single-node, embedded containerd; disable traefik (unused).
curl -sfL https://get.k3s.io | sudo INSTALL_K3S_EXEC="--disable traefik" sh -

# Stage pinned KubeVirt artifacts for runtime apply.
sudo mkdir -p /opt/hyperforge
BASE="https://github.com/kubevirt/kubevirt/releases/download/$KUBEVIRT_VERSION"
sudo curl -fsSL "$BASE/kubevirt-operator.yaml" -o /opt/hyperforge/kubevirt-operator.yaml
sudo curl -fsSL "$BASE/kubevirt-cr.yaml"       -o /opt/hyperforge/kubevirt-cr.yaml
sudo curl -fsSL "$BASE/virtctl-$KUBEVIRT_VERSION-linux-amd64" -o /usr/local/bin/virtctl
sudo chmod +x /usr/local/bin/virtctl

# Sanity: k3s came up on the build box and the staged manifests parse.
sudo k3s kubectl get node
grep -q "kind: KubeVirt" /opt/hyperforge/kubevirt-cr.yaml
virtctl version --client

echo "kubevirt-host provisioning complete (KubeVirt $KUBEVIRT_VERSION staged)"
