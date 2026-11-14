#!/usr/bin/env bash
# Build the host AMI for any hypervisor, driven by its profile:
#
#   ./scripts/build.sh kvm            # bakes the host image the kvm profile needs
#   ./scripts/build.sh hyperv
#   ./scripts/build.sh ahv            # resolves to kvm-host (AHV nests on KVM)
#   ./scripts/build.sh vme --dry-run  # show what would build without building
#
# The profile (hyperforge-core/profiles/<hv>.yaml) names which packer build
# serves it via its host_image field, so several hypervisors can share one
# host image and a new hypervisor needs no change here — just a profile.
set -euo pipefail

HV="${1:?usage: build.sh <hypervisor> [--dry-run] [--core-dir <path>]}"
shift
DRY_RUN=false
CORE_DIR="${HYPERFORGE_CORE_DIR:-$(cd "$(dirname "$0")/../.." && pwd)/hyperforge-core}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --core-dir) CORE_DIR="$2"; shift 2 ;;
    *) echo "error: unknown argument '$1'" >&2; exit 1 ;;
  esac
done

PROFILE="$CORE_DIR/profiles/$HV.yaml"
if [[ ! -f "$PROFILE" ]]; then
  echo "error: no profile at $PROFILE" >&2
  echo "known hypervisors:" >&2
  for f in "$CORE_DIR"/profiles/*.yaml; do [[ -e "$f" ]] && basename "$f" .yaml | sed 's/^/  - /' >&2; done
  exit 1
fi

# Minimal YAML field reader (top-level "key: value" only) — avoids a yq dependency.
profile_get() {
  awk -F': *' -v key="$1" '$1 == key { sub(/[[:space:]]*#.*$/, "", $2); print $2; exit }' "$PROFILE"
}

HOST_IMAGE=$(profile_get host_image)
AMI_PREFIX=$(profile_get host_ami_prefix)
PACKER_DIR="$(cd "$(dirname "$0")/.." && pwd)/packer/$HOST_IMAGE"

[[ -d "$PACKER_DIR" ]] || { echo "error: profile names host_image '$HOST_IMAGE' but $PACKER_DIR does not exist" >&2; exit 1; }

echo "hypervisor:  $HV"
echo "host image:  $HOST_IMAGE  ($PACKER_DIR)"
echo "ami prefix:  $AMI_PREFIX"

if $DRY_RUN; then
  echo "dry run: skipping packer build"
  exit 0
fi

( cd "$PACKER_DIR" && packer init . && packer build . )

echo
echo "Done. The hypervisor-host module resolves the newest '$AMI_PREFIX-*' AMI automatically."
echo "Next: bake/upload the golden guest image — see docs/baking-hypervisor-guests.md,"
echo "then ./scripts/upload-lab-image.sh <image> $HV"
