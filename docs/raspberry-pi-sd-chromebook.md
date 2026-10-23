# Raspberry Pi OS on an SD card, using only a Chromebook

How to prepare the Raspberry Pi 3's SD card without Raspberry Pi Imager.
Imager can't see SD cards from the ChromeOS Linux environment, so we use
the **Chromebook Recovery Utility** instead.

The catch: Raspberry Pi OS ships as `.img.xz`. The Recovery Utility lists
those files, but then "finishes" without writing anything (see the
[Raspberry Pi documentation PR](https://github.com/raspberrypi/documentation/pull/2517)
and the [Raspberry Pi forum](https://forums.raspberrypi.com/viewtopic.php?t=378633)).
It does write a `.zip` that contains the `.img`. The
[Raspberry Pi OS image workflow](../.github/workflows/raspios-image.yml)
makes that zip for us.

## Which SD card?

**16 GB is enough.** The image is 3.1 GB and the OS expands to fill the
card. Claude Code, the recovery kit, logs and 2 GB of swap leave around
8 GB free.

32 GB has one real advantage: the same writes are spread over more flash,
and swap writes a lot. So pick the **better card** (a known brand, rated
A1/A2). If both are equally good, take the 32 GB one.

## 1. Build the zip on GitHub

- [ ] GitHub → **Actions** → **Raspberry Pi OS image** → **Run workflow**.
- [ ] Wait about 5 minutes. The workflow:
  - finds the latest *Raspberry Pi OS Lite (64-bit)* in the official image
    list that Raspberry Pi Imager uses, filtered to images that support the
    Pi 3
  - downloads it from `downloads.raspberrypi.com` and checks it against the
    published `.sha256`
  - unpacks it and checks the SHA256 of the image itself against the image
    list
  - zips the image unmodified and publishes it as the release
    **`raspios-lite-arm64`**. A release lets the zip download directly, where
    an Actions artifact would wrap it in a second zip.
- [ ] Open the release on the Chromebook and download the `.zip` (about
      850 MB for the 2026-10-06 Trixie image).

## 2. Write the SD card

- [ ] Install the **Chromebook Recovery Utility** from the Chrome Web Store.
- [ ] Open it, click the **gear icon** (top right), then **Use local image**,
      and pick the downloaded `.zip`.
- [ ] Choose the SD card, then **Continue** → **Create now**. Writing takes a
      few minutes.

## 3. Configure first boot (cloud-init)

Raspberry Pi OS Trixie is configured on first boot by **cloud-init**,
from text files on the card's FAT32 boot partition. Raspberry Pi Imager
normally writes these for you; here you edit them yourself.

- [ ] Take the card out and put it back in. ChromeOS Files shows a drive
      called **bootfs**.
- [ ] Open `user-data` with the **Text** app, replace **everything** in it
      with the block below, then adjust the values. Use spaces only, never
      tabs: YAML is strict about indentation.

```yaml
#cloud-config
hostname: mt2500-bench
manage_etc_hosts: true
timezone: Europe/Amsterdam

users:
- name: kees
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  lock_passwd: false
  plain_text_passwd: CHANGE-ME
  sudo: ALL=(ALL) NOPASSWD:ALL

enable_ssh: true
ssh_pwauth: true

# Belt and braces: make sure the SSH server is on even if enable_ssh is ignored
runcmd:
- [systemctl, enable, --now, ssh]
```

- [ ] Open `network-config`, replace everything with this, and fill in your
      WiFi details:

```yaml
network:
  version: 2
  renderer: NetworkManager
  wifis:
    wlan0:
      dhcp4: true
      optional: true
      regulatory-domain: "NL"
      access-points:
        "YourWiFiName":
          password: "YourWiFiPassword"
```

- [ ] Leave `meta-data` alone. Eject the card from Files before removing it.

Notes:

* **WiFi:** the original Pi 3 Model B only has **2.4 GHz** WiFi; the 3B+
  also has 5 GHz. Set `regulatory-domain` to the country you're in.
  Without it, WiFi stays switched off.
* **Leave out `eth0` on purpose.** `recovery/pi-setup.sh` configures eth0
  later for the router's LAN port: fixed addresses, no gateway.
* **Leave out the `rpi: serial: true` option.** It would put a Linux login
  console on the UART pins we need for the router.
* **Change the password.** It's stored in plain text on the boot partition,
  and cloud-init only applies it on first boot. After that, change it with
  `passwd` and delete the line from `user-data`.
* **SSH from the phone** with password login (`ssh_pwauth: true`), for
  example with Termius. Adding an SSH key and setting `ssh_pwauth: false`
  is safer once that works.

## 4. First boot

- [ ] Put the card in the Pi 3 and power it. The first boot takes a few
      minutes: it expands the filesystem and runs cloud-init.
- [ ] Find the Pi's IP address in your home router's DHCP list, or try
      `mt2500-bench.local`.
- [ ] `ssh kees@<address>`, then check:
      `uname -m; dpkg --print-architecture; free -h`. Expect
      `aarch64`, `arm64`, and about 900 MB of RAM.

Next: the Claude-on-the-Pi test (journey chapter 5), and
`recovery/pi-setup.sh` (see [the recovery checklist](recovery-uart-raspberry-pi.md)).

## Sources

* Image list and download: `https://downloads.raspberrypi.com/os_list_imagingutility_v4.json`,
  `https://downloads.raspberrypi.com/raspios_lite_arm64/images/`
* [Cloud-init on Raspberry Pi OS](https://www.raspberrypi.com/news/cloud-init-on-raspberry-pi-os/) (official announcement, `user-data` and `network-config` examples)
* [Forum: WiFi on first boot without Imager (Trixie)](https://forums.raspberrypi.com/viewtopic.php?t=395107)
* The default `user-data`, `network-config` and `meta-data` files inside
  the 2026-10-06 image, read directly from its boot partition
