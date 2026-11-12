# hyperforge-bakery

Golden images for HyperForge: Packer-built host AMIs, plus the
upload/promotion flow for lab guest images.

## Host AMIs (`packer/`)

| Build | Base | What's baked in | Build instance |
|-------|------|-----------------|----------------|
| `kvm-host` | Ubuntu 24.04 | qemu-kvm, libvirt, virt-install, awscli | `c6i.2xlarge` (cheap — nested virt not needed at bake time) |
| `hyperv-host` | Windows Server 2022 | Hyper-V role (verified post-reboot), AWS.Tools.S3 | `m6i.metal` (role install needs real VT-x) |

```sh
cd packer/kvm-host && packer init . && packer build .
cd packer/hyperv-host && packer init . && packer build .   # ~30+ min, metal
```

Rebuild only when the base OS or tooling changes — runtime config lives in
cloud-init/userdata in `hyperforge-core`, so routine changes don't need a
re-bake.

## Lab guest images (`scripts/`)

Export the guest VM from the lab, then upload + promote:

```sh
# KVM lab: qemu-img convert -O qcow2 disk.img lab-guest.qcow2
# HPE VME: export via VME; it's KVM underneath, qcow2 works
# Hyper-V lab: Export-VM, take the .vhdx
./scripts/upload-lab-image.sh lab-guest.qcow2 kvm
./scripts/upload-lab-image.sh lab-guest.qcow2 vme
./scripts/upload-lab-image.sh lab-guest.vhdx  hyperv
```

Images are content-addressed by sha256 under `golden/<leg>/`, with a
`latest.txt` pointer the pipeline resolves at run time. Promoting a new image
is just re-running the script; rolling back is rewriting the pointer to an
older sha — old images are never overwritten.
