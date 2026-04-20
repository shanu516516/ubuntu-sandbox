# Ubuntu 24.04 Sandbox

A sandboxed Ubuntu environment for development and testing. Run risky files, experiment with tools, and test code without putting your host machine at risk.

## Purpose

This setup creates an isolated Ubuntu 24.04 container that acts as a disposable development environment. Use it to:

- Test untrusted scripts or binaries safely
- Experiment with new tools and configurations
- Run development builds without polluting your host system
- Debug with `gdb`/`strace` in an isolated environment

Data is stored in `./data/` on the host but is protected by UID mismatch and `chmod 700` — your host user cannot read, write, or list the files without `sudo`. This is the same technique PostgreSQL uses for its Docker volumes.

## Security Measures

| Measure | What it does |
|---|---|
| `privileged: false` | No access to host devices or kernel features |
| `cap_drop: ALL` | Strips all Linux capabilities — even root inside the container is restricted |
| `cap_add` (minimal set) | Only adds back `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETGID`, `SETUID`, `NET_RAW`, `SYS_PTRACE` |
| UID mismatch (UID 1100) | Container user doesn't match any host user — files in `./data/` are unreadable from the host |
| `chmod 700` on home dirs | Only the owning UID can access the data — host user gets "Permission denied" |
| `tmpfs` on `/tmp` and `/run` | These directories live in RAM and vanish on stop — nothing persists to host disk |
| `pids_limit: 512` | Prevents fork bombs from consuming system resources |
| `mem_limit: 4g` | Caps memory usage so a runaway process can't starve your laptop |
| `cpus: 4` | Limits CPU usage |
| Isolated bridge network | Container can reach the internet but cannot access host-local services |
| No Docker socket mounted | Malware inside the container cannot control Docker on your host |
| No host PID/IPC namespace | Full process and IPC isolation from the host |
| `./data/ssh` bind mount | Persists SSH host keys across rebuilds — avoids "host key changed" warnings |

## Pre-installed Tools

All tools below are baked into the image at **build time** — no runtime install flags, no first-boot waiting.

**System & build deps**
`curl`, `wget`, `git`, `vim`, `nano`, `sudo`, `build-essential`, `ca-certificates`, `pkg-config`, `libssl-dev`, `protobuf-compiler`, `cmake`, `clang`, `lld`, `python3` + `pip` + `venv`, `unzip`, `htop`, `net-tools`, `iputils-ping`, `openssh-server`.

**Language toolchains (system-wide)**

| Tool | Install path | Notes |
|---|---|---|
| Node.js (LTS) + npm | `/usr/bin` (via NodeSource) | |
| pnpm | global npm install | Store at `/home/ubuntu/.local/share/pnpm/store` (named volume) |
| Claude Code | global npm install | Session history, plans, memory, and auth tokens live under `~/.claude` — persisted automatically via the `/home/ubuntu` bind mount |
| Go (latest stable) | `/usr/local/go` | `GOPATH=/go`, `GOMODCACHE=/go/pkg/mod` (named volume) |
| Rust (stable, via rustup) | `/usr/local/cargo`, `/usr/local/rustup` | Registry + git cache on named volumes |

Toolchains live under `/usr/local/*` (not `~/.cargo` or `~/go`) because `/home/ubuntu` is a bind mount — anything installed there during build would be masked by the mount at runtime.

**Build caches persist across rebuilds** via named Docker volumes (`cargo-registry`, `cargo-git`, `go-mod-cache`, `pnpm-store`). So `cargo build` / `go build` / `pnpm install` stay fast even after `docker compose build --no-cache`.

## Users

| User | Password | Home Directory |
|---|---|---|
| `root` | `root123` (default) | `/root` (mapped to `./data/root`) |
| `ubuntu` (UID 1100) | `ubuntu123` (default) | `/home/ubuntu` (mapped to `./data/ubuntu`) |

Passwords are loaded from the `.env` file. If `.env` is missing or a variable is unset, the defaults above are used. To customize:

```bash
cp .env.example .env
# Edit .env with your own passwords
```

The container starts as `root`, sets passwords and permissions, then drops to the `ubuntu` user automatically. Use `sudo` or `su root` when you need root access.

Set `UBUNTU_NOPASSWD_SUDO=true` in `.env` to grant the `ubuntu` user passwordless `sudo` inside the container. This only affects privileges *inside* the sandbox — it does not weaken isolation from the host.

## Commands

