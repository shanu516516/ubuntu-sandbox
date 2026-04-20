#!/bin/bash
set -euo pipefail

log() { printf '[entrypoint %s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }

MARKER=/home/ubuntu/.sandbox-initialized

# --- Passwords: re-apply every boot so env vars are the source of truth ---
if [ -n "${ROOT_PASSWORD:-}" ]; then
  echo "root:$ROOT_PASSWORD" | chpasswd
fi
if [ -n "${UBUNTU_PASSWORD:-}" ]; then
  echo "ubuntu:$UBUNTU_PASSWORD" | chpasswd
fi

# --- First-run init (skipped on subsequent starts; marker lives in the volume) ---
if [ ! -f "$MARKER" ]; then
  log "first-run initialization"

  chown -R ubuntu:ubuntu /home/ubuntu
  chmod 700 /home/ubuntu
  chown -R root:root /root
  chmod 700 /root

  if [ "${UBUNTU_NOPASSWD_SUDO:-false}" = "true" ]; then
    echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-ubuntu
    chmod 440 /etc/sudoers.d/90-ubuntu
    log "enabled passwordless sudo for ubuntu"
  fi

  touch "$MARKER"
  chown ubuntu:ubuntu "$MARKER"
else
  # Cheap per-boot sanity: fix top-level only, not a recursive walk
  [ "$(stat -c %u /home/ubuntu)" = "1100" ] || chown ubuntu:ubuntu /home/ubuntu
  chmod 700 /home/ubuntu /root 2>/dev/null || true
fi

# --- SSH (optional) ---
if [ "${ENABLE_SSH:-false}" = "true" ]; then
  mkdir -p /run/sshd
  if [ -z "$(ls -A /etc/ssh 2>/dev/null)" ] && [ -d /etc/ssh.dist ]; then
    log "seeding /etc/ssh from image defaults"
    cp -a /etc/ssh.dist/. /etc/ssh/
  fi
  [ -f /etc/ssh/ssh_host_ed25519_key ] || ssh-keygen -A
  log "starting sshd on :22"
  /usr/sbin/sshd
fi

# --- Drop to ubuntu user ---
# Default CMD is "bash" — treat that (and empty args) as "interactive login shell".
# Any other command is executed via -c.
if [ $# -eq 0 ] || [ "$*" = "bash" ] || [ "$*" = "/bin/bash" ]; then
  exec runuser -l ubuntu
else
  exec runuser -l ubuntu -c "$*"
fi
