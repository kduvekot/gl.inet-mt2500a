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

## Where things stand (2026-10-23)

- Workflows on `main`: **Build OpenWrt**, **Recovery kit**, **Raspberry Pi
  OS image** (all Node 24 actions). The `recovery-kit` release is
  published (2026-10-23).
- Raspberry Pi set up and running Claude Code (below).
- **Waiting on cables:** female-female jumper wires, a 1 kΩ resistor, maybe
  a pin header or test hooks if the router's UART is bare pads (shopping
  trip to Fakkert, Zwolle).
- **Next:** run `recovery/pi-setup.sh --download` on the Pi (needs `sudo`
  and a reboot; ask first; the reboot is also the first test of
  `claude-rc.service`) → open the old router and wire the UART → follow
  [docs/recovery-uart-raspberry-pi.md](docs/recovery-uart-raspberry-pi.md).
- WAN PHY of both routers still unknown (table in docs/journey.md).

## Hardware

- **Pi:** Raspberry Pi 3 Model B+, hostname `mt2500-bench`, user `kees`,
  Raspberry Pi OS Lite 64-bit (Trixie, 2026-10-06), WiFi only so far
  (172.31.125.180 via DHCP). 905 MiB RAM; swap is rpi-swap (zram), not
  dphys-swapfile. Configured by cloud-init.
- **Planned wiring** (not done yet): Pi eth0 → router LAN port (eth0 gets
  192.168.1.2 + 192.168.8.2, no gateway, via `pi-setup.sh`); Pi pins 6/8/10
  (GND/TX/RX) → router UART GND/RX/TX, never 3V3, ideally 1 kΩ in series on
  Pi TX. `/dev/serial0` only exists after `pi-setup.sh` and a reboot.
- **Routers:** the old MT2500A (stuck at U-Boot) and a working replacement.

## Claude on the Pi

- Claude Code (native install, `~/.local/bin/claude`), signed in to the
  owner's claude.ai account.
- **`claude-rc.service`** (systemd *user* service, linger on) runs
  [pi/claude-rc.sh](pi/claude-rc.sh): `claude remote-control --name
  mt2500-bench --spawn same-dir` in its own tmux server, restarted when it
  exits and started at boot. Sessions are started and switched from
  claude.ai/code or the Claude app. Reboot behaviour not tested yet.
  - Status: `systemctl --user status claude-rc.service`
  - Terminal: `tmux -L claude-rc attach -t claude-rc` (detach: Ctrl-B, D)
- The original conversation also runs interactively in tmux session
  `claude` (default tmux server): `tmux attach -t claude`.

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
- `pi/`: `claude-rc.sh`, `claude-rc.service`
- `docs/`: `journey.md`, `firmware-sources.md`,
  `recovery-uart-raspberry-pi.md`, `raspberry-pi-sd-chromebook.md`

## Git

- Work on branch `claude/gifted-edison-lbt8ep`; changes reach `main` through
  pull requests the owner merges.
- The Pi clone pushes over HTTPS with a fine-grained token for this repo
  only (Contents and Pull requests: read/write), stored in
  `~/.git-credentials`. There's no `gh` CLI; check Actions runs and
  releases through the public GitHub API with `curl`.
