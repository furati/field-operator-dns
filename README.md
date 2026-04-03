# Field DNS Container

A lightweight, containerized **Bind9** DNS server designed specifically for **Nutanix AHV Foundation** and field deployments. It allows service engineers to provide a local, project-specific DNS infrastructure directly from a service notebook without interfering with the host OS.

## 1. Project Overview

During Nutanix Foundation (cluster imaging), several infrastructure services are required. This project automates the DNS requirement by providing:
* **Project-based Isolation:** Each deployment has its own configuration directory.
* **Non-Root Execution:** The container maps its internal user to the host's UID/GID for seamless file access (even on USB drives).
* **Agnostic Health Checks:** Built-in `localhost` resolution for status verification.
* **Professional OCI Metadata:** Fully compliant with Open Container Initiative standards for enterprise registries.

## 2. Directory Structure

```text
.
├── Makefile                # Main orchestration (Build, Run, Test, Push)
├── build-and-push-dns.yml  # Ansible Playbook for CI/CD and GHCR Push
├── config/                 # Project-specific DNS zone files
│   ├── named.conf          # Main Bind9 configuration
│   ├── db.nutanix.internal # Forward lookup zone
│   ├── db.192.168.100      # Reverse lookup zone
│   ├── db.local            # Localhost forward (for testing)
│   └── db.127              # Localhost reverse (for testing)
└── docker/                 # Container logic
    ├── Dockerfile          # Alpine-based Bind9 image
    └── entrypoint.sh       # Dynamic User-Mapping & Startup script
```

## 3. Architecture & Security

The container employs a **Dynamic User-Mapping** strategy. When the container starts, the `entrypoint.sh` script:
1. Detects the `HOST_UID` and `HOST_GID` passed via environment variables.
2. Dynamically creates a matching user inside the Alpine-based container.
3. Executes the `named` (Bind9) process as that specific user.

This ensures that:
* Zone files on the host (or USB stick) can be mounted as **Read-Only (`:ro`)**.
* The container cannot modify host files, but has full read access regardless of host-level permissions.
* No `root` processes are required for the DNS service inside the container (except for initial port binding if not using Rootless Docker).

## 4. Getting Started (Field Operations)

### Prerequisites
* Docker installed on the Service Notebook.
* Port 53 must be available (disable `systemd-resolved` or macOS DNS responders if necessary).

### Usage
To start the DNS service for a specific project:

1. **Configure Zones:** Update files in `./config/` with the target Nutanix Node/CVM IPs.
2. **Build (Optional):** If not pulling from registry:
   ```bash
   make build
   ```
3. **Run Service:**
   ```bash
   make run
   ```
4. **Verify Function:**
   ```bash
   make test
   ```

## 5. Makefile Targets

The included `Makefile` provides a self-documenting interface:

| Target | Description |
| :--- | :--- |
| `make help` | Displays available commands and current version info. |
| `make build` | Builds the local Docker image using the current Bind9 version. |
| `make run` | Starts the DNS daemon with project configs mounted. |
| `make test` | Performs an agnostic DNS lookup (localhost) to verify readiness. |
| `make logs` | Tails the Bind9 logs for debugging. |
| `make push` | Triggers the Ansible workflow to build and push to GHCR. |
| `make stop` | Gracefully stops and removes the DNS container. |

## 6. Automation (Ansible)

The `build-and-push-dns.yml` playbook automates the lifecycle of the image:
1. **Version Discovery:** Queries the latest Alpine repository for the current `bind` version.
2. **OCI Labeling:** Injects build arguments (Metadata, Repo URL, Version).
3. **Registry Integration:** Authenticates with GitHub Container Registry (GHCR) and pushes `latest` and `version-specific` tags.

---
**Author:** Ralf Buhlrich <ralf@buhlrich.com>  
**License:** MIT