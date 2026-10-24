# CLAUDE.md

Read this first in every session. The full story is in
[docs/journey.md](docs/journey.md); this file is the short version plus how
to work here.

## The project

GL.iNet GL-MT2500 / GL-MT2500A (Brume 2), MediaTek MT7981B:

1. **Upstream OpenWrt** (25.12.x) with properly working networking, built by
   GitHub workflows (ImageBuilder, both WAN PHY variants).
2. **Revive an old MT2500A** stuck at its U-Boot recovery page: uploads are
   accepted but never written. Likely cause: the 2022 U-Boot can't
   initialise the eMMC; GL.iNet's fixed 2025-02-24 U-Boot should, loaded
   over UART. The owner already has a working replacement unit; the old one
   is for experimenting.

## Working agreements (from the owner)

- **Ask before installing anything** (apt, pip, curl | bash, …) **and before
  any `sudo` command.** Show what will change first.
- **One command at a time** when the owner runs things. Chaining is fine
  when nothing needs checking in between; keep interactive steps separate.
- **Only create files the owner asked for.** Propose others and say why.
- Documents in **Markdown** (never Microsoft formats).
- Answer in English unless the owner writes in Dutch.
- Prefer **authoritative sources** (vendor docs, upstream repos) and check
  claims instead of answering from memory; say when something is our own
  construction rather than documented.
- Keep [docs/journey.md](docs/journey.md) up to date: a chapter per stage,
  a logbook line per milestone.
- **The repo is public: no secrets in it, not even encrypted** (tokens,
  setup codes), and no home-specific details (hub names, IDs, MACs,
  addresses, home domain). Those stay in local files on the Pi, such as
  `~/.config/dirigera/`.

## Where things stand (2026-10-24)

- Workflows on `main`: **Build OpenWrt**, **Recovery kit**, **Raspberry Pi
  OS image** (all Node 24 actions). The `recovery-kit` release is
  published (2026-10-23).
- Raspberry Pi set up and running Claude Code (below).
- **UART works** (2026-10-24): wired via a breadboard with 3 × 4.7 kΩ in
  parallel in Pi TX → J13 RX; `pi-setup.sh` done. The old U-Boot (Sep 12
  2022) fails the eMMC (`-110` / `-524`), as in Irakli's log. Console:
  `env -u TMUX ~/mt2500-recovery-kit/console.sh start|show|send|stop`
  (`env -u TMUX` because Claude itself runs inside the claude-rc tmux
  server); raw logs in `~/mt2500-recovery-kit/logs/`, on the Pi only.
- **Router power** is switchable from the Pi: `pi/plug.sh` (below).
- **Plan B works** (2026-10-24): the 2025-02-24 U-Boot loaded into RAM
  (`uartboot.sh -y` in tmux session `uartboot`, router switched with
  `pi/plug.sh`) reads the eMMC and its intact partition table. Nothing
  written yet; a power cycle brings back the old U-Boot. The published kit's
  `uartboot.sh` lacks the port-release fix: stop the console a few seconds
  before running it.
- **Full eMMC backup done** (2026-10-24), SHA256-verified against the
  router: `~/mt2500-backup/2026-10-24/` on the Pi (boot0, boot1, full image
  + `.zst`, `parts/`). boot1 holds the unit's MAC and serial number: **never
  put backup contents or their hashes in this public repo.** Method: OpenWrt
  initramfs over TFTP (`tftpd-hpa`, eth0 only, autostart off, TFTP root
  kept empty because GL's U-Boot auto-flashes `openwrt-gl-mt2500.bin` /
  `uboot-gl-mt2500.bin` from it), then `cat` over SSH. See the checklist,
  step 3b.
- **The old unit boots by itself again** (2026-10-24): the 2025-02-24 U-Boot
  is on the eMMC (`fip`, written with `dd` from the initramfs, verified),
  booting GL.iNet 4.7.4 (official, untouched), factory-reset and set up:
  English, Europe/Amsterdam, `root` password in
  `~/.config/mt2500/admin-password` on the Pi (never in the repo). Web UI
  and JSON-RPC at 192.168.8.1 from the Pi. Factory reset from failsafe:
  `mount_root; firstboot -y; sync; reboot -f` (without `mount_root` it does
  nothing on this firmware).
- **Next:** connect WAN and finish the internet setup, check the WAN PHY in
  `dmesg`, then decide between stock 4.7.4 and our OpenWrt build. Ask the
  owner before any write.
- WAN PHY: old unit MaxLinear GPY211C0VC (`glinet_gl-mt2500`; board
  MT2500-V1.1, DDR4 1 GB, Samsung 8 GB eMMC); replacement unknown (table in docs/journey.md). The old unit's UART is
  J13: 3.3V (square pad), RX, TX, GND, open through-holes.

## Hardware

