#!/bin/bash
# PC Remote end-to-end self-test on the VPS: a throw-away "computer" (a temporary sshd on 127.0.0.1:2299)
T=/tmp/pct; rm -rf $T; mkdir -p $T; cd $T
rm -rf /opt/pc-remote/bin/__pycache__
OUT=$(pc invite 1 | head -1); echo "invite file: $OUT"
IID=$(basename "$OUT" .bat | sed 's/PC-Remote-Setup-//')
python3 - "$OUT" <<'EOF'
import re, sys, base64
s = open(sys.argv[1], "rb").read().decode("ascii")
assert "\r\n" in s, "CRLF"
assert "@@" not in s, "placeholder left"
open("/tmp/pct/enroll_key", "wb").write(base64.b64decode(re.search(r"\$EnrollKeyB64 = '([^']+)'", s).group(1)))
open("/tmp/pct/known_hosts", "w").write(re.search(r"\$KnownHosts = '([^']+)'", s).group(1) + "\n")
print("bat ok: CRLF, placeholders filled")
EOF
chmod 600 $T/enroll_key
# the stand-in computer: its own sshd (host key + the admin key + a forced echo instead of PowerShell)
ssh-keygen -q -t ed25519 -N "" -f $T/hostkey; ssh-keygen -q -t ed25519 -N "" -f $T/tunnel_key
cp /root/.ssh/pc_admin.pub $T/authkeys; chmod 600 $T/authkeys
cat > $T/sshd_config <<EOF
Port 2299
ListenAddress 127.0.0.1
HostKey $T/hostkey
PidFile $T/sshd.pid
AuthorizedKeysFile $T/authkeys
PasswordAuthentication no
PermitRootLogin prohibit-password
StrictModes no
ForceCommand echo pc-remote-ok
EOF
/usr/sbin/sshd -f $T/sshd_config
O=(-i $T/enroll_key -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$T/known_hosts)
echo "--- enroll:"
python3 -c 'import json; print(json.dumps({"computer": "PCR-SELFTEST", "user": "root", "windows": "test", "tunnel_pubkey": open("/tmp/pct/tunnel_key.pub").read().strip(), "host_key": open("/tmp/pct/hostkey.pub").read().strip()}))' \
  | ssh "${O[@]}" pcenroll@87.107.160.17 enroll | tee $T/reply.json | cut -c1-160
PORT=$(python3 -c 'import json; print(json.load(open("/tmp/pct/reply.json"))["port"])')
echo "--- tunnel on port $PORT"
ssh -i $T/tunnel_key -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$T/known_hosts -o ExitOnForwardFailure=yes \
    -N -R 127.0.0.1:$PORT:127.0.0.1:2299 pcremote@87.107.160.17 &
TUN=$!; sleep 4
echo "--- check (admin logs in through the tunnel, host key pinned):"
echo '{"name": "pcr-selftest"}' | ssh "${O[@]}" pcenroll@87.107.160.17 check
echo "--- pc list / pc run:"
pc | grep pcr-selftest
pc pcr-selftest run 'anything'
echo "--- openssh-zip:"
ssh "${O[@]}" pcenroll@87.107.160.17 openssh-zip > $T/z.zip; sha256sum $T/z.zip | cut -c1-16
echo "--- refusals:"
ssh "${O[@]}" pcenroll@87.107.160.17 'id; cat /etc/shadow'; echo " exit=$?"
ssh "${O[@]}" -N -o ExitOnForwardFailure=yes -L 127.0.0.1:23998:127.0.0.1:22 pcenroll@87.107.160.17 2>&1 | tail -1 &
sleep 3; timeout 3 bash -c "exec 3<>/dev/tcp/127.0.0.1/23998; head -c 20 <&3"; echo " (local forward via invite key: $?)"; for p in $(pgrep -f 23998:127.0.0.1); do kill $p; done
timeout 12 ssh -i $T/tunnel_key -o BatchMode=yes -o UserKnownHostsFile=$T/known_hosts -o ExitOnForwardFailure=yes -N -R 127.0.0.1:22999:127.0.0.1:2299 pcremote@87.107.160.17 2>&1 | tail -1
timeout 12 ssh -i $T/tunnel_key -o BatchMode=yes -o UserKnownHostsFile=$T/known_hosts pcremote@87.107.160.17 id 2>&1 | tail -1
echo "--- a forged host key is refused by pc (pinning):"
kill $(cat $T/sshd.pid); sleep 1
ssh-keygen -q -t ed25519 -N "" -f $T/hostkey2; sed -i "s#HostKey $T/hostkey#HostKey $T/hostkey2#" $T/sshd_config; /usr/sbin/sshd -f $T/sshd_config; sleep 1
pc pcr-selftest run x 2>&1 | grep -iE "REMOTE HOST IDENTIFICATION|Host key verification" | head -1
echo "--- cleanup"
kill $TUN $(cat $T/sshd.pid) 2>/dev/null; wait 2>/dev/null
pc remove pcr-selftest
python3 - "$IID" <<'EOF'
import json, sys
p = "/opt/pc-remote/invites.json"; d = json.load(open(p)); d[sys.argv[1]]["expires"] = 0; json.dump(d, open(p, "w"))
EOF
pc; grep -c . /var/lib/pcenroll/.ssh/authorized_keys /var/lib/pcremote/.ssh/authorized_keys; ls /opt/pc-remote/out /opt/pc-remote/invites
rm -rf $T
