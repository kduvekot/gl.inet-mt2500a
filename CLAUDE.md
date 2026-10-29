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
- **Ask before anything that might trigger the safety check** (owner,
  2026-10-28): running downloaded or external programs (e.g. unluac),
  decompilers, or similar; get explicit permission first, before even
  trying it.
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

## How Claude works here (from the owner)

- **Do what you announce.** "Next I'll do X" means doing X in the same
  turn. End a turn only with the work done or a named blocker (a running
  build, the owner's decision), and say what you're waiting for.
- **Keep going.** After each step ask "what's next?" and continue with
  useful work in scope (prep for later releases, tooling, docs); stop only
  when nothing is left but waiting. Explicit gates still apply (installs and
  sudo on the Pi, router writes, the owner's decisions).
- **Check the journey first.** Before analysing a difference or topic,
  `grep -n -i` docs/journey.md (chapter 13's accepted differences, the
  logbook); build on it, and report what's known vs new.
- **Keep docs current.** Reflect at least every 30 minutes; every real
  finding or milestone goes into docs/journey.md (chapter text plus a
  logbook line) in the same turn, also during hourly check-ins.
- **Never wait in a foreground command** (`sleep`, polling over SSH):
  waits run as background tasks; act when notified. When a watcher's
  notification arrives, restart the watcher first, while jobs are still
  queued or running; otherwise results go unnoticed (2026-10-27: three
  jobs finished unseen).
- **Scripts first, few tokens:** bulk work in scripts or workflows that
  write a short summary; raw output stays in files. Cheap subagents for
  searches; verify their claims before relaying them.
- **Commits:** `git -c user.name=Claude -c user.email=noreply@anthropic.com`
  (no global identity on the Pi); stage files by name or `-u`, never
  `git add -A` (2026-10-27 it committed `__pycache__` files, which then
  blocked the M5+ worker's `git pull`); after pushing, check with
  `git ls-remote` before queueing jobs (jobs pull the branch). Open PRs as needed; the owner
  merges.
- **Check scripts and their inputs** before running them: shellcheck the
  build script (extracted from the workflow), YAML-check workflows, and
  check what a script will act on (e.g. `rebuild.sh` only on trees of
  finished builds). For a one-file question, run just that make target.
  Experiments that change a tree (patch swaps, config edits) run on a
  copy, and every step's result is checked before the next (2026-10-27: a
  patch swap in an archived tree failed halfway and damaged its kernel
  source). Every patch we generate is test-applied the way OpenWrt
  applies it (`patch -p1` on the source with the preceding patches)
  before it's committed; new files need `--- /dev/null` (2026-10-27: the
  musl patch lost its new file and job 70b built without it).
  Generated recipes too: before queueing a release, `~/recipecheck.sh
  <release> [private_now]` on the M5+ (OpenWrt parses every closed recipe,
  ~1 min) (2026-10-28: 4.9.0's preflight 99p lost to a missing `kernel.mk`).
- **M5+ workers:** address tmux sessions exactly (`tmux kill-session -t
  =queue`; a plain `-t queue` also matches `queue2`: 2026-10-28 it killed
  w2's job mid-build and w2 sat idle for 80 minutes). After touching a
  worker, check `tmux ls` shows both `queue` and `queue2`; every check-in
  confirms both workers are alive, not only that the log moved.
- **Watching runs:** by run id with the token; never `pkill -f` or
  `pgrep -f` a pattern that occurs in your own command line (wait on a
  file or the queue log instead); long builds print progress with
  `grep --line-buffered`, save logs with `if: always()`, keep a time limit.
- **Full runs are for batches (owner, 2026-10-28):** a byte-identical
  replacement for one closed binary is proven with a targeted compile
  (the binary alone, against that release's tree or SDK); full runs only
  after the whole set of binaries has been gone through and several
  fixes are in, never for one binary on an already proven release.
- **Order of work:** a release step only after the previous base is
  validated; `docs/releases.md` only once all releases are done (collect
  data meanwhile). No GPL source request to GL.iNet until all firmwares
  are done (owner, 2026-10-27); keep the list of not-public parts current.
- **Naming:** GitHub workflow runs by their run number (#N); M5+ jobs by
  their queue number.
- **Decompilation** (private repo): one commit per iteration, never
  squashed.

## Where things stand (2026-10-28)

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
- WAN of the old unit is connected (home LAN switch); GL.iNet 4.7.4
  running, used for read-only analysis.
- **Analysis done** (docs/driver-analysis.md, journey chapters 11-12):
  phases A and B (vendor vs mainline drivers), 16 firmware versions
  compared, GL.iNet 4.2.0 recreated (kernel config and all modules
  identical; SDK published as release `gl-4.2.0-sdk`), phase D (closed
  modules: only `mtkhnat` touches hardware and it is public code), kernel
  image byte-identical when built without ccache (2026-10-26; with ccache
  the build IDs differ). The
  decompiled code lives in a private repo on the owner's account (name in
  Claude's memory), never in this one.
- **4.2.0 recreation, complete image** (journey chapter 13, 2026-10-25):
  public part identical except accepted differences (Samba library order
  and ~25 `.pyc`, both random in GL.iNet's own builds too; vermagic hash;
  `wg`'s tree hash). The complete image, with GL.iNet's closed packages
  generated *inside the run* from the official image, builds on the free
  public runners: `gl-recreate-4.2.0.yml` input `closed` (full build) or
  `gl-assemble-4.2.0.yml` (published SDK + ImageBuilder, ~10 min). Both
  publish reports only, never the image. 466 packages, 6071 files like the
  official, `status` identical apart from vermagic, every `Installed-Size`
  explained. **Validated 2026-10-26** (two runs without ccache, identical);
  Samba and `.pyc` differences proven to be order only (function-by-function
  and code-object comparison, journey chapter 13).
- **Release by release (2026-10-27, journey chapter 15):** one recipe, a
  row per release in `openwrt/gl-releases.tsv` (workflow input `release`);
  release values found so far: `patches_rev` (4.4.x came from a release
  branch: patch folder of 25 June 2023, 4.4.6 plus the wireguard fix),
  `extra_config`, `feed_revs` (gl-feeds pinned by `SourceDateEpoch`,
  `analysis/release-values.py` reads all releases' values in one run),
  `extra_commits` (`openwrt/gl-extra-commits/`: GL.iNet patches missing
  from the public set, two of them published in `gl-inet/gl-image`, plus a
  labelled placeholder for 4.5.x's unidentified 885th commit, kept until a
  reason to remove it or its real content is found). Build-machine orders
  are read from the official binaries (`.github/scripts/link-order.py`).
  **Proved** (validated without ccache, only the accepted classes left):
  4.1.1, 4.2.0, 4.2.1, 4.2.3, 4.4.5, 4.4.6, 4.5.0, 4.5.16 (2026-10-28).
  4.6.2, 4.6.4, 4.6.8: reproducible without ccache; left only the
  not-public parts (journey ch. 15 keeps the list, 13 items) and
  `ethsys_reset`. 4.7.0, 4.7.4 (99k): reproducible without ccache, left
  only the not-public parts. 4.8.2 (99y, 99zb without ccache): at that level too. 4.9.0 (99ze, without ccache): at that level too (cfg80211
  kernel config, WireGuard 954, AdGuardHome 0.107.56 frontend, conninfra
  and ubusd from public sources). Release values beyond the first ones:
  `sdk_mode` (4.8.2+ built with SDK=1, empty revision), `build_dir`
  (4.1.1 Actions runner, Jenkins path from 4.7.0), `umask` (002 from
  4.7.0), `early_patches` also as a range (4.8.2+). Release-specific
  closed-package recipes: `openwrt/gl-4.2.0-closed/overrides@<release>/`;
  feed-specific source patches: `openwrt/gl-4.2.0-patches/<pkg>@<feed>/`.
  GL.iNet's private MediaTek feed is called `mt798x` from 4.6.2 on.
  `gl-inet/gl-image` holds complete GPL trees of later GL.iNet releases
  for other models (gl-be10000 `versions/4.8.6`, gl-be14000 `4.9.1`,
  gl-mt3600be `4.8.7`/`4.9.0`): source for GL.iNet's package patches and
  some of their own packages (e.g. `gl-sdk4-nas-exfat`).
- **M5+ workflow:** two job workers (`~/queue/`, `~/queue2/`, verdict
  `~/brief.sh NN`), each keeps its last OpenWrt tree (`~/trees/w1|w2`) for
  `~/rebuild.sh <w> <package>` (minutes instead of a ~31-minute full run).
- **Closed binaries:** 11 of 45 byte-identical (private repo `user/`,
  `results/user/`); origins inventory in the private repo
  `notes/oss-origins-4.2.0.md`. Further work on them stopped (safety
  classifier stops). `docs/releases.md` only once all releases are done.
  Public origins found 2026-10-28 and turned into recipes (build steps in
  `overrides@<from>..<to>/…/build.mk`, which keep the generated recipe's
  metadata): 4.5.16 Tailscale (official 1.58.2 release, sstripped),
  4.1.1–4.7.0 `oui/system.so` (oui `lsystem.c`, `-O1`), 4.8.2/4.9.0
  bundled LuCI ipks (our own LuCI builds), `black_white_list.ko`
  4.7.4/4.8.2 and `parental_control.ko` 4.8.2 (gl-image sources). Leads
  are found with string scans against local sources (`~/provenance.py`,
  `~/kmodsrc.sh` on the M5+); "GL.iNet's own code" only on evidence.
  Private reconstructions (`reconstructed/<release>/<package>/` in the
  private repo): all compiled Lua 5.1/5.3/5.4 with build-path chunk names
  (unluac 2025, owner-approved, plus `tools/lnum2std.py`, `lua5xstd.py`,
  `relayout.py`), data-only Lua, `oopslog` 4.1.1-4.7.0. C decompilation
  stops on the safety classifier (2026-10-28 again): don't retry it.
  Bridging a close public version function by function (disassembly
  compared with our build, source edited, one commit per step) is
  owner-approved (2026-10-28): private `tools/kbridge.sh` for kernel
  modules; 4.9.0 `mtk_warp.ko` done that way.
- **Next:** phase C (upstream
  OpenWrt on the old unit, iperf with the GMKtec). Ask the owner before any
  write to a router.
- WAN PHY: old unit MaxLinear GPY211C0VC (`glinet_gl-mt2500`; board
  MT2500-V1.1, DDR4 1 GB, Samsung 8 GB eMMC); replacement Airoha EN8811H (`glinet_gl-mt2500-airoha`; GL.iNet 4.7.13; table in docs/journey.md). The old unit's UART is
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
  `raspios-image.yml`, `gl-recreate-4.2.0.yml` (inputs `ccache`,
  `publish_sdk`, `closed`), `gl-assemble-4.2.0.yml`, `sdk-package.yml`,
  `gl-versions.yml`; `.github/scripts/`: `compare-firmware.py`,
  `classify-diffs.py`, `control-diffs.py`, `fit-ikconfig.py`,
  `gen-closed-feed.py`, `version-diff.py`
- `openwrt/gl-4.2.0-patches/`: our patches for build-machine effects
  (iproute2 order); `openwrt/gl-4.2.0-closed/`: what the closed part needs
  besides the official image (three source-built recipes, image-file paths)
- `analysis/`: `collect-baseline.sh`, `summarize-baseline.py`,
  `source-diff.py`, `firmware-versions.py`, `release-values.py`,
  `kernel-functions.py` (two kernels function by function, with
  vmlinux-to-elf for GL.iNet's)
  and `private-binaries.py` (generates `docs/closed-binaries/`: every
  binary we can't build identically, per release; rerun after new results)
- `openwrt/packages.txt`: extra packages for the OpenWrt images
- `recovery/`: `pi-setup.sh`, `uartboot.sh`, `console.sh`, `web-flash.sh`,
  `get-stock-firmware.sh` (GL.iNet's firmware is fetched from GL.iNet, never
  bundled or stored in this public repo; private copies go on the NAS)
- `pi/`: `claude-rc.sh`, `claude-rc.service`, `dirigera-token.py`,
  `plug.sh`
- `docs/`: `journey.md`, `closed-binaries/`, `firmware-sources.md`, `driver-analysis.md`
  (plan: `driver-analysis-plan.md`), `recovery-uart-raspberry-pi.md`, `raspberry-pi-sd-chromebook.md`

## Git

- Work on branch `claude/gifted-edison-lbt8ep`; changes reach `main` through
  pull requests the owner merges.
- The Pi clone pushes over HTTPS with a fine-grained token for this repo
  only (Contents and Pull requests: read/write), stored in
  `~/.git-credentials`. There's no `gh` CLI; check Actions runs and
  releases through the public GitHub API with `curl`.
