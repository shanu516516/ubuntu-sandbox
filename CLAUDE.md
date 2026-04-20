# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Docker-based Ubuntu 24.04 sandbox for development work. Primary goal: **isolate the host from a potentially-compromised dev toolchain** (supply-chain attacks, untrusted binaries). The security hardening in `docker-compose.yml` (`cap_drop: ALL`, resource limits, no docker socket mount, UID mismatch, mode-700 home dirs) is load-bearing — do not weaken it casually.

See `README.md` for the user-facing tour (security table, IDE integration, file transfer helper).

## Common commands

| Task | Command |
|---|---|
| Build + start | `docker compose up -d --build` |
| Start (no rebuild) | `docker compose up -d` |
| Shell as `ubuntu` | `docker compose exec ubuntu bash` |
| Shell as `root` | `docker compose exec -u 0 ubuntu bash` |
| Stop | `docker compose down` |
| Follow logs | `docker compose logs -f ubuntu` |
| Rebuild from scratch | `docker compose down && docker compose up -d --build` |
| Wipe all state | `docker compose down && sudo rm -rf ./data` (host needs `sudo` because of UID 1100 + mode 700) |

`sandbox-cp.sh` is the safe file-transfer helper: `./sandbox-cp.sh in <host> <container>` / `./sandbox-cp.sh out <container> <host>`. The `out` direction requires typing `yes` to prevent accidentally pulling untrusted files onto the host.

## Architecture: why things look the way they do

### Dev tools are installed **system-wide**, not per-user

`./data/ubuntu` is bind-mounted onto `/home/ubuntu` at runtime. Anything a `RUN` step in the `Dockerfile` writes into `/home/ubuntu` (e.g. a default `rustup` install into `~/.cargo`) **is masked** the moment the container starts and the bind mount takes over. Consequences:

- Rust installs to `/usr/local/rustup` + `/usr/local/cargo` via `RUSTUP_HOME` / `CARGO_HOME` envs set in the Dockerfile.
- Go installs to `/usr/local/go`; `GOPATH=/go`, `GOMODCACHE=/go/pkg/mod`.
- Node.js + pnpm + Claude Code installed globally via NodeSource + `npm install -g`.
- Shell env vars re-exported via `/etc/profile.d/*.sh` so login shells and sshd sessions both pick them up.

Claude Code's own state (`~/.claude/`, `~/.claude.json`) lives under `/home/ubuntu`, so session history, plans, memory, and OAuth tokens persist across rebuilds for free — **do not** add a separate bind mount for `~/.claude`; it would shadow the already-mounted home dir.

**If you add a new language toolchain, install it under `/usr/local` or `/opt`, never into `/home/ubuntu` during build.**

### Caches are on named volumes, not in the image

Build caches (cargo registry, go module cache, pnpm store) are mounted as **named Docker volumes** in `docker-compose.yml` so they survive `docker compose build --no-cache` and image deletion. Mount points are created and made world-writable in the Dockerfile so the volume has somewhere to attach.

### `/etc/ssh` is bind-mounted and must be seeded on first run

`./data/ssh:/etc/ssh` persists SSH host keys across rebuilds (no "host key changed" warnings). But on first run the host dir is empty and masks sshd's config files. Workaround: the Dockerfile copies `/etc/ssh` → `/etc/ssh.dist` during build, and `entrypoint.sh` restores it if `/etc/ssh` is empty before starting sshd.

### Entrypoint flow

`entrypoint.sh` runs as root, then execs into the `ubuntu` user. Key details:

- **Passwords re-applied every boot** from `ROOT_PASSWORD` / `UBUNTU_PASSWORD` env vars — the env is the source of truth, not `/etc/shadow`. Manual `passwd` changes inside the container don't stick.
- **First-run marker** at `/home/ubuntu/.sandbox-initialized` gates expensive one-time init (recursive chown, sudoers). Subsequent starts only fix top-level ownership — avoids thrashing large repos on every boot.
- **Default `CMD ["bash"]` is detected specially** — the entrypoint runs `runuser -l ubuntu` (interactive login shell) instead of `runuser -l ubuntu -c "bash"` (which produces "no job control in this shell" because `-c` is non-interactive). Any *other* argv goes through `-c`.
- **`UBUNTU_NOPASSWD_SUDO=true`** (env) grants the `ubuntu` user passwordless sudo — only affects privileges *inside* the container, not host isolation.

### Data that survives vs. doesn't survive a rebuild

| Persists | Does not persist |
|---|---|
| `./data/ubuntu/`, `./data/root/`, `./data/workspace/`, `./data/ssh/` | Extra apt packages installed at runtime, manual `/etc/*` edits |
| Named volumes: `cargo-registry`, `cargo-git`, `go-mod-cache`, `pnpm-store` | `/tmp`, `/run` (tmpfs — wiped every restart) |
| Passwords (re-applied from `.env` on boot) | Manual `passwd` changes inside container |

## Constraints when editing

- **Never** uncomment `- ./data:/` in `docker-compose.yml`. Mounting host `/` inside the container defeats the entire isolation model.
- **Don't** weaken `cap_drop: ALL`, `privileged: false`, or the resource limits (`mem_limit`, `pids_limit`, `cpus`) without explicit reason — they're the host-protection boundary.
- **Don't** mount the docker socket (`/var/run/docker.sock`). That's a host-escape vector.
- UID 1100 for `ubuntu` is deliberate — it doesn't match any host UID, which is what makes `./data/` unreadable from the host without sudo. Don't change it.
- `.env` holds real passwords and is gitignored; `.env.example` is the template. Update both in sync when adding env vars.
- **Add new Dockerfile instructions at the end of the file, not in the middle.** Docker caches layers sequentially — inserting a new `RUN` above existing steps invalidates every layer below it, forcing a full rebuild (re-downloading Go, reinstalling Rust, etc.). A new package added as the last `RUN` only rebuilds that one layer. Same principle for edits: prefer appending a new `RUN` over modifying an earlier one.
