FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
      curl wget git vim nano sudo \
      build-essential ca-certificates \
      pkg-config libssl-dev \
      protobuf-compiler \
      cmake clang lld \
      python3 python3-pip python3-venv \
      unzip htop net-tools iputils-ping \
      openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && cp -a /etc/ssh /etc/ssh.dist

# Node.js (LTS) + pnpm + Claude Code
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g pnpm @anthropic-ai/claude-code && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Go (latest stable) -> /usr/local/go
ENV GOPATH=/go \
    GOMODCACHE=/go/pkg/mod \
    PATH=/usr/local/go/bin:/go/bin:$PATH
RUN GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1) && \
    curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" \
      | tar -C /usr/local -xz && \
    mkdir -p /go/pkg/mod /go/bin && chmod -R a+rwX /go && \
    { echo 'export GOPATH=/go'; \
      echo 'export GOMODCACHE=/go/pkg/mod'; \
      echo 'export PATH=$PATH:/usr/local/go/bin:/go/bin'; \
    } > /etc/profile.d/go.sh

# Rust (system-wide via rustup)
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/usr/local/go/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --default-toolchain stable && \
    mkdir -p /usr/local/cargo/registry /usr/local/cargo/git && \
    chmod -R a+rwX /usr/local/cargo /usr/local/rustup && \
    echo 'export RUSTUP_HOME=/usr/local/rustup'       > /etc/profile.d/rust.sh && \
    echo 'export CARGO_HOME=/usr/local/cargo'        >> /etc/profile.d/rust.sh && \
    echo 'export PATH=$PATH:/usr/local/cargo/bin'    >> /etc/profile.d/rust.sh

RUN usermod -u 1100 -s /bin/bash -aG sudo ubuntu && \
    mkdir -p /home/ubuntu && \
    chown -R ubuntu:ubuntu /home/ubuntu

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
