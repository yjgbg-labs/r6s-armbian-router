#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command docker
[[ -x "$R6S_ARMBIAN_DIR/compile.sh" ]] || die "run mise run prepare first"
[[ -f "$R6S_STAGED_USERPATCHES/config-r6s-router.conf.sh" ]] || \
	die "staged userpatches are missing"

available_kib="$(df -Pk "$R6S_PROJECT_ROOT" | awk 'NR == 2 { print $4 }')"
(( available_kib >= 35 * 1024 * 1024 )) || \
	die "less than 35 GiB is available; Armbian recommends about 50 GiB"

"$R6S_ARMBIAN_DIR/compile.sh" build r6s-router \
	USERPATCHES_PATH="$R6S_STAGED_USERPATCHES" \
	PREFER_DOCKER=yes \
	CLEAN_LEVEL=images
