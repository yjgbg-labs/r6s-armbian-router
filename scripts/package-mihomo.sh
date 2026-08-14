#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command cp
require_command sha256sum

source_binary="$R6S_STAGE_DIR/mihomo/mihomo"
[[ -f "$source_binary" ]] || die "missing Mihomo binary: $source_binary"

actual_sha="$(sha256sum "$source_binary" | cut -d ' ' -f 1)"
[[ "$actual_sha" == "$R6S_MIHOMO_SHA256" ]] || \
	die "Mihomo SHA-256 is $actual_sha, expected $R6S_MIHOMO_SHA256"

mkdir -p "$R6S_ARTIFACT_DIR"
artifact_name="mihomo-${R6S_MIHOMO_VERSION}-linux-arm64-${actual_sha:0:12}"
artifact="$R6S_ARTIFACT_DIR/$artifact_name"
cp "$source_binary" "$artifact"
chmod 755 "$artifact"
(
	cd "$R6S_ARTIFACT_DIR"
	sha256sum "$artifact_name" > "$artifact_name.sha256"
)

{
	printf 'R6S_MIHOMO_ARTIFACT=%q\n' "$artifact"
	printf 'R6S_MIHOMO_ARTIFACT_SHA256=%q\n' "$artifact.sha256"
	printf 'R6S_MIHOMO_ARTIFACT_NAME=%q\n' "$artifact_name"
} > "$R6S_ARTIFACT_DIR/mihomo-latest.env"

printf '%s\n' "$artifact"
