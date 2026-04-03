# docker-vivado-webpack

Dockerized **Xilinx Vivado** (WebPACK edition) and **Xilinx ISE** (WebPACK edition) with browser-based GUI access via **noVNC**. No local Xilinx installation or VNC client required — just Docker and a browser.

```
http://localhost:6080/vnc.html
```

---

## Repository Structure

```
docker-vivado-webpack/
├── novnc-display/               # Shared X11 display sidecar (noVNC + websockify)
│   ├── Dockerfile.novnc
│   └── novnc-entrypoint.sh
├── docker-vivado-webpack/       # Vivado HL WebPACK container
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── config-vivado.ini
│   └── .env
└── docker-ise-14.7/             # ISE WebPACK container
    ├── Dockerfile
    ├── docker-compose.yml
    ├── config-ise.ini
    ├── sanitize_xilinx.py
    ├── expected-config.txt
    └── .env
```

---

## Prerequisites

- **Docker** with [BuildKit](https://docs.docker.com/build/buildkit/) enabled (Docker 23+ recommended)
- **docker compose** v2 plugin (`docker compose`, not `docker-compose`)
- A downloaded Xilinx installer payload directory placed on your local machine

> **License**: Both Vivado and ISE are installed in their free **WebPACK** editions, which do not require a license for supported device families (Artix-7, Kintex-7, Spartan-6, etc.).

---

## How It Works

The setup uses a **two-container sidecar architecture** to keep display logic cleanly separated from the Xilinx tool image.

```
┌─────────────────────────────────────────────┐
│  Host Machine                               │
│                                             │
│  Browser → localhost:6080                   │
│                    │                        │
│  ┌─────────────────▼──────────────────────┐ │
│  │  web-display container (novnc-display) │ │
│  │                                        │ │
│  │  Xvfb (:0) ← virtual framebuffer       │ │
│  │  x11vnc    ← VNC server on :5900       │ │
│  │  websockify ← noVNC proxy on :6080     │ │
│  └──────────────────┬─────────────────────┘ │
│                     │ shared X11 socket      │
│                     │ (/tmp/.X11-unix)        │
│  ┌──────────────────▼─────────────────────┐ │
│  │  vivado / ise container                │ │
│  │                                        │ │
│  │  DISPLAY=:0 → renders on Xvfb          │ │
│  │  Vivado / ISE GUI opens in browser     │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

The X server socket (`/tmp/.X11-unix`) is shared between containers using a named Docker volume. The tool container sets `DISPLAY=:0` and shares the PID namespace with the display container (`pid: "service:web-display"`), allowing it to render directly through the sidecar's Xvfb instance.

---

## Vivado HL WebPACK

### System Requirements

| Component | Requirement |
|-----------|-------------|
| Host OS | Linux (tested on Arch Linux) |
| Vivado Version | 2016.2 – 2016.3 (configurable) |
| Base Image | `ubuntu:16.04` |
| Installer | `Xilinx_Vivado_SDK_<version>_<date>/` directory |

### Setup

**1. Edit `.env`**

```sh
cd docker-vivado-webpack
```

Open `.env` and set your paths:

```dotenv
VIVADO_VERSION=2016.3
INSTALLER_DIR=/path/to/Xilinx_Vivado_SDK_2016.3_1011_1
CONFIG_DIR=/path/to/docker-vivado-webpack/docker-vivado-webpack/
WORKSPACE=.
```

- `INSTALLER_DIR` — path to the extracted Vivado installer directory on your host.
- `CONFIG_DIR` — path to the directory containing `config-vivado.ini` (the `docker-vivado-webpack/` sub-directory by default).
- `WORKSPACE` — host directory to mount at `/home/guest/workspace` inside the container (use `.` for the current directory).

**2. (Optional) Extract a reference install config**

If you need to verify exact edition or module names accepted by your installer, run the `config-gen` service. It runs `xsetup --batch ConfigGen` inside a pre-built base image (with all required installer dependencies) and writes the reference `install_config.txt` to `./config-out/` on the host:

```sh
docker compose --profile tools run --rm config-gen
```

Inspect `./config-out/install_config.txt` to confirm valid `Modules=` names, then update `config-vivado.ini` as needed.

**3. Build the Vivado image**

The installer is bind-mounted at build time using Docker BuildKit's `additional_contexts` feature — the installer payload is **never copied into the image layer**.

```sh
docker compose build vivado
```

**4. Launch Vivado in the browser**

```sh
docker compose up vivado-webapp
```

Open **http://localhost:6080/vnc.html** in your browser. Vivado will launch automatically after a brief startup delay.

#### Alternative: Linux host with a local X server

If you are on Linux and already have an X server running, you can run Vivado directly through your host display without the noVNC sidecar:

```sh
docker compose run vivado-linux
```

This mounts `/tmp/.X11-unix` directly from the host and inherits `$DISPLAY`.

### Install Configuration (`config-vivado.ini`)

Installs **Vivado HL WebPACK** with Artix-7 support only (minimal footprint):

```ini
Edition=Vivado HL WebPACK
Destination=/opt/Xilinx
Modules=Vivado:1,Artix-7:1,Kintex-7:0,Zynq-7000:0,...
```

Edit `config-vivado.ini` to add additional device families before building.

---

## Xilinx ISE WebPACK 14.7

### System Requirements

| Component | Requirement |
|-----------|-------------|
| Host OS | Linux |
| ISE Version | 14.7 |
| Base Image | `ubuntu:14.04` |
| Installer | `Xilinx_ISE_DS_Lin_14.7_<date>/` directory |

> ISE 14.7 requires extensive **32-bit multilib** support and legacy libraries (`libstdc++5`, `libmotif-dev`). Ubuntu 14.04 is used as the base for maximum compatibility.

### Setup

**1. Edit `.env`**

```sh
cd docker-ise-14.7
```

Open `.env` and set your paths:

```dotenv
ISE_VERSION=14.7
INSTALLER_DIR=./Xilinx_ISE_DS_Lin_14.7_1015_1
CONFIG_DIR=/path/to/docker-vivado-webpack/docker-ise-14.7/
WORKSPACE=.
```

**2. (Optional) Generate an install config**

If you don't have a `config-ise.ini` or need to select a different edition, the `config-gen` service will run the Xilinx interactive config generator inside a minimal container and write the output to your `$WORKSPACE`:

```sh
docker compose run config-gen
```

Follow the interactive prompts, then copy the resulting config file to `config-ise.ini`.

**3. Build the ISE image**

```sh
docker compose build ise
```

**4. Launch ISE in the browser**

```sh
docker compose up ise-webapp
```

Open **http://localhost:6080/vnc.html**. ISE will launch automatically.

#### Alternative: Linux host with a local X server

```sh
docker compose run ise-linux
```

### Install Configuration (`config-ise.ini`)

Installs **ISE WebPACK** (Spartan-6 and 7-series support):

```ini
destination_dir=/opt/Xilinx
package=ISE WebPACK::1
```

### Known ISE Compatibility Fixes

ISE 14.7 has several known issues on modern Linux environments. The following environment variables are set in the docker-compose service to work around them:

| Variable | Purpose |
|----------|---------|
| `MALLOC_CHECK_=0` | Suppresses ISE memory allocator assertions that cause crashes |
| `LC_ALL=C` | Avoids locale-related ISE startup failures |
| `QT_X11_NO_MITSHM=1` | Disables MIT-SHM X extension that ISE misuses |
| `XLIB_SKIP_ARGB_VISUALS=1` | Prevents X11 ARGB visual selection crashes |

---

## noVNC Display Sidecar (`novnc-display/`)

Both tool stacks share the same reusable display container defined in `novnc-display/`.

| Component | Role |
|-----------|------|
| `Xvfb` | Virtual framebuffer X server on `:0` at `1600x900x24` |
| `x11vnc` | Headless VNC server (no password) exposing `:5900` |
| `websockify` | WebSocket-to-TCP bridge, serving noVNC UI on `:6080` |

The X server socket is exported via a named Docker volume (`x11-socket`) mounted at `/tmp/.X11-unix` in both containers.

**Access**: http://localhost:6080/vnc.html (no password required).

---

## Common Commands

### Vivado

```sh
cd docker-vivado-webpack

# Build Vivado image (requires installer)
docker compose build vivado

# Launch Vivado in browser
docker compose up vivado-webapp

# Launch Vivado using host X server (Linux only)
docker compose run vivado-linux

# Open a shell in the Vivado container
docker compose run vivado /bin/bash

# Stop all services
docker compose down
```

### ISE

```sh
cd docker-ise-14.7

# (Optional) Generate install config interactively
docker compose run config-gen

# Build ISE image (requires installer)
docker compose build ise

# Launch ISE in browser
docker compose up ise-webapp

# Launch ISE using host X server (Linux only)
docker compose run ise-linux

# Open a shell in the ISE container
docker compose run ise /bin/bash

# Stop all services
docker compose down
```

---

## Technical Notes

### BuildKit `additional_contexts`

The Dockerfiles use [BuildKit additional build contexts](https://docs.docker.com/build/building/context/#additional-build-contexts) to bind-mount the Xilinx installer directory at build time:

```yaml
additional_contexts:
  - installer_dir=${INSTALLER_DIR}
  - config_dir=${CONFIG_DIR}
```

This means:
- The installer payload is **never written into an image layer** — images stay lean.
- The installer directory can live anywhere on your host machine.
- BuildKit must be enabled (`DOCKER_BUILDKIT=1` or Docker 23+).

### PID Namespace Sharing

The webapp services use `pid: "service:web-display"` to share the PID namespace with the display sidecar. This allows the tool container to cleanly terminate the sidecar (via `kill -15 1`) when Vivado or ISE exits, shutting down the entire compose stack gracefully rather than leaving the display container orphaned.

### Container Lifecycle

When the Xilinx tool exits (user closes the GUI window), the compose command:
```
... && vivado; kill -15 1
```
sends `SIGTERM` to PID 1 of the shared PID namespace (the websockify process in the display container), causing a clean shutdown of both containers.

---

## Troubleshooting

**`pull access denied for vivado` error**
> The `vivado` image doesn't exist yet. Run `docker compose build vivado` first before `docker compose up vivado-webapp`.

**Black / blank noVNC screen**
> The X server may not have finished starting. The webapp services include a `sleep 5` delay to account for this. Increase the value in `docker-compose.yml` if needed on slower machines.

**Vivado/ISE crashes immediately on startup**
> Ensure the environment variables (`MALLOC_CHECK_=0`, `LC_ALL=C`, etc.) are set. These are pre-configured in the compose files but may need to be added if running containers manually.

**Build fails: `xsetup: not found` or `batchxsetup: not found`**
> Verify `INSTALLER_DIR` in your `.env` points to the root of the extracted Xilinx installer directory (the folder containing `xsetup` or `bin/lin64/batchxsetup`).

**`docker compose` command not found**
> Ensure you are using Docker with the compose v2 plugin (`docker compose`, not `docker-compose`). Install via your package manager or from [Docker's release page](https://github.com/docker/compose/releases).
