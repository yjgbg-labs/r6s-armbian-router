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
- dnsmasq with DNS disabled (`port=0`) for LAN DHCP only; Mihomo owns DNS on
  `10.0.0.1` and has a periodic DNS/proxy-egress health check.
- The custom RSS-capable r8125 driver loaded directly from initramfs with two
  RX and TX queues. The stock r8169 driver is disabled.
- Stable MAC addresses for every Ethernet interface and `br-lan`.
- Mihomo transparent proxying. Wi-Fi and QoS remain runtime configuration
  managed by `groot-cli` rather than duplicated in the base image.
- Key-only SSH as the `router` user; password login and root SSH are disabled.
- Kernel and BSP packages frozen until the R6S Ethernet and Wi-Fi paths pass
  qualification.

IPv6 routing and Tailscale are outside the current image scope.

## Build Configuration

Copy `config.local.env.example` to `config.local.env`. The local file is ignored
by Git. At minimum, point `SSH_AUTHORIZED_KEY_FILE` to an OpenSSH public key.
Wi-Fi credentials are deliberately not embedded in the image. Apply the
runtime router configuration with `groot router write` after first boot.

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
7. Confirm only `r8125` is loaded and both PCIe interfaces expose 2RX/2TX.
8. Apply Wi-Fi and QoS with `groot router write`.

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
