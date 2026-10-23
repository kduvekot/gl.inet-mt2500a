#!/usr/bin/env python3
"""Pair the Pi with an IKEA DIRIGERA hub: get a token for its local API.

    pi/dirigera-token.py [hub]

Without [hub], the hub is found on the local network via mDNS (service
_ihsp._tcp). Then press the Action button on the bottom of the hub (not
Reset) within 90 s. Results, outside the repo:

    ~/.config/dirigera/hub     the hub's mDNS name (e.g. gw2-xxxxxxxxxxxx.local)
    ~/.config/dirigera/token   the access token, mode 0600: full control
                               of the hub, treat it like a password

Pairing again is harmless; earlier tokens stay valid. Only the Python
standard library is used.

The local API is not documented by IKEA. The flow (OAuth with PKCE on
port 8443) follows the community library https://github.com/Leggin/dirigera
(MIT); a hub firmware update may change it.
"""
import base64, hashlib, json, os, secrets, socket, ssl, string, struct, sys, time
import urllib.error, urllib.parse, urllib.request

conf_dir = os.path.expanduser("~/.config/dirigera")


def mdns_find_hub(timeout=4):
	"""Return the mDNS host name of the first hub answering for _ihsp._tcp."""
	service = "_ihsp._tcp.local"
	qname = b"".join(bytes([len(p)]) + p.encode() for p in service.split(".")) + b"\0"
	query = struct.pack("!6H", 0, 0, 1, 0, 0, 0) + qname + struct.pack("!HH", 12, 0x8001)
	s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
	s.settimeout(0.5)
	s.sendto(query, ("224.0.0.251", 5353))
	deadline = time.time() + timeout
	while time.time() < deadline:
		try:
			buf, _ = s.recvfrom(9000)
		except socket.timeout:
			continue
		# The hub's TXT record carries "hostname=gw2-..."; no full DNS parse needed.
		i = buf.find(b"hostname=")
		if i >= 0:
			n = buf[i - 1] - len(b"hostname=")
			return buf[i + 9:i + 9 + n].decode() + ".local"
	return None


hub = sys.argv[1] if len(sys.argv) > 1 else mdns_find_hub()
if not hub:
	sys.exit("No DIRIGERA hub found via mDNS; give its name or IP as argument.")
print("Hub: %s" % hub)

base = "https://%s:8443/v1" % hub
ctx = ssl._create_unverified_context()  # the hub uses a self-signed certificate

alphabet = "_-~." + string.ascii_letters + string.digits
verifier = "".join(secrets.choice(alphabet) for _ in range(128))
challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()

q = urllib.parse.urlencode({"audience": "homesmart.local", "response_type": "code",
                            "code_challenge": challenge, "code_challenge_method": "S256"})
with urllib.request.urlopen(base + "/oauth/authorize?" + q, context=ctx, timeout=10) as r:
	code = json.load(r)["code"]
print("Press the Action button on the bottom of the hub now (90 s).", flush=True)

# The hub answers with an error until the button is pressed, so retry
# instead of waiting for Enter: this also works when run unattended.
body = urllib.parse.urlencode({"code": code, "name": socket.gethostname(),
                               "grant_type": "authorization_code",
                               "code_verifier": verifier}).encode()
last = "no answer"
deadline = time.time() + 90
while time.time() < deadline:
	req = urllib.request.Request(base + "/oauth/token", data=body,
	                             headers={"Content-Type": "application/x-www-form-urlencoded"})
	try:
		with urllib.request.urlopen(req, context=ctx, timeout=10) as r:
			token = json.load(r)["access_token"]
		break
	except urllib.error.HTTPError as e:
		last = "HTTP %d" % e.code
		time.sleep(2)
else:
	sys.exit("No token within 90 s (last answer: %s). Run again and press the button." % last)

os.makedirs(conf_dir, mode=0o700, exist_ok=True)
for name, value, mode in (("hub", hub, 0o644), ("token", token, 0o600)):
	path = os.path.join(conf_dir, name)
	fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
	with os.fdopen(fd, "w") as f:
		f.write(value + "\n")
print("Stored the hub name and the token (%d characters, not shown) in %s." % (len(token), conf_dir))
