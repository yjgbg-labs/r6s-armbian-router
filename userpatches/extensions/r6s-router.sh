function extension_prepare_config__r6s_router_packages() {
	if [[ "$BOARD" != nanopi-r6s || "$RELEASE" != trixie || "$BRANCH" != current ]]; then
		exit_with_error "r6s-router requires nanopi-r6s/trixie/current"
	fi

	display_alert "Extension: ${EXTENSION}" "Adding router packages" "info"
	add_packages_to_image \
		hostapd dnsmasq nftables iw wireless-regdb rfkill ethtool \
		curl ca-certificates dnsutils sudo build-essential
}

function extension_finish_config__r6s_router_kernel_headers() {
	[[ "${KERNEL_HAS_WORKING_HEADERS}" == yes ]] || \
		exit_with_error "r6s-router requires working headers for the target kernel"
	declare -g INSTALL_HEADERS=yes
}

function install_r6s_r8125() {
	# shellcheck source=/dev/null
	. "${SDCARD}/etc/r6s-router/r8125.env"
	local archive="${SDCARD}/tmp/r8125-source.tar.gz"
	local source_dir="${SDCARD}/tmp/r8125-source"
	local kernel
	local -a kernels

	curl --fail --retry 3 -o "$archive" "$R8125_SOURCE_URL"
	printf '%s  %s\n' "$R8125_SOURCE_SHA256" "$archive" | sha256sum -c -
	rm -rf "$source_dir"
	install -d "$source_dir"
	tar -xzf "$archive" -C "$source_dir"

	mapfile -t kernels < <(find "${SDCARD}/lib/modules" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
	(( ${#kernels[@]} == 1 )) || exit_with_error "Expected one target kernel, found: ${kernels[*]}"
	kernel="${kernels[0]}"
	chroot_sdcard test -e "/lib/modules/${kernel}/build/Makefile" || \
		exit_with_error "Missing target kernel headers for ${kernel}"

	chroot_sdcard make -C "/lib/modules/${kernel}/build" \
		M=/tmp/r8125-source \
		ENABLE_MULTIPLE_TX_QUEUE=y \
		ENABLE_RSS_SUPPORT=y \
		CONFIG_ASPM=n \
		ENABLE_PTP_SUPPORT=n \
		modules
	install -d "${SDCARD}/lib/modules/${kernel}/updates/dkms"
	install -m 0644 "$source_dir/r8125.ko" \
		"${SDCARD}/lib/modules/${kernel}/updates/dkms/r8125.ko"
	install -m 0755 "$source_dir/scripts/persistent-start.sh" \
		"${SDCARD}/usr/local/sbin/groot-r8125-start"
	install -m 0644 "$source_dir/systemd/groot-r8125.service" \
		"${SDCARD}/etc/systemd/system/groot-r8125.service"

	sed -i '/^[[:space:]]*r8125\([[:space:]].*\)\?$/d' \
		"${SDCARD}/etc/initramfs-tools/modules"
	printf '%s\n' 'r8125 rx_queues=2 tx_queues=2' >> \
		"${SDCARD}/etc/initramfs-tools/modules"
	chroot_sdcard depmod -a "$kernel"
	chroot_sdcard update-initramfs -u -k "$kernel"
	chroot_sdcard systemctl enable groot-r8125.service
	rm -rf "$archive" "$source_dir"
}

function configure_r6s_boot_args() {
	local boot_env="${SDCARD}/boot/armbianEnv.txt"
	local extraargs
	local arg

	[[ -f "$boot_env" ]] || exit_with_error "Missing ${boot_env}"
	extraargs="$(sed -n 's/^extraargs=//p' "$boot_env")"
	for arg in cma=256M iommu.strict=0 iommu.passthrough=1; do
		[[ " ${extraargs} " == *" ${arg} "* ]] || extraargs="${extraargs:+${extraargs} }${arg}"
	done
	if grep -q '^extraargs=' "$boot_env"; then
		sed -i "s|^extraargs=.*|extraargs=${extraargs}|" "$boot_env"
	else
		printf 'extraargs=%s\n' "$extraargs" >> "$boot_env"
	fi
}

function post_customize_image__install_r6s_router() {
	display_alert "Extension: ${EXTENSION}" "Installing router configuration" "info"
	cp -a --no-preserve=ownership "${USERPATCHES_PATH}/overlay/." "${SDCARD}/"
	chown root:root \
		"${SDCARD}" \
		"${SDCARD}/etc" \
		"${SDCARD}/etc/ssh" \
		"${SDCARD}/etc/ssh/sshd_config.d" \
		"${SDCARD}/etc/systemd" \
		"${SDCARD}/etc/systemd/system" \
		"${SDCARD}/etc/sysctl.d" \
		"${SDCARD}/etc/sudoers.d" \
		"${SDCARD}/usr" \
		"${SDCARD}/usr/local" \
		"${SDCARD}/usr/local/sbin" \
		"${SDCARD}/home"
	chmod 755 \
		"${SDCARD}" \
		"${SDCARD}/etc" \
		"${SDCARD}/etc/ssh" \
		"${SDCARD}/etc/ssh/sshd_config.d" \
		"${SDCARD}/etc/systemd" \
		"${SDCARD}/etc/systemd/system" \
		"${SDCARD}/etc/sysctl.d" \
		"${SDCARD}/etc/sudoers.d" \
		"${SDCARD}/usr" \
		"${SDCARD}/usr/local" \
		"${SDCARD}/usr/local/sbin" \
		"${SDCARD}/home"

	if [[ ! -f "${SDCARD}/etc/r6s-router/router.env" ]]; then
		cp "${SDCARD}/etc/r6s-router/router.env.example" \
			"${SDCARD}/etc/r6s-router/router.env"
	fi

	chmod 600 "${SDCARD}/etc/r6s-router/router.env"
	chmod 755 \
		"${SDCARD}/usr/local/sbin/r6s-router-prepare" \
		"${SDCARD}/usr/local/sbin/r6s-router-diagnose" \
		"${SDCARD}/usr/local/sbin/r6s-mihomo-health" \
		"${SDCARD}/usr/local/sbin/r6s-router-verify"

	[[ -f "${SDCARD}/home/router/.ssh/authorized_keys" ]] || \
		exit_with_error "router SSH public key was not staged"

	if ! chroot_sdcard id router >/dev/null 2>&1; then
		chroot_sdcard useradd --create-home --shell /bin/bash --groups sudo router
	fi

	install -d -m 0700 "${SDCARD}/home/router/.ssh"
	chmod 600 "${SDCARD}/home/router/.ssh/authorized_keys"
	chroot_sdcard chown -R router:router /home/router/.ssh

	random_password="$(openssl rand -hex 32)"
	printf 'router:%s\nroot:%s\n' "$random_password" "$random_password" | chroot_sdcard chpasswd
	unset random_password

	install -d -m 0750 "${SDCARD}/etc/sudoers.d"
	printf 'router ALL=(ALL:ALL) NOPASSWD: ALL\n' > "${SDCARD}/etc/sudoers.d/90-r6s-router"
	chmod 440 "${SDCARD}/etc/sudoers.d/90-r6s-router"
	rm -f "${SDCARD}/root/.not_logged_in_yet"
	rm -f "${SDCARD}/etc/netplan/10-dhcp-all-interfaces.yaml"

	R6S_ROOT="${SDCARD}" \
	R6S_CONFIG="${SDCARD}/etc/r6s-router/router.env" \
	R6S_DRY_RUN=1 \
		"${SDCARD}/usr/local/sbin/r6s-router-prepare"
	install_r6s_r8125
	configure_r6s_boot_args

	chroot_sdcard systemctl disable hostapd.service || true
	chroot_sdcard systemctl enable \
		r6s-router-prepare.service \
		r6s-router-verify.service \
		r6s-mihomo-health.timer \
		nftables.service \
		dnsmasq.service
}
