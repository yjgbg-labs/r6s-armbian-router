#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command curl
[[ -f "$R6S_ARTIFACT_DIR/latest.env" ]] || die "run groot jobs package first"
# shellcheck source=/dev/null
. "$R6S_ARTIFACT_DIR/latest.env"

for artifact in "$R6S_IMAGE" "$R6S_IMAGE_SHA256"; do
	name="$(basename -- "$artifact")"
	url="$R6S_ARTIFACT_UPLOAD_BASE_URL/$name"
	if curl --fail --silent --head "$url" >/dev/null 2>&1; then
		die "refusing to overwrite existing artifact: $url"
	fi
	curl --fail --silent --show-error --request PUT --upload-file "$artifact" "$url"
	printf 'uploaded %s\n' "$url"
done
