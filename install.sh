#!/bin/bash
# PC Remote - the server side (idempotent). 1405/08/19. Independent of NMarketing.
#   pcremote : tunnel user - no shell; each computer's key may only open ITS port on 127.0.0.1 (reverse tunnel)
#   pcenroll : the setup files' invitation keys - each may only run bin/pc-enroll (through one sudo rule)
#   /root/.ssh/pc_admin : the key `pc` logs in to the computers with; their host keys are pinned in /root/.ssh/pc_known_hosts
# Undo: rm /etc/ssh/sshd_config.d/61-pc-remote.conf /etc/sudoers.d/pc-remote /usr/local/bin/pc; systemctl reload ssh;
#       userdel -r pcremote; userdel -r pcenroll
# Needs: root, openssh-server, python3, sudo, curl. The repository must be at /opt/pc-remote.
set -euo pipefail
B=/opt/pc-remote

id -u pcremote >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/pcremote --shell /usr/sbin/nologin pcremote
id -u pcenroll >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/pcenroll --shell /bin/sh pcenroll
passwd -l pcremote >/dev/null 2>&1 || true
passwd -l pcenroll >/dev/null 2>&1 || true
for u in pcremote pcenroll; do
  install -d -m 700 -o "$u" -g "$u" "/var/lib/$u/.ssh"
  [ -f "/var/lib/$u/.ssh/authorized_keys" ] || install -m 600 -o "$u" -g "$u" /dev/null "/var/lib/$u/.ssh/authorized_keys"
done

[ -f /root/.ssh/pc_admin ] || ssh-keygen -q -t ed25519 -N "" -C "pc-remote-admin@$(hostname)" -f /root/.ssh/pc_admin
touch /root/.ssh/pc_known_hosts && chmod 600 /root/.ssh/pc_known_hosts

CONF=/etc/ssh/sshd_config.d/61-pc-remote.conf
cat > "$CONF.new" <<'EOF'
# PC Remote (/opt/pc-remote/install.sh). Per-key options in the users' authorized_keys narrow it further.
Match User pcremote
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    AllowTcpForwarding remote
    AllowStreamLocalForwarding no
    AllowAgentForwarding no
    X11Forwarding no
    PermitTunnel no
    PermitUserRC no
    PermitTTY no
    GatewayPorts no
    ForceCommand /bin/false
Match User pcenroll
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    AllowTcpForwarding no
    AllowStreamLocalForwarding no
    AllowAgentForwarding no
    X11Forwarding no
    PermitTunnel no
    PermitUserRC no
    PermitTTY no
EOF
if ! cmp -s "$CONF.new" "$CONF" 2>/dev/null; then
  mv "$CONF.new" "$CONF"; sshd -t; systemctl reload ssh; echo "sshd: $CONF installed"
else
  rm -f "$CONF.new"
fi

echo 'pcenroll ALL=(root) NOPASSWD: /opt/pc-remote/bin/pc-enroll' > /etc/sudoers.d/pc-remote.new
chmod 440 /etc/sudoers.d/pc-remote.new
visudo -cf /etc/sudoers.d/pc-remote.new >/dev/null && mv /etc/sudoers.d/pc-remote.new /etc/sudoers.d/pc-remote

# the Windows OpenSSH package (for computers whose Windows cannot add the OpenSSH Server feature itself). It is not kept in
# git (5 MB): fetched once from the project's own release and checked against the SHA-256 pinned in bin/pc.
ZIP_NAME=OpenSSH-Win64-v9.8.3.0p2.zip
ZIP_URL=https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.8.3.0p2-Preview/OpenSSH-Win64.zip
ZIP_SHA=$(sed -n 's/^ZIP_SHA256 = "\([0-9a-f]\{64\}\)".*/\1/p' "$B/bin/pc")
mkdir -p "$B/windows"
if [ ! -f "$B/windows/$ZIP_NAME" ]; then
  if [ -n "$ZIP_SHA" ] && curl -fsSL --retry 3 --max-time 300 -o "$B/windows/$ZIP_NAME.part" "$ZIP_URL" \
       && echo "$ZIP_SHA  $B/windows/$ZIP_NAME.part" | sha256sum -c --status; then
    mv "$B/windows/$ZIP_NAME.part" "$B/windows/$ZIP_NAME"; echo "OpenSSH package for Windows: downloaded and verified"
  else
    rm -f "$B/windows/$ZIP_NAME.part"
    echo "WARNING: could not fetch the Windows OpenSSH package ($ZIP_URL); only computers whose Windows can add OpenSSH Server by itself will work" >&2
  fi
fi

# the repository is public: a pre-commit hook keeps keys and invitation files out of it
if [ -d "$B/.git" ]; then
  mkdir -p "$B/.git/hooks"
  printf '#!/bin/sh\nexec "$(git rev-parse --show-toplevel)/bin/check-public.sh"\n' > "$B/.git/hooks/pre-commit"
  chmod 755 "$B/.git/hooks/pre-commit"
fi

chown -R root:root "$B"
chmod 755 "$B" "$B/bin" "$B/windows"
chmod 755 "$B/bin/pc" "$B/bin/pc-enroll" "$B/bin/check-public.sh"
install -d -m 700 "$B/nodes" "$B/invites" "$B/out"
ln -sf "$B/bin/pc" /usr/local/bin/pc
echo "PC Remote ready: pc invite  (a setup file for the computers)"