- **Pi:** Raspberry Pi 3 Model B+, hostname `mt2500-bench`, user `kees`,
  Raspberry Pi OS Lite 64-bit (Trixie, 2026-10-06), WiFi only so far
  (DHCP). 905 MiB RAM; swap is rpi-swap (zram), not
  dphys-swapfile. Configured by cloud-init.
- **Wiring (done 2026-10-24):** Pi eth0 → router LAN port (the one next
  to J13; eth0 has 192.168.1.2 + 192.168.8.2, no gateway); Pi pins 6/8/10
  (GND/TXD/RXD; outer row, 3rd–5th from the end away from the USB ports) →
  J13 GND/RX/TX, 3.3V taped over, ~1.57 kΩ in the Pi TX line.
  `/dev/serial0 → ttyAMA0`.
- **Routers:** the old MT2500A (stuck at U-Boot) and a working replacement.
- **Router power:** an IKEA INSPELNING smart plug named **`MT2500A`**, via
  the house's IKEA DIRIGERA hub (found by mDNS). `pi/plug.sh status|on|off|
  cycle [s]|startup <on|off|previous|toggle>`; hub name and token in
  `~/.config/dirigera/` (from `pi/dirigera-token.py`). **Only ever switch
  `MT2500A`**: another plug drives a space heater.

## Claude on the Pi

- Claude Code (native install, `~/.local/bin/claude`), signed in to the
  owner's claude.ai account.
- **`claude-rc.service`** (systemd *user* service, linger on) runs
  [pi/claude-rc.sh](pi/claude-rc.sh): `claude remote-control --name
  mt2500-bench --spawn same-dir` in its own tmux server, restarted when it
  exits and started at boot. Sessions are started and switched from
  claude.ai/code or the Claude app. Reboot tested 2026-10-23: online
  again ~30 s after boot, with the served session and its history restored.
  - Status: `systemctl --user status claude-rc.service`
  - Terminal: `tmux -L claude-rc attach -t claude-rc` (detach: Ctrl-B, D)
- The original conversation (`fee797e3-…`) ran interactively in tmux
  session `claude`; that isn't a service, so it ended with the reboot.
  Reopen it from SSH with `cd ~/gl.inet-mt2500a && claude --resume`.
- The user journal isn't persistent (`journalctl --user` is empty); the
  service's output is in its tmux pane:
  `tmux -L claude-rc capture-pane -p -t claude-rc`.

## Earlier conversations (transcripts)

Claude Code stores every local conversation as JSONL under
`~/.claude/projects/<working dir with / replaced by ->/<session id>.jsonl`.
For this repo: `~/.claude/projects/-home-kees-gl-inet-mt2500a/`.

- **`fee797e3-b250-41f4-aa39-ff37ae0b083e.jsonl`** is the main conversation:
  research, workflows, recovery plan, Pi setup. It started as cloud session
  `session_015oH4BS3ForAmc3LiC2czZ9` and was teleported to the Pi, so it
  holds the whole history from the first message (~2000 lines, several MB:
  search it, don't read it whole).
- Other files there are later sessions (for example those started by
  `claude-rc.service`); `ls -lt` shows the newest first.

Each line is one JSON record; the conversation is in records with
`"type": "user"` or `"assistant"`, text under `message.content` (a string, or
a list of parts with `"type": "text"`). Timestamps are UTC. To search
(no `jq` on the Pi; Python is there):

```sh
python3 -I -c '
import json, re, sys
pat = re.compile(sys.argv[2], re.I)
for line in open(sys.argv[1]):
    d = json.loads(line)
    if d.get("type") not in ("user", "assistant"):
        continue
    c = d["message"]["content"]
    texts = [c] if isinstance(c, str) else [p.get("text", "") for p in c if p.get("type") == "text"]
    for t in texts:
        if pat.search(t):
            print("---", d["type"], d.get("timestamp", "")[:16])
            print(t[:400])
' ~/.claude/projects/-home-kees-gl-inet-mt2500a/fee797e3-b250-41f4-aa39-ff37ae0b083e.jsonl 'search words'
```

## Repo map

- `.github/workflows/`: `build-openwrt.yml`, `recovery-kit.yml`,
  `raspios-image.yml`
- `openwrt/packages.txt`: extra packages for the OpenWrt images
- `recovery/`: `pi-setup.sh`, `uartboot.sh`, `console.sh`, `web-flash.sh`
- `pi/`: `claude-rc.sh`, `claude-rc.service`, `dirigera-token.py`,
  `plug.sh`
- `docs/`: `journey.md`, `firmware-sources.md`,
  `recovery-uart-raspberry-pi.md`, `raspberry-pi-sd-chromebook.md`

## Git

- Work on branch `claude/gifted-edison-lbt8ep`; changes reach `main` through
  pull requests the owner merges.
- The Pi clone pushes over HTTPS with a fine-grained token for this repo
  only (Contents and Pull requests: read/write), stored in
  `~/.git-credentials`. There's no `gh` CLI; check Actions runs and
  releases through the public GitHub API with `curl`.
