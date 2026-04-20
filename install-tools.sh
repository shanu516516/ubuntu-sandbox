#!/bin/bash
set -e

MARKER_DIR="/home/ubuntu/.installed"
mkdir -p "$MARKER_DIR"

install_node() {
  if [ -f "$MARKER_DIR/.node" ]; then
    echo "[node] Already installed, skipping."
    return
  fi
  echo "[node] Installing Node.js and npm..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
  apt-get install -y nodejs
  echo "[node] Installed: $(node -v), npm $(npm -v)"
  touch "$MARKER_DIR/.node"
}

install_pnpm() {
  if [ -f "$MARKER_DIR/.pnpm" ]; then
    echo "[pnpm] Already installed, skipping."
    return
  fi
  echo "[pnpm] Installing pnpm..."
  npm install -g pnpm
  echo "[pnpm] Installed: $(pnpm -v)"
  touch "$MARKER_DIR/.pnpm"
}

install_rust() {
  if [ -f "$MARKER_DIR/.rust" ]; then
    echo "[rust] Already installed, skipping."
    return
  fi
  echo "[rust] Installing Rust..."
  mkdir -p /home/ubuntu/.rustup-tmp
  chown ubuntu:ubuntu /home/ubuntu/.rustup-tmp
  su - ubuntu -c "TMPDIR=/home/ubuntu/.rustup-tmp curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | TMPDIR=/home/ubuntu/.rustup-tmp sh -s -- -y"
  rm -rf /home/ubuntu/.rustup-tmp
  echo "[rust] Installed: $(su - ubuntu -c 'source ~/.cargo/env && rustc --version')"
  touch "$MARKER_DIR/.rust"
}

install_go() {
  if [ -f "$MARKER_DIR/.go" ]; then
    echo "[go] Already installed, skipping."
    return
  fi
  echo "[go] Installing Go..."
  GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
  curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" | tar -C /usr/local -xz
  echo 'export PATH=$PATH:/usr/local/go/bin' >> /home/ubuntu/.profile
  echo "[go] Installed: $(/usr/local/go/bin/go version)"
  touch "$MARKER_DIR/.go"
}

if [ "$INSTALL_NODE" = "true" ]; then
  install_node
fi

if [ "$INSTALL_PNPM" = "true" ]; then
  if [ "$INSTALL_NODE" != "true" ] && [ ! -f "$MARKER_DIR/.node" ]; then
    echo "[pnpm] Node.js is required. Installing Node.js first..."
    install_node
  fi
  install_pnpm
fi

if [ "$INSTALL_RUST" = "true" ]; then
  install_rust
fi

if [ "$INSTALL_GO" = "true" ]; then
  install_go
fi
