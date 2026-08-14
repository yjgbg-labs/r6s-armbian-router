#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command sha256sum
require_command xz
mkdir -p "$R6S_ARTIFACT_DIR"

shopt -s nullglob
images=("$R6S_ARMBIAN_DIR"/output/images/*.img.xz)
(( ${#images[@]} == 1 )) || \
	die "expected one .img.xz in Armbian output/images, found ${#images[@]}"

source_image="${images[0]}"
xz --test "$source_image"
source_sha="$(sha256sum "$source_image" | cut -d ' ' -f 1)"
artifact_name="r6s-armbian-router-${R6S_ARTIFACT_VERSION}-${source_sha:0:12}.img.xz"
artifact="$R6S_ARTIFACT_DIR/$artifact_name"

cp "$source_image" "$artifact"
(
	cd "$R6S_ARTIFACT_DIR"
	sha256sum "$artifact_name" > "$artifact_name.sha256"
)

{
	printf 'R6S_IMAGE=%q\n' "$artifact"
	printf 'R6S_IMAGE_SHA256=%q\n' "$artifact.sha256"
	printf 'R6S_IMAGE_DIGEST=%q\n' "$source_sha"
} > "$R6S_ARTIFACT_DIR/latest.env"

printf '%s\n' "$artifact"
