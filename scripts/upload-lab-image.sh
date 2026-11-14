#!/usr/bin/env bash
# Upload an exported lab guest image (qcow2 for KVM/VME, vhdx for Hyper-V)
# to the golden-image bucket, content-addressed by sha256 so runs are
# reproducible and re-uploads of identical images are no-ops.
#
# Usage: upload-lab-image.sh <image-file> <leg: kvm|vme|hyperv> [bucket]
set -euo pipefail

IMAGE_FILE="${1:?usage: upload-lab-image.sh <image-file> <leg> [bucket]}"
LEG="${2:?leg required: kvm|vme|ahv|kubevirt|hyperv}"
BUCKET="${3:-hyperforge-golden-images}"

case "$LEG" in
  kvm|vme|ahv|kubevirt)
    [[ "$IMAGE_FILE" == *.qcow2 ]] || { echo "error: $LEG leg expects a .qcow2 image" >&2; exit 1; } ;;
  hyperv)
    [[ "$IMAGE_FILE" == *.vhdx ]] || { echo "error: hyperv leg expects a .vhdx image" >&2; exit 1; } ;;
  *)
    echo "error: unknown leg '$LEG'" >&2; exit 1 ;;
esac

SHA=$(shasum -a 256 "$IMAGE_FILE" | cut -d' ' -f1)
EXT="${IMAGE_FILE##*.}"
KEY="golden/$LEG/${SHA}.${EXT}"

if aws s3api head-object --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1; then
  echo "already uploaded: s3://$BUCKET/$KEY"
else
  aws s3 cp "$IMAGE_FILE" "s3://$BUCKET/$KEY"
fi

# Pointer the pipeline resolves at run time; updating it promotes this image.
echo "s3://$BUCKET/$KEY" | aws s3 cp - "s3://$BUCKET/golden/$LEG/latest.txt"

echo "promoted: s3://$BUCKET/$KEY (pointer: golden/$LEG/latest.txt)"
