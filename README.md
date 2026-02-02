![Super PXE Banner](assets/banner.png)

# <img src="assets/icon.png" width="48" height="48" align="center"/> Super PXE Server (Next-Gen)

**The Ultimate Network Boot Solution**

**Copyright © 2026 BQD Services. All Rights Reserved.**
**Version: v2.0 (Next-Gen)**

## Overview

Super PXE Server is an advanced, automated network boot appliance designed to unify the best features of tools like **iVentoy**, **Netboot.xyz**, and **Enterprise Diskless Solutions**.

It provides a "Drop-and-Boot" experience: simply place an ISO, VHD, or Disk Image into a folder, and the server automatically:
1.  **Detects** the file.
2.  **Generates** the necessary backend configuration (iSCSI targets, NFS exports).
3.  **Updates** the dynamic iPXE boot menu.
4.  **Handles** complex logic like **Secure Boot** chaining and **Copy-on-Write Snapshots** for multiple clients.

---

## Licensing & Editions

Super PXE Server operates on a **Freemium Proprietary** model.

### 60-Day Full Trial
Every installation includes a **60-Day Enterprise Trial** enabled by default. This unlocks all features, including unlimited diskless workstations and automated injection.

### Community Edition (Free Forever)
After the trial expires, the server reverts to Community Edition:
*   **Unlimited ISO Booting:** Boot as many installers or live tools as you need.
*   **Unlimited Read-Only VHDs:** Boot generic images on unlimited clients.
*   **Single Diskless Node:** You may maintain **one (1)** active "Persistent Overlay" client. Perfect for a personal workstation or homelab testing.
*   **No Auto-Injection:** Kickstart/Preseed injection is disabled.

### Enterprise Edition
Upgrading to Enterprise unlocks:
*   **Unlimited Persistent Workstations:** Deploy entire labs with individual persistence.
*   **Automated Injection:** Zero-touch OS installation via Kickstart/Preseed.
*   **Priority Support:** Direct email support from BQD Services.

---

## Key Capabilities

### 1. Zero-Config Booting
*   **ISOs:** Drop Linux or Windows installers into `/storage/isos`.
    *   **Windows:** Uses `wimboot` for native, high-speed HTTP booting.
    *   **Linux (Ubuntu/Debian):** Uses Kernel Extraction for instant booting.
    *   **Legacy/Other:** Falls back to `memdisk` for maximum compatibility.
*   **VHDs / Virtual Disks:** Drop `.vhd`, `.qcow2`, or `.img` files into `/storage/vhds`. The server automatically maps them as iSCSI targets.

### 2. True Diskless Workstation Engine (New in v2.0!)
*   **Golden Image Support:** Run an entire lab (e.g., 50+ PCs) from a single "Master" OS image.
*   **Automatic Copy-on-Write (COW) Overlays:** When a client configured for "Overlay" boots a Master image, the server automatically creates a **private QCOW2 overlay** for that specific MAC address.
*   **Individual Persistence:** Changes made by the client are saved to their private overlay (`/storage/overlays/`), keeping the Master image pristine.

### 3. Advanced Auto-Installation & Injection (New in v2.0!)
*   **Injection Support:** Upload `kickstart.cfg`, `preseed.cfg`, or `unattend.xml` files via the Web UI.
*   **Zero-Touch Deployment:** Assign injection files to specific clients. The server automatically patches the boot arguments (e.g., `inst.ks=http://...` or `autoinstall`) to trigger a fully automated installation.
*   **Custom Kernel Arguments:** Pass specific boot parameters (e.g., `quiet splash`, `console=ttyS0`) per client.

### 4. Enterprise-Grade Security
*   **Secure Boot Compatible:** Includes a pre-configured boot chain using a Microsoft-Signed Shim (`shim.efi`) loading a signed iPXE binary.
*   **Client Isolation:** The iSCSI backend restricts target access by IP/Initiator, ensuring Client A cannot corrupt Client B's disk overlay.
*   **Dynamic iSCSI Targeting:** Automatically generates Read-Only targets for installers and Read-Write targets for diskless clients.

