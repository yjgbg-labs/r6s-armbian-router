#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command lsblk
require_command sha256sum
require_command sudo
require_command xz

[[ -f "$R6S_ARTIFACT_DIR/latest.env" ]] || die "run mise run package first"
# shellcheck source=/dev/null
. "$R6S_ARTIFACT_DIR/latest.env"

: "${FLASH_DEVICE:?set FLASH_DEVICE to the whole SD device, for example /dev/sdX}"
FLASH_DEVICE="$(readlink -f -- "$FLASH_DEVICE")"
[[ -b "$FLASH_DEVICE" ]] || die "not a block device: $FLASH_DEVICE"
[[ "$(lsblk -ndo TYPE "$FLASH_DEVICE")" == disk ]] || die "select a whole disk, not a partition"

if lsblk -nrpo MOUNTPOINT "$FLASH_DEVICE" | grep -q '/'; then
	die "a filesystem on $FLASH_DEVICE is mounted"
fi

removable="$(lsblk -ndo RM "$FLASH_DEVICE")"
[[ "$removable" == 1 || "${FLASH_ALLOW_FIXED:-0}" == 1 ]] || \
	die "$FLASH_DEVICE is not marked removable; set FLASH_ALLOW_FIXED=1 only after checking it"

[[ "${FLASH_CONFIRM:-}" == "ERASE $FLASH_DEVICE" ]] || \
	die "set FLASH_CONFIRM='ERASE $FLASH_DEVICE' to confirm destructive writing"

(
	cd "$R6S_ARTIFACT_DIR"
	sha256sum -c "$(basename -- "$R6S_IMAGE_SHA256")"
)
xz --decompress --stdout "$R6S_IMAGE" | sudo dd of="$FLASH_DEVICE" bs=16M conv=fsync status=progress
sync
printf 'flashed and synced %s\n' "$FLASH_DEVICE"
