#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

require_command ssh
metadata="$R6S_ARTIFACT_DIR/runtime.env"
[[ -f "$metadata" ]] || die "run groot jobs runtime-package first"
# shellcheck source=/dev/null
. "$metadata"

archive_name="$(basename -- "$R6S_RUNTIME_ARTIFACT")"
archive_url="$R6S_ARTIFACT_UPLOAD_BASE_URL/$archive_name"
checksum_url="$R6S_ARTIFACT_UPLOAD_BASE_URL/$(basename -- "$R6S_RUNTIME_SHA256")"

ssh -o BatchMode=yes "$R6S_RUNTIME_HOST" bash -s -- \
	"$archive_url" "$checksum_url" "$archive_name" <<'REMOTE'
set -euo pipefail

work="$(mktemp -d /tmp/r6s-runtime.XXXXXX)"
trap 'rm -rf "$work"' EXIT
curl --fail --retry 3 -o "$work/$3" "$1"
curl --fail --retry 3 -o "$work/$3.sha256" "$2"
(
	cd "$work"
	sha256sum -c "$3.sha256"
)

sudo systemctl disable --now r6s-router-wifi.service >/dev/null 2>&1 || true
sudo tar -xzf "$work/$3" -C /
sudo rm -f \
	/etc/dnsmasq.d/r6s-mihomo.conf \
	/etc/hostapd/r6s-router.conf \
	/etc/netplan/10-br-lan-fixed-mac.yaml \
	/etc/netplan/20-eth-fixed-mac.yaml \
	/etc/netplan/90-wan-mac-test.yaml \
	/etc/systemd/system/r6s-router-wifi.service \
	/usr/local/sbin/r6s-router-hostapd

router_config="$work/router.env"
sudo sed \
	-e '/^WIFI_/d' \
	-e '/^WAN_MAC=/d' \
	-e '/^LAN_INTERFACE_1_MAC=/d' \
	-e '/^LAN_INTERFACE_2_MAC=/d' \
	-e '/^LAN_BRIDGE_MAC=/d' \
	/etc/r6s-router/router.env > "$router_config"
cat >> "$router_config" <<'EOF'
WAN_MAC=06:A5:73:3A:20:1F
LAN_INTERFACE_1_MAC=0E:3E:80:DF:AF:12
LAN_INTERFACE_2_MAC=0A:30:61:12:37:D8
LAN_BRIDGE_MAC=0A:30:61:12:37:D9
EOF
sudo install -o root -g root -m 0600 "$router_config" /etc/r6s-router/router.env

if ! command -v dig >/dev/null 2>&1; then
	sudo env DEBIAN_FRONTEND=noninteractive apt-get update
	sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends dnsutils
fi

sudo systemctl daemon-reload
sudo systemctl restart r6s-router-prepare.service
sudo systemctl restart dnsmasq.service
sudo systemctl enable r6s-router-verify.service r6s-mihomo-health.timer >/dev/null
sudo systemctl restart r6s-router-verify.service
health_ok=0
for _ in 1 2 3; do
	if sudo systemctl restart r6s-mihomo-health.service; then
		health_ok=1
		break
	fi
	sleep 2
done
(( health_ok == 1 ))
sudo systemctl start r6s-mihomo-health.timer

for service in \
	r6s-router-prepare.service \
	r6s-router-verify.service \
	r6s-mihomo-health.timer \
	dnsmasq.service \
	mihomo.service \
	hostapd.service \
	groot-router-qos.service \
	groot-r8125.service; do
	systemctl is-active --quiet "$service"
done
printf 'r6s runtime synchronized\n'
REMOTE
