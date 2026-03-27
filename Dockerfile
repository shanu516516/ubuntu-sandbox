FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
      curl wget git vim nano sudo \
      build-essential ca-certificates \
      python3 python3-pip python3-venv \
      unzip htop net-tools iputils-ping \
      openssh-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd

RUN usermod -u 1100 -s /bin/bash -aG sudo ubuntu && \
    mkdir -p /home/ubuntu && \
    chown -R ubuntu:ubuntu /home/ubuntu

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
