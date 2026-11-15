#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command curl
metadata="$R6S_ARTIFACT_DIR/mihomo-latest.env"
[[ -f "$metadata" ]] || die "run mise run mihomo-package first"
# shellcheck source=/dev/null
. "$metadata"

for artifact in "$R6S_MIHOMO_ARTIFACT" "$R6S_MIHOMO_ARTIFACT_SHA256"; do
	name="$(basename -- "$artifact")"
	url="$R6S_ARTIFACT_UPLOAD_BASE_URL/$name"
	if curl --noproxy '*' --fail --silent --head "$url" >/dev/null 2>&1; then
		remote_sha="$(curl --noproxy '*' --fail --silent "$R6S_ARTIFACT_UPLOAD_BASE_URL/$R6S_MIHOMO_ARTIFACT_NAME.sha256" 2>/dev/null || true)"
		[[ "$remote_sha" == "$R6S_MIHOMO_SHA256  $R6S_MIHOMO_ARTIFACT_NAME" ]] || \
			die "artifact already exists with unexpected checksum: $url"
		printf 'already uploaded %s\n' "$url"
		continue
	fi
	curl --noproxy '*' --fail --silent --show-error --request PUT --upload-file "$artifact" "$url"
	printf 'uploaded %s\n' "$url"
done
