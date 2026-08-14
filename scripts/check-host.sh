#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

missing=0
for command in git docker sha256sum xz curl; do
	if ! command -v "$command" >/dev/null 2>&1; then
		printf 'missing: %s\n' "$command" >&2
		missing=1
	fi
done

available_kib="$(df -Pk "$R6S_PROJECT_ROOT" | awk 'NR == 2 { print $4 }')"
printf 'available disk: %s GiB\n' "$((available_kib / 1024 / 1024))"
printf 'recommended disk: at least 50 GiB\n'

if (( available_kib < 35 * 1024 * 1024 )); then
	printf 'insufficient disk for an Armbian source build\n' >&2
	missing=1
fi

(( missing == 0 )) || exit 1
