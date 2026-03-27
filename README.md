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

## Pre-installed Tools

`curl`, `wget`, `git`, `vim`, `nano`, `sudo`, `build-essential`, `ca-certificates`, `python3`, `pip`, `venv`, `unzip`, `htop`, `net-tools`, `iputils-ping`

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
```

### View logs

```bash
docker compose logs -f ubuntu
```

## VSCode Integration

1. Install the **Dev Containers** extension in VSCode
2. Start the container with `docker compose up -d`
3. Open command palette → **Dev Containers: Attach to Running Container** → select `ubuntu-sandbox`
4. You'll get a full VSCode window running inside the container at `/home/ubuntu`

## File Structure

```
.
├── docker-compose.yml   # Container configuration and security settings
├── Dockerfile           # Base image and package installation
├── entrypoint.sh        # Sets passwords, permissions, and switches to ubuntu user
├── .env                 # Your passwords — optional, not committed to git
├── .env.example         # Template with variable names and explanations
├── .gitignore           # Excludes .env and data/ from version control
├── sandbox-cp.sh        # Safe file transfer with confirmation prompts
├── data/                # Created on first run — unreadable from host without sudo
│   ├── ubuntu/          # /home/ubuntu inside the container (UID 1100, mode 700)
│   └── root/            # /root inside the container (UID 0, mode 700)
└── README.md
```

## macOS Note

Docker Desktop on macOS uses a file sharing layer (VirtioFS) that may remap UIDs. If you find `./data/` is still readable from your host, you can switch to named Docker volumes for stronger isolation — those live entirely inside Docker's Linux VM and are not accessible from the host filesystem at all.
