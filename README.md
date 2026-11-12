# HyperForge · bakery

Golden images for [HyperForge](https://github.com/HariBoddapati01/hyperforge-core) — the ephemeral hypervisor
testbed that recreates lab VMs (KVM, Hyper-V, HPE VM Essentials) on AWS for
end-to-end product testing.

This repo bakes two kinds of images:

1. **Host AMIs** (Packer) — the hypervisor hosts themselves, with the full
   virtualization stack preinstalled so ephemeral instances boot straight into
   "pull guest, start guest".
2. **Lab guest images** (upload flow) — your actual lab VMs, exported once and
   promoted into S3 with content-addressed, rollback-friendly versioning.

## Host AMIs (`packer/`)

| Build | Base | Baked in | Build instance |
|-------|------|----------|----------------|
| `kvm-host` | Ubuntu 24.04 | qemu-kvm, libvirt, virt-install, awscli | `c6i.2xlarge` — cheap; nested virt is only needed at *runtime*, not bake time |
| `hyperv-host` | Windows Server 2022 | Hyper-V role (verified after reboot), AWS.Tools.S3 | `m6i.metal` — the role install itself requires real VT-x |

```sh
cd packer/kvm-host    && packer init . && packer build .
cd packer/hyperv-host && packer init . && packer build .   # ~30+ min, metal
```

AMIs are named `hyperforge-kvm-host-<timestamp>` /
`hyperforge-hyperv-host-<timestamp>`; the Terraform in hyperforge-core always
resolves the most recent. Rebuild only when the base OS or tooling changes —
per-run configuration lives in cloud-init/userdata in hyperforge-core, so
routine changes need no re-bake.

## Lab guest images (`scripts/`)

Export the guest VM from the lab, then upload and promote:

```sh
# KVM lab:    qemu-img convert -O qcow2 disk.img lab-guest.qcow2
# HPE VME:    export via VME — it's KVM underneath, qcow2 works as-is
# Hyper-V:    Export-VM, take the .vhdx
./scripts/upload-lab-image.sh lab-guest.qcow2 kvm
./scripts/upload-lab-image.sh lab-guest.qcow2 vme
./scripts/upload-lab-image.sh lab-guest.vhdx  hyperv
```

### Versioning model

```
s3://hyperforge-golden-images/
  golden/
    kvm/
      <sha256>.qcow2     immutable, content-addressed
      latest.txt         pointer the pipeline resolves at run time
    vme/    ...
    hyperv/ ...
```

- **Promote** = run the script (rewrites `latest.txt`).
- **Roll back** = rewrite `latest.txt` to an older sha; images are never
  overwritten or deleted by the tooling.
- **Reproduce** = any historical run's exact image is still addressable by sha.

## Status

- [x] Packer templates syntax-validated (`packer validate`)
- [x] Upload script shellcheck-clean
- [ ] First AMI bake pending AWS account setup
- [ ] First lab guest export pending
