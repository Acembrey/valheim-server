# valheim-server

## Overview

A portable, containerized Valheim dedicated server built on the `community-valheim-tools/valheim-server-docker` image (a drop-in successor to the original `lloesche/valheim-server-docker` — the legacy image tag `ghcr.io/lloesche/valheim-server` is still published and works identically). Everything the server needs — world save, backups, and admin/ban/whitelist files — lives in a single mounted `/config` directory, so the whole server can be moved to a new host by copying that one folder.

Current for **Valheim 1.0 / Deep North** (released September 9, 2026).

## Prerequisites

- **Docker** (or **Podman**) installed and running on the host
- **~1 GB free disk** for the initial Steam download of the dedicated server binary, plus room for the world and backups
- **Minimum hardware**: dual-core CPU, 4 GB RAM. Recommended: 4 cores / 8 GB — a few high-clocked cores outperform many slow ones, since Valheim's server leans on one or two heavily-loaded threads
- **UDP ports 2456–2457** reachable from clients (port+1 is the query port). Add **2458/udp** as well if crossplay is enabled
- Two host directories:
  - `config/` — persistent: world save, backups, admin/ban/whitelist files. **This is the folder to back up or move to a new host.**
  - `data/` — optional cache of the downloaded server binary, so a recreated container doesn't re-pull ~1 GB from Steam

## Usage

### Quick start — `docker run`

```bash
mkdir -p ~/valheim-server/config ~/valheim-server/data

docker run -d \
  --name valheim-server \
  --cap-add=sys_nice \
  --stop-timeout 120 \
  --restart unless-stopped \
  -p 2456-2457:2456-2457/udp \
  -v ~/valheim-server/config:/config \
  -v ~/valheim-server/data:/opt/valheim \
  -e SERVER_NAME="My Server" \
  -e WORLD_NAME="Midgard" \
  -e SERVER_PASS="changeme123" \
  -e SERVER_PUBLIC="true" \
  ghcr.io/community-valheim-tools/valheim-server
```

- `SERVER_PASS` must be **at least 5 characters** or the server refuses to start
- `--cap-add=sys_nice` is optional — lets the Steam runtime raise its own thread priority; without it you'll just see a harmless warning in the startup log

### docker-compose

More portable than a long run command — drop this file and a `config/` folder anywhere with Docker installed:

```yaml
services:
  valheim:
    image: ghcr.io/community-valheim-tools/valheim-server
    cap_add:
      - sys_nice
    stop_grace_period: 2m
    restart: unless-stopped
    ports:
      - "2456-2457:2456-2457/udp"
    volumes:
      - ./config:/config
      - ./data:/opt/valheim
    environment:
      - SERVER_NAME=My Server
      - WORLD_NAME=Midgard
      - SERVER_PASS=changeme123
      - SERVER_PUBLIC=true
```

```bash
docker compose up -d
```

### Windows — `start-valheim-server.bat`

For hosts without a shell environment, the included batch script does the same setup:

- Edit `SERVER_NAME`, `WORLD_NAME`, and `SERVER_PASS` at the top of the script
- Double-click, or run from a command prompt
- Validates Docker is installed and running, checks the password length, creates `%USERPROFILE%\valheim-server\{config,data}`, and offers to remove/recreate an existing container of the same name before launching
- Avoid `!`, `^`, `%`, and `"` characters in `SERVER_PASS` — batch parses these specially

### Podman notes

The image runs under Podman as well, with two differences from Docker:

1. **Rootless Podman**: the image defaults to running as root inside the container (`PUID=0`/`PGID=0`) to freely write `/config` and `/opt/valheim`. Rootless Podman remaps that to your host UID via user namespaces, which is usually fine — if you hit permission errors on the mounted volumes, add `--userns=keep-id` to `podman run`, or set `PUID`/`PGID` to match your host user.
2. `--cap-add=sys_nice` works identically in `podman run` or a Podman-compatible compose file.

## Settings Reference

Valheim has no server config file. Everything lives in one of three places:

1. **Launch parameters** — flags on the server start line (pass extra ones via the `SERVER_ARGS` env var on this image)
2. **World modifiers** — stored *in the world save itself*, set via `-preset`/`-modifier`/`-setkey` or changed live from the admin console
3. **Three plain-text access files** next to the world saves (or via `ADMINLIST_IDS` / `BANNEDLIST_IDS` / `PERMITTEDLIST_IDS` env vars on this image)

---

### 1. Launch Parameters