---

## Web Interface (v2.0)

A modern, "Shield of Speed" themed Admin Console allows you to manage the entire ecosystem without touching a command line.

**Access:** Open `http://<Your-Server-IP>:8000`

### Features
*   **Dashboard:** Real-time view of active sessions (iSCSI/NFS) and system health.
*   **Asset Management:** Browse and search ISOs, VHDs, and Injection files.
    *   **New:** Upload Kickstart/Preseed files directly from the browser.
*   **Client Management:** 
    *   Map specific MAC addresses to specific Images (ISO or VHD).
    *   **Enable Persistent Overlay:** Toggle for VHDs to create private storage.
    *   **Attach Injection:** Select a configuration file for auto-install.
    *   **Set Hostname:** Track client identity.

---

## Installation

The provided `install_super_pxe.sh` is a comprehensive, single-file installer.

**Prerequisites:**
*   **OS:** Ubuntu 22.04 LTS or 24.04 LTS (Fresh Install Recommended).
*   **Network:** Wired Ethernet connection with a Static IP is highly recommended.

**How to Install:**
```bash
# 1. Download the installer
wget https://raw.githubusercontent.com/YourRepo/super-pxe/main/install_super_pxe.sh

# 2. Make executable
chmod +x install_super_pxe.sh

# 3. Run as Root
sudo ./install_super_pxe.sh
```

> **Note:** Rerunning the installer on an existing system will **preserve** your `config.json` and assets.

---

## Docker Deployment (Portable)

You can run Super PXE Server on any OS (Linux, Windows, macOS) using Docker.

**Prerequisites:** Docker & Docker Compose installed.

**1. Create a `docker-compose.yml`:**
```yaml
version: '3.8'
services:
  super-pxe:
    image: bqdservices/super-pxe-server:latest # Or build locally
    container_name: super-pxe
    privileged: true  # REQUIRED for iSCSI/TGT
    network_mode: "host" # REQUIRED for PXE/TFTP
    environment:
      - SERVER_IP=192.168.1.100 # Replace with your Host IP
    volumes:
      - ./runtime/storage:/opt/super-pxe-server/storage
    restart: unless-stopped
```

**2. Start the Server:**
```bash
docker-compose up -d
```

---

## Usage Guide

### 1. Adding Boot Images
*   **Installers (ISOs):** Copy to `/opt/super-pxe-server/storage/isos/`
*   **Virtual Disks (VHDs):** Copy to `/opt/super-pxe-server/storage/vhds/`

### 2. DHCP Configuration (Critical)
Configure your existing DHCP Server (Router, Windows Server, etc.) to point clients to this server.

*   **Next-Server (Option 66):** `<IP_Address_of_This_Server>`
*   **Boot Filename (Option 67):**
    *   **UEFI Clients:** `shim.efi` (Recommended)
    *   **Legacy BIOS:** `undionly.kpxe`

### 3. Monitoring & Logs
*   **Check Brain Service:** `journalctl -u super-pxe-brain -f`
*   **View Active iSCSI Targets:** `tgt-admin --show`

---

## Troubleshooting

**Problem: "Exec format error" when booting ISOs**
*   **Fix:** Re-run the installer or manually extract `memdisk` from syslinux.

**Problem: Windows Setup can't see the hard drive**
*   **Fix:** Ensure your ISO has VirtIO drivers if running in a VM, or inject them into `boot.wim`.

**Problem: Diskless Client boots to Read-Only Master**
*   **Fix:** Ensure you have added the client in the Web UI and checked "Enable Persistent Overlay".

---

## License



**Proprietary / Freemium**



**Super PXE Server** is proprietary software developed by **BQD Services**.



*   **Community Use:** Free for personal and limited commercial use (subject to Community Edition feature limits).

*   **Enterprise Use:** Requires a paid subscription for full feature access beyond the trial period.

*   **Redistribution:** You may not redistribute modified versions of this software without express written permission.



The core orchestration logic ("The Brain"), installer script, and architectural designs are the intellectual property of **BQD Services**.
