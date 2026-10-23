#!/usr/bin/env bash
# Run the router's serial console inside tmux, so that both a person (on the
# phone over SSH) and Claude Code (via commands) can use the same console.
#
#   ./console.sh start [port]   start picocom in tmux session "mt2500"
#   ./console.sh send <text>    type text followed by Enter
#   ./console.sh keys <keys>    send raw tmux keys, e.g. "C-c"
#   ./console.sh show [lines]   print the last lines of the screen (default 60)
#   ./console.sh attach         watch and type live (detach: Ctrl-B d)
#   ./console.sh stop           close the console and free the serial port
#
# Everything the router prints is also logged to logs/console-<time>.log.

set -euo pipefail

kit_dir=$(cd "$(dirname "$0")" && pwd)
session=mt2500

running() {
	tmux has-session -t "$session" 2> /dev/null
}

case "${1:-}" in
	start)
		port=${2:-/dev/serial0}
		if running; then
			echo "Console already running; use: $0 attach" >&2
			exit 1
		fi
		mkdir -p "$kit_dir/logs"
		log="$kit_dir/logs/console-$(date +%Y%m%d-%H%M%S).log"
		tmux new-session -d -s "$session" -x 200 -y 50 \
			picocom -b 115200 --send-cmd "sx -vv" --logfile "$log" "$port"
		echo "Console started on $port, logging to $log"
		;;
	send)
		shift
		running || { echo "Console not running; use: $0 start" >&2; exit 1; }
		tmux send-keys -t "$session" -l "$*"
		tmux send-keys -t "$session" Enter
		;;
	keys)
		shift
		running || { echo "Console not running; use: $0 start" >&2; exit 1; }
		tmux send-keys -t "$session" "$@"
		;;
	show)
		running || { echo "Console not running; use: $0 start" >&2; exit 1; }
		tmux capture-pane -t "$session" -p -S "-${2:-60}"
		;;
	attach)
		exec tmux attach -t "$session"
		;;
	stop)
		if running; then
			tmux kill-session -t "$session"
			echo "Console stopped."
		fi
		;;
	*)
		sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
		exit 1
		;;
esac
