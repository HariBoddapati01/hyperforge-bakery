# Baking hypervisor-product guest images (AHV/AOS, HPE VME)

The `ahv` and `vme` legs don't boot a plain OS guest — they boot the
hypervisor *product* itself as a nested VM, with the product's own guests one
level deeper. The expensive, interactive installer runs **once here at bake
time**; test runs always boot the already-installed golden qcow2.

```
metal host (kvm-host AMI, --cpu host-passthrough)
  ├─ vme: VME Manager appliance VM  +  HVM host VM (Ubuntu + VME agent)
  └─ ahv: Nutanix CE single-node VM (AHV + CVM)
```

Both installers are x86-only and sit behind logins, so the bake is a manual,
documented procedure on an x86 Linux box with KVM — a lab machine, or a
short-lived metal instance.

## Prerequisites

| Leg | Installer | Source |
|-----|-----------|--------|
| ahv | Nutanix Community Edition ISO | free Nutanix community account (next.nutanix.com) |
| vme | VME Manager appliance (qcow2/OVA) + host agent packages | HPE entitlement / 60-day eval |

## AHV/AOS (Nutanix CE single node)

```sh
# Disks: boot + hot tier + cold tier (CE installer expects all three)
qemu-img create -f qcow2 ce-boot.qcow2 64G
qemu-img create -f qcow2 ce-hot.qcow2 200G
qemu-img create -f qcow2 ce-cold.qcow2 500G

virt-install \
  --name ce-bake --memory 49152 --vcpus 12 \
  --cpu host-passthrough \
  --disk path=ce-boot.qcow2,bus=virtio \
  --disk path=ce-hot.qcow2,bus=virtio \
  --disk path=ce-cold.qcow2,bus=virtio \
  --cdrom phoenix-ce.iso \
  --osinfo detect=on,require=off \
  --network network=default,model=virtio \
  --graphics vnc --noautoconsole
# Complete the CE installer over VNC (single-node, configure CVM),
# let AOS finish first boot, create the cluster, then shut down cleanly.
```

Upload **only the boot disk** — the test runs recreate empty data disks
(the nested-kvm module's `guest_extra_disk_gb = [200, 500]` for ahv):

```sh
./scripts/upload-lab-image.sh ce-boot.qcow2 ahv
```

Caveats:
- CE first boot after import re-detects disks; keep the virtio ordering
  identical to bake time (the module attaches data disks in index order).
- CE's CVM pins ~20GB RAM — the ahv leg's 48GB guest default is not padding.
- i4i.metal (local NVMe) is the preferred cloud host; the env root picks it
  for the ahv leg automatically.

## HPE VME

VME ships as a manager appliance plus host agents on Ubuntu — its "host" is
the same Ubuntu+KVM stack as our kvm leg:

1. Boot an Ubuntu 24.04 cloud image as the HVM host VM
   (`--cpu host-passthrough`), install the VME host agent.
2. Import the VME Manager appliance qcow2 as a second VM, run its setup,
   register the host.
3. Shut both down cleanly; upload the HVM host image as the `vme` golden
   image. For a single-image flow, the manager can live nested on the HVM
   host; for a two-VM topology, extend the module to boot both (future work).

```sh
./scripts/upload-lab-image.sh vme-host.qcow2 vme
```

## Verifying a bake before promoting

Boot the image locally exactly as the module will, then check the product's
own health (Prism reachable for ahv; VME manager UI for vme) before
`upload-lab-image.sh` rewrites `latest.txt`. Rollback is always possible —
point `latest.txt` back at the previous sha.
