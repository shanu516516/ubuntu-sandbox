#!/bin/bash
set -e

if [ -n "$ROOT_PASSWORD" ]; then
  echo "root:$ROOT_PASSWORD" | chpasswd
fi

if [ -n "$UBUNTU_PASSWORD" ]; then
  echo "ubuntu:$UBUNTU_PASSWORD" | chpasswd
fi

chown -R ubuntu:ubuntu /home/ubuntu
chmod 700 /home/ubuntu

chown -R root:root /root
chmod 700 /root

if [ "$ENABLE_SSH" = "true" ]; then
  mkdir -p /run/sshd
  ssh-keygen -A
  echo "Starting SSH server on port 22..."
  /usr/sbin/sshd
fi

exec su - ubuntu -c "$*"
