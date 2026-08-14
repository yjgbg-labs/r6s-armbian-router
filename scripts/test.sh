#!/usr/bin/env bash

set -euo pipefail
. "$(dirname -- "$0")/common.sh"

scripts=(
	"$R6S_PROJECT_ROOT"/scripts/*.sh
	"$R6S_PROJECT_ROOT"/userpatches/*.sh
	"$R6S_PROJECT_ROOT"/userpatches/extensions/*.sh
	"$R6S_PROJECT_ROOT"/userpatches/overlay/usr/local/sbin/*
)

for script in "${scripts[@]}"; do
	bash -n "$script"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
config="$tmp/router.env"
cp "$R6S_PROJECT_ROOT/userpatches/overlay/etc/r6s-router/router.env.example" "$config"

R6S_ROOT="$tmp/root" \
R6S_CONFIG="$config" \
R6S_DRY_RUN=1 \
	"$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-router-prepare"

mkdir -p "$tmp/bin"
cat > "$tmp/bin/systemctl" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$tmp/bin/dig" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$MOCK_DIG_LOG"
printf '142.250.4.94\n'
EOF
cat > "$tmp/bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$MOCK_CURL_LOG"
EOF
chmod 755 "$tmp/bin/systemctl" "$tmp/bin/dig" "$tmp/bin/curl"
cat > "$tmp/mihomo.yaml" <<'EOF'
mixed-port: 17890
EOF
MOCK_CURL_LOG="$tmp/curl.args" \
MOCK_DIG_LOG="$tmp/dig.args" \
PATH="$tmp/bin:$PATH" \
R6S_CONFIG="$config" \
MIHOMO_CONFIG="$tmp/mihomo.yaml" \
	"$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-mihomo-health"
grep -q '^@10.0.0.1$' "$tmp/dig.args"
grep -q '^http://127.0.0.1:17890$' "$tmp/curl.args"
grep -q '^https://www.gstatic.com/generate_204$' "$tmp/curl.args"

test -f "$tmp/root/etc/netplan/60-r6s-router.yaml"
test -f "$tmp/root/etc/dnsmasq.d/r6s-router.conf"
test -f "$tmp/root/etc/nftables.conf"
grep -q '^port=0$' "$tmp/root/etc/dnsmasq.d/r6s-router.conf"
! grep -Eq '^(cache-size|domain-needed|bogus-priv|local|server|no-resolv)=' \
	"$tmp/root/etc/dnsmasq.d/r6s-router.conf"
grep -q 'interfaces: \[lan1, wan\]' "$tmp/root/etc/netplan/60-r6s-router.yaml"
grep -q 'addresses: \[10.0.0.1/16\]' "$tmp/root/etc/netplan/60-r6s-router.yaml"
grep -q 'macaddress: 06:A5:73:3A:20:1F' "$tmp/root/etc/netplan/60-r6s-router.yaml"
grep -q 'macaddress: 0E:3E:80:DF:AF:12' "$tmp/root/etc/netplan/60-r6s-router.yaml"
grep -q 'macaddress: 0A:30:61:12:37:D8' "$tmp/root/etc/netplan/60-r6s-router.yaml"
grep -q 'macaddress: 0A:30:61:12:37:D9' "$tmp/root/etc/netplan/60-r6s-router.yaml"
grep -q 'oifname "lan2" masquerade' "$tmp/root/etc/nftables.conf"
grep -q 'iifname "Meta" ip saddr 198.18.0.2 ip daddr 198.18.0.1 meta l4proto tcp counter accept' \
	"$tmp/root/etc/nftables.conf"
grep -q 'iifname { "lan1", "wan" } oifname { "lan1", "wan" } accept' \
	"$tmp/root/etc/nftables.conf"
grep -q 'iifname "br-lan" oifname "Meta" accept' \
	"$tmp/root/etc/nftables.conf"
grep -q 'iifname "Meta" oifname "br-lan" accept' \
	"$tmp/root/etc/nftables.conf"
grep -q '^CONFIG_DIR=/etc/dnsmasq.d,.dpkg-dist,.dpkg-old,.dpkg-new$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/default/dnsmasq"
grep -q '^IGNORE_RESOLVCONF=yes$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/default/dnsmasq"
grep -q '^DNSMASQ_EXCEPT="lo"$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/default/dnsmasq"
grep -q '^ExecStartPre=/usr/local/bin/mihomo -t ' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/mihomo.service"
grep -q '^ExecStartPre=/usr/sbin/modprobe tun$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/mihomo.service"
grep -q '^R6S_MIHOMO_SHA256=' "$R6S_PROJECT_ROOT/config.env"
grep -q '^R6S_R8125_SOURCE_SHA256=' "$R6S_PROJECT_ROOT/config.env"
grep -q 'paired10' "$R6S_PROJECT_ROOT/config.env"
grep -q '^blacklist r8169$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/modprobe.d/groot-r8125.conf"
grep -q '^blacklist hantro_vpu$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/modprobe.d/blacklist-hantro-vpu.conf"
grep -q 'iommu.passthrough=1' \
	"$R6S_PROJECT_ROOT/userpatches/extensions/r6s-router.sh"
grep -q 'declare -g INSTALL_HEADERS=yes' \
	"$R6S_PROJECT_ROOT/userpatches/extensions/r6s-router.sh"
grep -q 'chroot_sdcard test -e "/lib/modules/.*build/Makefile"' \
	"$R6S_PROJECT_ROOT/userpatches/extensions/r6s-router.sh"
grep -q 'KERNELS=="0003:31:00.0", NAME:="wan"' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/udev/rules.d/70-persistent-net.rules"
grep -q 'KERNELS=="0004:41:00.0", NAME:="lan1"' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/udev/rules.d/70-persistent-net.rules"
! grep -q '90-wan-mac-test\|16:c9:1c:42:a5:dc' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-router-diagnose"
grep -q '^WantedBy=multi-user.target$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/r6s-router-verify.service"
grep -q 'groot-router-qos.service mihomo.service' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/r6s-router-verify.service"
grep -q 'check_queues.*tx' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-router-verify"
test -x "$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-router-verify"
test -x "$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-mihomo-health"
grep -q '^After=network-online.target nftables.service groot-r8125.service$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/mihomo.service"
! grep -q 'dnsmasq.service' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/mihomo.service"
test ! -e "$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/dnsmasq.service.d/r6s-mihomo.conf"
grep -q '^OnUnitActiveSec=1min$' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/r6s-mihomo-health.timer"
grep -q 'dig .*@.*DNS_NAME' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-mihomo-health"
grep -q -- '--proxy ' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-mihomo-health"
test ! -e "$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/r6s-router-wifi.service"
test ! -e "$R6S_PROJECT_ROOT/userpatches/overlay/usr/local/sbin/r6s-router-hostapd"

if command -v netplan >/dev/null 2>&1; then
	if ! netplan_output="$(netplan generate --root-dir "$tmp/root" 2>&1)"; then
		printf '%s\n' "$netplan_output" >&2
		exit 1
	fi
fi

grep -q '^BRANCH=current$' "$R6S_PROJECT_ROOT/userpatches/config-r6s-router.conf.sh"
grep -q '^RELEASE=trixie$' "$R6S_PROJECT_ROOT/userpatches/config-r6s-router.conf.sh"
grep -q '^BSPFREEZE=yes$' "$R6S_PROJECT_ROOT/userpatches/config-r6s-router.conf.sh"
grep -q '^EXTRAWIFI=no$' "$R6S_PROJECT_ROOT/userpatches/config-r6s-router.conf.sh"
grep -q '10-dhcp-all-interfaces.yaml' "$R6S_PROJECT_ROOT/userpatches/extensions/r6s-router.sh"
grep -q '^Before=network-pre.target' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/r6s-router-prepare.service"
! grep -q 'r6s-router-wifi' \
	"$R6S_PROJECT_ROOT/userpatches/overlay/etc/systemd/system/r6s-router-prepare.service"

printf 'all tests passed\n'
