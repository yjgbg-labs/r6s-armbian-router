#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command curl
metadata="$R6S_ARTIFACT_DIR/runtime.env"
[[ -f "$metadata" ]] || die "run groot jobs runtime-package first"
# shellcheck source=/dev/null
. "$metadata"

for artifact in "$R6S_RUNTIME_ARTIFACT" "$R6S_RUNTIME_SHA256"; do
	name="$(basename -- "$artifact")"
	url="$R6S_ARTIFACT_UPLOAD_BASE_URL/$name"
	if curl --fail --silent --head "$url" >/dev/null 2>&1; then
		printf 'using existing %s\n' "$url"
		continue
	fi
	curl --fail --silent --show-error --request PUT --upload-file "$artifact" "$url"
	printf 'uploaded %s\n' "$url"
done
