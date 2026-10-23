#!/usr/bin/env bash
# Keep a Claude Code Remote Control server running on the Pi, so it can be
# used from claude.ai/code or the Claude app without an SSH session.
#
# Started at boot by pi/claude-rc.service, inside tmux session "claude-rc"
# (Remote Control needs a terminal). Look at it with: tmux -L claude-rc attach -t claude-rc
#
# Each round:
#   1. wait until api.anthropic.com is reachable (WiFi may still be coming up)
#   2. start the server; it brings back every session it was serving (for
#      ~4 hours after a stop), otherwise it starts a new one. Further
#      sessions can be started from claude.ai/code or the Claude app.
#   3. if claude exits for any reason, wait 30 s and start again

export PATH="$HOME/.local/bin:$PATH"
cd "$HOME/gl.inet-mt2500a" || exit 1

name=$(hostname)

while true; do
	until curl -s -o /dev/null -m 10 https://api.anthropic.com; do
		echo "$(date '+%F %T') waiting for network..."
		sleep 10
	done

	echo "$(date '+%F %T') starting claude remote-control"
	claude remote-control --name "$name" --spawn same-dir

	echo "$(date '+%F %T') claude exited ($?); restarting in 30 s (Ctrl-C to stop)"
	sleep 30
done
