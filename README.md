# R6S Armbian Router

Reproducible Armbian Debian 13 router image for the FriendlyElec NanoPi R6S.
The image uses Armbian `v26.5.1`, Debian Trixie Minimal and the current 6.18
kernel so RTL8832BU/RTL8852BU can use the upstream `rtw89_8852bu` driver.

## Initial Scope

- WAN DHCP on Armbian `lan2`, the native 1GbE port used as WAN by the
  current FriendlyWrt installation.
- A `br-lan` bridge over Armbian `lan1` and `wan`, the two PCIe 2.5GbE
  ports currently used as LAN, at `10.0.0.1/16`.
- IPv4 forwarding, nftables firewall and WAN masquerading.
- dnsmasq DNS cache and DHCP service for LAN clients.
- Optional 2.4 GHz WPA2 access point with 20 MHz-friendly settings.
- Key-only SSH as the `router` user; password login and root SSH are disabled.
- Kernel and BSP packages frozen until the R6S Ethernet and Wi-Fi paths pass
  qualification.

IPv6 routing, Mihomo, Tailscale and migration of the existing FriendlyWrt
configuration are deliberately outside the first bootable image.

## Build Configuration

Copy `config.local.env.example` to `config.local.env`. The local file is ignored
by Git. At minimum, point `SSH_AUTHORIZED_KEY_FILE` to an OpenSSH public key.
Wi-Fi can remain disabled for the first wired boot, then be configured in
`/etc/r6s-router/router.env` on the device.

Normal project operations use `groot jobs`:

```bash
groot jobs test
groot jobs host-check
groot jobs build
groot jobs package
groot jobs upload
```

The source build requires Docker, at least 35 GiB free for this project and
about 50 GiB free as recommended by Armbian. The upstream repository is pinned
to commit `8de11a017f7f05a82c77850f8322928cb6a3b70c`.

## First Boot

1. Write the image to a reliable A1-rated microSD card.
2. Leave the existing FriendlyWrt eMMC untouched.
3. Connect the physical WAN port to the upstream network.
4. Connect a test machine to LAN1 or LAN2.
5. Boot from microSD and obtain a DHCP lease on the test machine.
6. SSH to `router@10.0.0.1` with the public key selected at build time.
7. Validate all Ethernet ports before enabling Wi-Fi.

To enable Wi-Fi after the first wired boot, edit
`/etc/r6s-router/router.env`, set the SSID and PSK, then run:

```bash
sudo systemctl restart r6s-router-prepare.service
sudo systemctl restart r6s-router-wifi.service
```

Use the USB 2.0 port for a 2.4 GHz-only access point. Check that
`iw phy` advertises AP mode and that `rtw89_8852bu` owns the device before
treating the wireless path as production-ready.

## Flash Safety

The `flash` job is intentionally guarded. It requires a whole removable block
device and an exact destructive confirmation string:

```bash
FLASH_DEVICE=/dev/sdX \
FLASH_CONFIRM='ERASE /dev/sdX' \
groot jobs flash
```

Prefer Armbian Imager when writing manually. Do not write to eMMC until the SD
test matrix in `docs/runbook.md` passes.
