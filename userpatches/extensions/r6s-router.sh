function extension_prepare_config__r6s_router_packages() {
	if [[ "$BOARD" != nanopi-r6s || "$RELEASE" != trixie || "$BRANCH" != current ]]; then
		exit_with_error "r6s-router requires nanopi-r6s/trixie/current"
	fi

	display_alert "Extension: ${EXTENSION}" "Adding router packages" "info"
	add_packages_to_image \
		hostapd dnsmasq nftables iw wireless-regdb rfkill ethtool \
		curl ca-certificates sudo
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
		"${SDCARD}/usr/local/sbin/r6s-router-hostapd" \
		"${SDCARD}/usr/local/sbin/r6s-router-diagnose"

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

	chroot_sdcard systemctl disable hostapd.service || true
	chroot_sdcard systemctl enable \
		r6s-router-prepare.service \
		r6s-router-wifi.service \
		nftables.service \
		dnsmasq.service
}