| Parameter | Default | What it does |
|---|---|---|
| `-name "My Server"` | required | Name shown in the server browser |
| `-port 2456` | 2456 | Game port. Server also uses port+1 (2457) for queries — forward both if self-hosting |
| `-world "Dedicated"` | required | World to load/create |
| `-password "secret"` | none | Join password. **Minimum 5 characters**, and can't appear in the server/world name or the server refuses to start |
| `-savedir "path"` | game default | Where worlds, characters, and the 3 access files live |
| `-public 1` | 1 | `1` = listed in community browser, `0` = hidden (still joinable by IP/code) |
| `-logFile "path"` | none | Redirect server log to a file |
| `-saveinterval 1800` | 1800s (30 min) | Autosave frequency |
| `-backups 4` | 4 | Number of automatic backups kept |
| `-backupshort 7200` | 7200s (2h) | Age of the first automatic backup |
| `-backuplong 43200` | 43200s (12h) | Spacing of subsequent backups |
| `-crossplay` | off | Enables Xbox/PS5/Switch 2/Game Pass join via code. Also removes the port-forwarding requirement (traffic goes through Iron Gate's relay) |
| `-instanceid [text]` | none | Only needed for multiple crossplay servers sharing one public IP/port |
| `-preset [name]` | normal | Applies a world modifier preset (see below). **Overwrites any modifiers set earlier on the line** |
| `-modifier [name] [value]` | none | Sets one world modifier — must come **after** `-preset` on the line |
| `-setkey [name]` | none | Enables a checkbox modifier (see below) |
| `-nographics -batchmode` | always on | Headless mode flags — leave in place |

**⚠️ Ordering gotcha:** `-preset` resets everything set before it. Always put `-preset` first, then `-modifier`/`-setkey` after:

```
valheim_server.exe -nographics -batchmode -name "Midgard Crew" -port 2456 -world "Midgard" -password "vikings" -public 1 -crossplay -saveinterval 900 -preset normal -modifier raids less -backups 6
```

---

### 2. World Modifiers

Stored in the world save (follows the world wherever it's loaded). Applying a modifier to an already-explored world is safe — nothing built or explored is lost.

#### Presets (`-preset [name]`)

| Preset | Feel |
|---|---|
| `normal` | Default rules |
| `casual` | Gentlest: forgiving combat/death, more resources, fewer raids, portals carry everything |
| `easy` | Easier combat + death penalty, more resources |
| `hard` | Tougher combat + death penalty, fewer resources, more raids |
| `hardcore` | Harshest combat/death penalty, more raids, portal restrictions |
| `immersive` | No map, portal restrictions |
| `hammer` | No build cost. **Flags the world as cheated in 1.0 — achievements stop unlocking while active** |

#### Individual modifiers (`-modifier [name] [value]`)

| Modifier | Values (easiest → hardest) | What it changes |
|---|---|---|
| `combat` | `veryeasy`, `easy`, *default*, `hard`, `veryhard` | Damage dealt/taken |
| `deathpenalty` | `casual`, `veryeasy`, `easy`, *default*, `hard`, `hardcore` | What you lose on death |
| `resources` | `most`, `muchmore`, `more`, *default*, `less`, `muchless` | Resource drop rates |
| `raids` | `none`, `muchless`, `less`, *default*, `more`, `muchmore` | Raid frequency |
| `portals` | `casual`, *default*, `hard`, `veryhard` | What can pass through portals (casual = ores/metals allowed; veryhard = portals disabled) |

#### Checkbox modifiers (`-setkey [name]`)

| Key | Effect |
|---|---|
| `nobuildcost` | Free building (hammer mode). Flags world as cheated in 1.0 |
| `playerevents` | Raids triggered by each player's own progress instead of the world's (known history of dedicated-server-specific bugs — verify it's actually scoping raids per-player before relying on it) |
| `passivemobs` | Creatures only attack if attacked first |
| `nomap` | No map for anyone |

#### Changing modifiers live (in-game admin console, no restart)

| Command | Example |
|---|---|
| `setworldmodifier [name] [value]` | `setworldmodifier resources more` |
| `setworldpreset [name]` | `setworldpreset casual` |
| `resetworldkeys` | Resets all modifiers to default (boss progress untouched) |

---

### 3. Access Files

Plain text, one platform user ID per line (format shown by the in-game **F2** panel, e.g. `Steam_76561197960287930`), stored in the save directory.

| File | Effect |
|---|---|
| `adminlist.txt` | Grants kick/ban/save/world-modifier rights |
| `bannedlist.txt` | Blocks listed players from joining |
| `permittedlist.txt` | Whitelist — **any entry at all makes the server invite-only** |

---

### Notes

- Beyond this list, vanilla has nothing else — player limits above 10, building rules, stack sizes, etc. require a mod (Valheim Plus exposes hundreds of additional values through its own config, and is built into this container image via the `VALHEIM_PLUS` env var).
- A password-protected + `-public 0` server is effectively invisible; for a hard whitelist use `permittedlist.txt` (or `PERMITTEDLIST_IDS` on this image).
- World files are `<name>.db` + `<name>.fwl` pairs pre-1.0, or a directory per world on 1.0+; either way, everything needed lives under `config/worlds_local/`.