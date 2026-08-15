#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command sha256sum
require_command tar
mkdir -p "$R6S_ARTIFACT_DIR"

temporary="$(mktemp "$R6S_ARTIFACT_DIR/runtime.XXXXXX.tar.gz")"
trap 'rm -f "$temporary"' EXIT
tar \
	--sort=name \
	--owner=0 \
	--group=0 \
	--numeric-owner \
	--mtime=@0 \
	-C "$R6S_PROJECT_ROOT/userpatches/overlay" \
	-czf "$temporary" .

digest="$(sha256sum "$temporary" | cut -d ' ' -f 1)"
name="r6s-router-runtime-${R6S_ARTIFACT_VERSION}-${digest:0:12}.tar.gz"
artifact="$R6S_ARTIFACT_DIR/$name"
mv "$temporary" "$artifact"
trap - EXIT
(
	cd "$R6S_ARTIFACT_DIR"
	sha256sum "$name" > "$name.sha256"
)

{
	printf 'R6S_RUNTIME_ARTIFACT=%q\n' "$artifact"
	printf 'R6S_RUNTIME_SHA256=%q\n' "$artifact.sha256"
} > "$R6S_ARTIFACT_DIR/runtime.env"

printf '%s\n' "$artifact"
