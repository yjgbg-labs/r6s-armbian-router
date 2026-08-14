#!/usr/bin/env bash

set -euo pipefail

R6S_PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
. "$R6S_PROJECT_ROOT/config.env"

R6S_ARMBIAN_DIR="$R6S_PROJECT_ROOT/.cache/armbian-build"
R6S_STAGE_DIR="$R6S_PROJECT_ROOT/.build"
R6S_STAGED_USERPATCHES="$R6S_STAGE_DIR/userpatches"
R6S_ARTIFACT_DIR="$R6S_PROJECT_ROOT/artifacts"

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_command() {
	command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}