### Build and start

```bash
docker compose up -d --build
```

`--build` is only needed the first time or after changing the `Dockerfile`.

### Start (after first build)

```bash
docker compose up -d
```

### Open a shell

```bash
docker compose exec ubuntu bash
```

### Stop

```bash
docker compose down
```

### Copy files in/out (with confirmation)

```bash
# Copy a file INTO the container
./sandbox-cp.sh in ./myfile.txt /home/ubuntu/myfile.txt

# Copy a file OUT of the container (requires typing 'yes')
./sandbox-cp.sh out /home/ubuntu/result.txt ./result.txt
```

Copying files **out** requires typing `yes` as a safety measure — so you don't accidentally pull untrusted files onto your host.

### Rebuild from scratch

```bash
docker compose down
docker compose up -d --build
```

### Destroy all data

```bash
docker compose down
sudo rm -rf ./data
docker volume rm $(docker volume ls -q --filter name=cargo-) \
                 $(docker volume ls -q --filter name=go-mod-cache) \
                 $(docker volume ls -q --filter name=pnpm-store) 2>/dev/null || true
```

### What survives a rebuild

**Safe across `docker compose build --no-cache` and image deletion:**

- Everything under `./data/` (your home dir, `/root`, `/workspace`, `/etc/ssh` host keys)
- Named volumes (cargo / go / pnpm caches)
- Passwords (re-applied from `.env` on each boot)

**Lost on rebuild:**

- Extra apt packages you installed at runtime — reinstall or add them to the Dockerfile
- Manual edits to `/etc/*` (except `/etc/ssh`, which is bind-mounted)
- Manual `passwd` changes inside the container (env vars are the source of truth)
- Anything in `/tmp` or `/run` (tmpfs — wiped on every restart, not just rebuilds)

### View logs

```bash
docker compose logs -f ubuntu
```

## IDE Integration (VSCode / Cursor)

### Option 1: Dev Containers (no SSH needed)

1. Install the **Dev Containers** extension
2. Start the container with `docker compose up -d`
3. Open command palette (`Cmd+Shift+P`) → **Dev Containers: Attach to Running Container** → select `ubuntu-sandbox`
4. You'll get a full IDE window running inside the container at `/home/ubuntu`

### Option 2: Remote SSH

1. Enable SSH in your `.env` file:

```
ENABLE_SSH=true
SSH_PORT=2222
```

2. Rebuild: `docker compose up -d --build`
3. Install the **Remote - SSH** extension
4. Connect to `ssh ubuntu@localhost -p 2222`

SSH is disabled by default. Set `ENABLE_SSH=true` in `.env` to enable it.

## File Structure

```
.
├── docker-compose.yml   # Container configuration, bind mounts, named volumes, security
├── Dockerfile           # Base image + all dev toolchains (Node, pnpm, Go, Rust, build deps)
├── entrypoint.sh        # Passwords, permissions, /etc/ssh seeding, drops to ubuntu user
├── .env                 # Your passwords — optional, not committed to git
├── .env.example         # Template with variable names and explanations
├── .gitignore           # Excludes .env and data/ from version control
├── sandbox-cp.sh        # Safe file transfer with confirmation prompts
├── CLAUDE.md            # Architecture notes for Claude Code
├── data/                # Created on first run — unreadable from host without sudo
│   ├── ubuntu/          # /home/ubuntu inside the container (UID 1100, mode 700)
│   ├── root/            # /root inside the container (UID 0, mode 700)
│   ├── workspace/       # /workspace — a dedicated project dir (no dotfiles noise)
│   └── ssh/             # /etc/ssh — persists SSH host keys across rebuilds
└── README.md
```

Named Docker volumes (not on the host filesystem, but persist across rebuilds):

- `cargo-registry`, `cargo-git` — Rust build cache
- `go-mod-cache` — Go module cache
- `pnpm-store` — pnpm content-addressed store

These live inside Docker's VM and survive `docker compose build --no-cache`. To wipe them: `docker volume rm ubuntu24_cargo-registry ubuntu24_cargo-git ubuntu24_go-mod-cache ubuntu24_pnpm-store` (prefix matches your project dir name).

## macOS Note

Docker Desktop on macOS uses a file sharing layer (VirtioFS) that may remap UIDs. If you find `./data/` is still readable from your host, you can switch to named Docker volumes for stronger isolation — those live entirely inside Docker's Linux VM and are not accessible from the host filesystem at all.
