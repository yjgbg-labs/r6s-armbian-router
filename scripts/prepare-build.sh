#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command git
require_command cp
require_command install

if [[ ! -d "$R6S_ARMBIAN_DIR/.git" ]]; then
	mkdir -p "$(dirname -- "$R6S_ARMBIAN_DIR")"
	git clone --filter=blob:none --branch "$R6S_ARMBIAN_REF" \
		"$R6S_ARMBIAN_REPOSITORY" "$R6S_ARMBIAN_DIR"
fi

actual_commit="$(git -C "$R6S_ARMBIAN_DIR" rev-parse HEAD)"
[[ "$actual_commit" == "$R6S_ARMBIAN_COMMIT" ]] || \
	die "Armbian checkout is $actual_commit, expected $R6S_ARMBIAN_COMMIT"
grep -q '^CONFIG_RTW89_8852BU=m$' \
	"$R6S_ARMBIAN_DIR/config/kernel/linux-rockchip64-current.config" || \
	die "pinned Armbian kernel config does not enable rtw89_8852bu"

mkdir -p "$R6S_STAGED_USERPATCHES"
cp -a "$R6S_PROJECT_ROOT/userpatches/." "$R6S_STAGED_USERPATCHES/"

WIFI_ENABLED=0
WIFI_SSID=""
WIFI_PSK=""
WIFI_COUNTRY=CN
WIFI_CHANNEL=6
WIFI_ENABLE_AX=0
WAN_INTERFACE=lan2
LAN_INTERFACE_1=lan1
LAN_INTERFACE_2=wan
LAN_CIDR=10.0.0.1/16
DHCP_START=10.0.0.100
DHCP_END=10.0.0.249
DHCP_LEASE=12h
SSH_AUTHORIZED_KEY_FILE="${SSH_AUTHORIZED_KEY_FILE:-$HOME/.ssh/id_ed25519.pub}"

if [[ -f "$R6S_PROJECT_ROOT/config.local.env" ]]; then
	# shellcheck source=/dev/null
	. "$R6S_PROJECT_ROOT/config.local.env"
fi

[[ -f "$SSH_AUTHORIZED_KEY_FILE" ]] || \
	die "set SSH_AUTHORIZED_KEY_FILE in config.local.env"
grep -Eq '^ssh-(ed25519|rsa|ecdsa-[^[:space:]]+)[[:space:]]' "$SSH_AUTHORIZED_KEY_FILE" || \
	die "SSH_AUTHORIZED_KEY_FILE does not contain an OpenSSH public key"

router_config="$R6S_STAGED_USERPATCHES/overlay/etc/r6s-router/router.env"
install -d -m 0755 "$(dirname -- "$router_config")"
umask 077
{
	printf 'WIFI_ENABLED=%q\n' "$WIFI_ENABLED"
	printf 'WIFI_SSID=%q\n' "$WIFI_SSID"
	printf 'WIFI_PSK=%q\n' "$WIFI_PSK"
	printf 'WIFI_COUNTRY=%q\n' "$WIFI_COUNTRY"
	printf 'WIFI_CHANNEL=%q\n' "$WIFI_CHANNEL"
	printf 'WIFI_ENABLE_AX=%q\n' "$WIFI_ENABLE_AX"
	printf 'WAN_INTERFACE=%q\n' "$WAN_INTERFACE"
	printf 'LAN_INTERFACE_1=%q\n' "$LAN_INTERFACE_1"
	printf 'LAN_INTERFACE_2=%q\n' "$LAN_INTERFACE_2"
	printf 'LAN_CIDR=%q\n' "$LAN_CIDR"
	printf 'DHCP_START=%q\n' "$DHCP_START"
	printf 'DHCP_END=%q\n' "$DHCP_END"
	printf 'DHCP_LEASE=%q\n' "$DHCP_LEASE"
} > "$router_config"

authorized_keys="$R6S_STAGED_USERPATCHES/overlay/home/router/.ssh/authorized_keys"
install -d -m 0700 "$(dirname -- "$authorized_keys")"
install -m 0600 "$SSH_AUTHORIZED_KEY_FILE" "$authorized_keys"

printf 'prepared Armbian %s (%s) userpatches\n' "$R6S_ARMBIAN_REF" "$R6S_ARMBIAN_COMMIT"
