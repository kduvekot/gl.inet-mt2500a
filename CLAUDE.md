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
- **Nothing new after midnight (owner, 2026-10-29):** from 00:00 no new
  jobs, subagents or work of any kind, and no analysis of tasks that
  finish (not even in check-ins); what is already running may finish
  unreviewed until the owner resumes. The rule is about Claude's token
  use (owner, 2026-10-30): queued M5+ jobs may keep running through the
  night without a watcher, as long as everything needed afterwards is
  kept (reports, logs, trees).
- **Order of work:** a release step only after the previous base is
  validated; `docs/releases.md` only once all releases are done (collect
  data meanwhile). No GPL source request to GL.iNet until all firmwares
  are done (owner, 2026-10-27); keep the list of not-public parts current.
- **Naming:** GitHub workflow runs by their run number (#N); M5+ jobs by
  their queue number: plain increasing integers from 101 on (owner,
  2026-10-31; older jobs 02–99zzz16 keep their names), e.g.
  `101-validation-4.8.2.args`. A preflight (dry run up to defconfig) only
  when a release's configuration changes, as its own number: `101` the
  preflight, `102` the build with `needs=101`; small-fix re-validations go
  without one (`recipecheck.sh` first).
- **Decompilation** (private repo): one commit per iteration, never
  squashed.

## Where things stand (2026-10-31)

Details and history are in docs/journey.md (chapters plus logbook).

**Infrastructure**
- Workflows on `main`: **Build OpenWrt**, **Recovery kit** (release
  published 2026-10-23), **Raspberry Pi OS image** (Node 24 actions).
- Pi runs Claude Code (below). UART works (J13 via breadboard, 3 × 4.7 kΩ
  in Pi TX); console `env -u TMUX ~/mt2500-recovery-kit/console.sh
  start|show|send|stop`; logs only on the Pi. Router power: `pi/plug.sh`.
- **Old unit recovered** (2026-10-24): 2025-02-24 U-Boot in `fip`; runs
  GL.iNet 4.7.4 (latest stable for the MT2500; 4.8.2/4.9.0 are testing),
  factory-reset, at 192.168.8.1 from the Pi; root password in
  `~/.config/mt2500/admin-password`; SSH with
  `SSH_ASKPASS=~/.config/mt2500/askpass.sh`. WAN on the home LAN. Failsafe
  reset: `mount_root; firstboot -y; sync; reboot -f`.
- **Full eMMC backup** `~/mt2500-backup/2026-10-24/` on the Pi (and NAS):
  boot1 holds MAC and serial, **never put contents or hashes in this repo.**
- WAN PHY: old unit GPY211C0VC (`glinet_gl-mt2500`, MT2500-V1.1, 1 GB,
  8 GB eMMC); replacement EN8811H (`glinet_gl-mt2500-airoha`, 4.7.13).

**Recreation of GL.iNet's firmware (journey chapters 13–15)**
- One recipe (`gl-recreate-4.2.0.yml`), a row per release in
  `openwrt/gl-releases.tsv` (values: `patches_rev`, `extra_config`,
  `feed_revs`, `extra_commits` in `openwrt/gl-extra-commits/`,
  `early_patches`, `sdk_mode`, `build_dir`, `umask`). Closed packages are
  generated in the run from the official image; release-specific recipes
  in `openwrt/gl-4.2.0-closed/overrides@<from>..<to>/`; workflows publish
  reports only. Accepted differences: Samba library order, `.pyc` order,
  vermagic hash, `wg`'s tree hash (and the `Installed-Size` it shifts).
- **All 15 releases validated without ccache** (final batch 99zzz01–15,
  jobs 101/102, 2026-10-31): counts and differing-file lists as before;
  `docs/closed-binaries/` regenerated (`analysis/private-binaries.py`).
  4.1.1–4.5.16 kernel byte-identical; 4.6.2–4.9.0 kernel public except the
  not-public parts (journey ch. 15 list).
- **Private (repo `mt2500-decomp`, name in memory; never here):**
  - Kernel bridged for 4.6.2–4.9.0: Image identical except the 20-byte
    build ID, which covers DWARF of GL.iNet's not-public source (needs their
    files; gl-image already searched).
  - GL.iNet's own kernel modules byte-identical in every release except
    `kmwan` 4.5.0 (17 bytes in `remove_netcell`, accepted, open; ~11,000
    variants, generator `~/agent/kmgen/` on the M5+).
  - All closed Lua reconstructed (unluac, owner-approved; line layout from
    the bytecode). Closed C programs partly (C decompilation stopped by the
    safety classifier: don't retry); bridging close public versions
    function by function is owner-approved (`tools/kbridge.sh`, `vbridge.sh`).
  - Wi-Fi baggage out of scope (owner, 2026-10-30): `mt_wifi`,
    `mtk_warp_proxy`, `mtk_warp`, `mtfwd`, `mtqos`, `fwdd`.
- Lessons: when code placement differs, check the data structures it
  touches; measure function lengths in GL.iNet's binary; compare `__LINE__`
  values as sorted sets; blank-line layout is our construction.
- Left: closed C programs, `docs/releases.md` (only when all is done), GPL
  source request to GL.iNet afterwards.

**M5+ workflow**
- Two workers (`~/queue/`, `~/queue2/`, tmux `queue`/`queue2`, log
  `~/queue.log`, verdict `~/brief.sh <job>`); jobs numbered 101, 102, …
- Each keeps its last tree (`~/trees/w1|w2`, `~/rebuild.sh`); finished trees
  in `~/archive/trees/` (60 days, owner 2026-10-31; 500 GB). `kernel=true`: kernel-only tree.
  M5+ scripts backed up in the private repo (`tools/m5/`, `tools/variants/`).
  `~/recipecheck.sh <release>` before queueing.
- **Subagents** (Sonnet; Haiku for simple checks) work in
  `~/agent/mt2500-decomp` (branch `agent/*`; refresh by pushing the Pi's
  private `main` to its `pi-main`), push with `~/agent/push-private.sh`;
  the main session verifies by rebuilding and merges. Brief them: copy only
  `src/` and `build.opts`, push after every commit, no waits or monitors.

**Next:** phase C (upstream OpenWrt on the old unit, iperf with the
GMKtec). Ask the owner before any write to a router.

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
