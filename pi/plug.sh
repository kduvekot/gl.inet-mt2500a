#!/usr/bin/env bash
# Switch the router's power through an IKEA DIRIGERA hub and its INSPELNING
# smart plug, so the Pi can power-cycle the router for UART recovery.
#
#   pi/plug.sh status            on/off, watts, volts, startup behaviour
#   pi/plug.sh on | off
#   pi/plug.sh cycle [seconds]   off, wait (default 5 s), on
#   pi/plug.sh startup <on|off|previous|toggle>
#                                state after a power cut; "off" keeps the
#                                router from starting by itself mid-experiment
#
# Only ever touches the one plug named $PLUG_NAME (default "MT2500A", as set
# in the IKEA Home smart app), and refuses if that name isn't found exactly
# once: other plugs in the house may drive anything (a space heater, say).
#
# Needs pi/dirigera-token.py to have been run once (hub name and token in
# ~/.config/dirigera/). The hub's local API is not documented by IKEA; the
# requests follow https://github.com/Leggin/dirigera.

set -euo pipefail

conf=$HOME/.config/dirigera
plug_name=${PLUG_NAME:-MT2500A}

[ -r "$conf/hub" ] && [ -r "$conf/token" ] || {
	echo "No hub or token in $conf; run pi/dirigera-token.py first." >&2
	exit 1
}
api="https://$(cat "$conf/hub"):8443/v1"
auth="Authorization: Bearer $(cat "$conf/token")"

# -k: the hub uses a self-signed certificate.
hub() {
	curl -skf --max-time 10 -H "$auth" "$@"
}

plug_id() {
	hub "$api/devices" | python3 -I -c '
import json, sys
m = [d["id"] for d in json.load(sys.stdin)
     if d.get("deviceType") == "outlet" and d["attributes"].get("customName") == sys.argv[1]]
if len(m) != 1:
	sys.exit("Expected exactly one plug named %r, found %d; nothing switched." % (sys.argv[1], len(m)))
print(m[0])' "$plug_name"
}

set_attr() {
	hub -o /dev/null -X PATCH -H 'Content-Type: application/json' \
		-d "[{\"attributes\":{$1}}]" "$api/devices/$id"
}

status() {
	hub "$api/devices/$id" | python3 -I -c '
import json, sys
d = json.load(sys.stdin); a = d["attributes"]
print("%s: %s, %s W, %.0f V, startup %s%s" % (a["customName"], "on" if a["isOn"] else "off",
	a.get("currentActivePower"), a.get("currentVoltage", 0), a.get("startupOnOff"),
	"" if d.get("isReachable", True) else " (NOT reachable)"))'
}

cmd=${1:-status}
id=$(plug_id)

case "$cmd" in
	status)
		status
		;;
	on | off)
		set_attr "\"isOn\":$([ "$cmd" = on ] && echo true || echo false)"
		sleep 2
		status
		;;
	cycle)
		set_attr '"isOn":false'
		echo "off; waiting ${2:-5} s"
		sleep "${2:-5}"
		set_attr '"isOn":true'
		sleep 2
		status
		;;
	startup)
		case "${2:-}" in
			on) v=startOn ;;
			off) v=startOff ;;
			previous) v=startPrevious ;;
			toggle) v=startToggle ;;
			*) echo "Usage: $0 startup <on|off|previous|toggle>" >&2; exit 1 ;;
		esac
		set_attr "\"startupOnOff\":\"$v\""
		sleep 2
		status
		;;
	*)
		sed -n '5,10p' "$0" | sed 's/^# \{0,1\}//' >&2
		exit 1
		;;
esac
