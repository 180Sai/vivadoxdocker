A Docker Compose module for running legacy Xilinx Vivado and Xilinx ISE installations on any machine, bypassing the need for a virtual machine setup. Where arbitrary constraints enforce the need to learn or use antiquated, unsupported versions of these IDEs, virtualization solves this by recreating the environment to run the app. Docker Compose automates the virtualization setup so users can focus more on the task at hand rather than shaping the tools they need.

## Prerequisites

- **Docker** with [BuildKit](https://docs.docker.com/build/buildkit/) and [Docker Compose](https://docs.docker.com/compose/) OR **Docker Desktop**
- [Licenses](https://www.xilinx.com/member/forms/license-form.html) for Xilinx ISE, if necessary
- **Windows Subsystem for Linux** (WSL2, for Windows only) 
- **Vivado or ISE Installer** (for local image building only)

## General Usage

Open the environment `.env` to set the `WORKSPACE` directory. The Docker container will attach this directory to ISE/Vivado.

Set the path to the license file `ISE_LICENSE_FILE` for Xilinx ISE to enable all features.

To mitigate filesystem-related issues, a migration script performs a lean copy of projects from `WORKSPACE` to a Docker volume. The files are restored upon closing ISE/Vivado. Set `AUTO_MIGRATE` and `AUTO_RESTORE` to configure the migration behaviour.

> Projects may need to be cleaned in ISE using **Project > Cleanup Project Files.**

- Set `WORKSPACE_MAX_MB` to limit the migration script's maximum copy size. If the size is exceeded, then the application will not run.
- Set `ENABLE_CRASH_RECOVERY` to allow the migration script to store files in `archives/` under `WORKSPACE`, if the Docker volume contains unsaved changes.

To start the application, run within the repository directory:

```bash
docker compose up ise
docker compose up vivado
```

For Windows users, Docker must be started within WSL to properly connect to the display. Run these commands to start the application:

```bash
wsl docker compose up ise
wsl docker compose up vivado
```

Images for Vivado 2016.3 and ISE 14.7 are retrieved from [this repository](https://hub.docker.com/repository/docker/180sai/vivadoxdocker/) on Docker Hub.

The migration script may ask to archive detected unsaved changes and perform a migration to a Docker volume. On closing ISE/Vivado, the script may also ask to restore changes to the `WORKSPACE` directory.

To ensure that the application is closed, run:

```bash
docker compose down
```

**NOTE:** The full Vivado/ISE image is larger than the size of the installed application by a factor of 3.

| Image         | **Disk Usage** | Installed Content Size |
| ------------- | -------------- | ---------------------- |
| Vivado 2016.3 | **13.1 GB**    | 3.96 GB                |
| ISE 14.7      | **21.4 GB**    | 6.08 GB                | 

## Local Image Building

First download the full product installer from the [official downloads website](https://www.xilinx.com/support/download.html) and extract the compressed file to a directory.

Edit the build section of the `.env` file pointing to the installer directory and the installer configuration file using `ISE_INSTALLER_DIR`, `ISE_CONFIG_DIR`, etc. Previews of the configuration file are found in `dise/` and `dvivado/`.

To start the local image build, run:

```bash
docker compose build ise-base
docker compose build vivado-base
```

Image building requires a significant available size on disk **(60+ GB).** After the image is built, retrieve the unnecessary space using `docker builder prune`.
