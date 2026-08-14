# R6S Router Qualification Runbook

## Before Boot

- Preserve the current FriendlyWrt eMMC installation as rollback media.
- Record the current WAN and LAN cable positions.
- Use an A1-rated microSD card and verify the image SHA-256 before writing.
- Keep the SSH private key corresponding to the embedded public key available.
- Insert the RTL8832BU adapter into the USB 2.0 port while power is off.

## Wired Validation

1. Confirm the test client receives an address from `10.0.0.100-249`.
2. Confirm `router@10.0.0.1` accepts only public-key SSH.
3. Confirm `wan`, `lan1`, `lan2` and `br-lan` have the intended roles.
4. Confirm DNS resolution and IPv4 Internet access from both LAN ports.
5. Confirm unsolicited WAN input is dropped.
6. Reboot twice and repeat DHCP, DNS and forwarding checks.

## RTL8832BU Validation

1. Confirm `lsusb` reports the expected Realtek VID/PID.
2. Confirm `rtw89_8852bu` is loaded and no third-party DKMS driver is present.
3. Confirm `iw phy` lists AP mode and the 2.4 GHz channels allowed in `CN`.
4. Start with channel 1, 6 or 11, 20 MHz, WPA2-PSK/CCMP and AX disabled.
5. Test at least one legacy 2.4 GHz IoT device and one modern client.
6. Run a sustained transfer while monitoring disconnects, USB resets and heat.
7. Enable AX only after the compatibility test passes again.

## Performance and Stability

- Measure wired routing in both directions with iperf3.
- Measure Wi-Fi throughput and latency at near, normal and edge locations.
- Run at least 24 hours with DHCP renewals and normal household traffic.
- Check temperatures, load, memory, kernel logs and service restart counts.

## Mihomo Validation

- Prefer `tun.stack: mixed`: TCP uses the lower-overhead system stack while UDP
  uses gVisor.
- Allow the system stack's internal `198.18.0.2 -> 198.18.0.1` TCP traffic on
  the `Meta` input interface. Without it, fake-IP DNS and SOCKS work but
  transparent TCP times out.
- Confirm `br-lan` can forward to and from Mihomo's `Meta` TUN interface.
- Test DNS and HTTPS from a LAN client with all explicit proxy variables disabled.

## eMMC Gate

Install to eMMC only after wired reboot tests, Wi-Fi AP tests and rollback tests
all pass. Keep the validated SD card as rescue media. The initial image supports
IPv4 routing only; IPv6 and proxy migration need separate acceptance criteria.
