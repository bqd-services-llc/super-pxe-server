![Super PXE Banner](banner.png)

# <img src="icon.png" width="48" height="48" align="center"/> Super PXE Server

**\*\*The Ultimate Open-Source Network Boot Solution\*\***

**\*\*Copyright © 2026 BQD Services LLC. All Rights Reserved.\*\***
**Version: v1.37**

## Overview
![Super PXE Interface](release_v1/SPS-image.png)

Super PXE Server is an advanced, automated network boot appliance designed to unify the best features of tools like **\*\*iVentoy\*\***, **\*\*Netboot.xyz\*\***, and **\*\*Enterprise Diskless Solutions\*\***.

It provides a "Drop-and-Boot" experience: simply place an ISO, VHD, or Disk Image into a folder, and the server automatically:  
1\.  **\*\*Detects\*\*** the file.  
2\.  **\*\*Generates\*\*** the necessary backend configuration (iSCSI targets, NFS exports).  
3\.  **\*\*Updates\*\*** the dynamic iPXE boot menu.  
4\.  **\*\*Handles\*\*** complex logic like **\*\*Secure Boot\*\*** chaining and **\*\*Copy-on-Write Snapshots\*\*** for multiple clients.

\---

\#\# Key Capabilities

\#\#\# 1\. Zero-Config Booting  
\* **\*\*ISOs:\*\*** Drop Linux or Windows installers into \`/storage/isos\`.  
    \* **\*\*Windows:\*\*** Uses \`wimboot\` for native, high-speed HTTP booting.  
    \* **\*\*Linux (Ubuntu/Debian):\*\*** Uses Kernel Extraction for instant booting.  
    \* **\*\*Legacy/Other:\*\*** Falls back to \`memdisk\` for maximum compatibility.  
\* **\*\*VHDs / Virtual Disks:\*\*** Drop \`.vhd\`, \`.qcow2\`, or \`.img\` files into \`/storage/vhds\`. The server automatically maps them as iSCSI targets.

\#\#\# 2\. Diskless Workstation Engine  
\* **\*\*Golden Image Support:\*\*** Run an entire lab (e.g., 50+ PCs) from a single "Master" OS image.  
\* **\*\*Automatic Snapshots:\*\*** When a client boots a Master image, the server automatically creates a **\*\*Copy-on-Write (CoW)\*\*** snapshot for that specific client.  
\* **\*\*Individual Persistence:\*\*** Each diskless client gets its own persistent overlay (\`/storage/diskless/overlays/\`), preserving user data while keeping the Master image pristine.

\#\#\# 3\. Enterprise-Grade Security  
\* **\*\*Secure Boot Compatible:\*\*** Includes a pre-configured boot chain using a Microsoft-Signed Shim (\`shim.efi\`) loading a signed iPXE binary.  
\* **\*\*Client Isolation:\*\*** The iSCSI backend restricts target access by IP, ensuring Client A cannot corrupt Client B's disk overlay.

\---

\#\# Compatibility Matrix

**\*\*Current v1.0 Support Status:\*\***

| OS Type | Boot Method | Status | Notes |  
| :--- | :--- | :--- | :--- |  
| **\*\*Windows 10 / 11\*\*** | \`wimboot\` | ✅ **\*\*Native\*\*** | Fast load. Works with Secure Boot. |  
| **\*\*Ubuntu 20.04+\*\*** | Kernel Extraction | ✅ **\*\*Native\*\*** | Supports \`casper\` boot arguments. |  
| **\*\*Debian / Mint\*\*** | Kernel Extraction | ✅ **\*\*Native\*\*** | Automatic detection. |  
| **\*\*Fedora / RHEL\*\*** | \`memdisk\` | ⚠️ **\*\*Experimental\*\*** | Requires loading full ISO to RAM. Client needs 4GB+ RAM. |  
| **\*\*Arch / Other\*\*** | \`memdisk\` | ⚠️ **\*\*Experimental\*\*** | May fail on older BIOS/Hardware. |

\---

\#\# Installation

The provided \`install\_super\_pxe.sh\` is a comprehensive, single-file installer.

**\*\*Prerequisites:\*\***  
\* **\*\*OS:\*\*** Ubuntu 22.04 LTS or 24.04 LTS (Fresh Install Recommended).  
\* **\*\*Network:\*\*** Wired Ethernet connection with a Static IP is highly recommended.  
\* **\*\*Storage:\*\*** Sufficient disk space for your ISOs and VHDs.

**\*\*How to Install:\*\***  
\`\`\`bash  
\# 1\. Download the installer  
wget \[https://raw.githubusercontent.com/YourRepo/super-pxe/main/install\_super\_pxe.sh\](https://raw.githubusercontent.com/YourRepo/super-pxe/main/install\_super\_pxe.sh)

\# 2\. Make executable  
chmod \+x install\_super\_pxe.sh

# 3. Run as Root
sudo ./install_super_pxe.sh

> **Note (v1.25+):** Rerunning the installer on an existing system will **preserve** your `config.json` and assets.

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

**3. Add Images:**
Place ISOs in the `./storage/isos/` folder on your host machine. They will appear in the web UI automatically.

## ---

**Usage Guide**

### **1\. Adding Boot Images**

* **Installers (ISOs):**  
  Copy files to: /opt/super-pxe-server/storage/isos/  
  Or you can leverage Symlinks, and just add a Symlink that links to the directory that has all of your ISO files in it.
  * *Example:* ubuntu-22.04.iso, windows-11.iso  
* **Persistent Desktops (VHDs):**  
  Copy files to: /opt/super-pxe-server/storage/vhds/  
  Or you can leverage Symlinks, and just add a Symlink that links to the directory that has all of your VHD files in it.
  * *Example:* win10-master.qcow2, linux-desktop.img

### **2\. DHCP Configuration (Critical Step)**

You must configure your existing DHCP Server (Router, Windows Server, etc.) to point clients to this server.

* **Next-Server (Option 66):** \<IP\_Address\_of\_This\_Server\>  
* **Boot Filename (Option 67):**  
  * **UEFI Clients:** shim.efi (Recommended)  
  * **Legacy BIOS:** undionly.kpxe

### **3. Monitoring & Logs**

* **Check Brain Service:**  
  Bash  
  journalctl \-u super-pxe-brain \-f

* **View Active iSCSI Targets:**  
  Bash  
  tgt-admin \--show

---

## Configuration & Web Interface

**New in v1.1:** A web-based Admin Console is available to manage settings without command-line editing.

**Access:** Open `http://<Your-Server-IP>:8000` in a web browser.

### **Security & Authentication (v1.25+)**
The Web UI and API are now protected by Basic Authentication.
*   **Default Username:** `admin`
*   **Default Password:** `admin` (Change this immediately in the UI!)

### **Settings Explained**
All settings are stored in `/opt/super-pxe-server/brain/config.json`.

| Setting | JSON Key | Default | Description |
| :--- | :--- | :--- | :--- |
| **Server IP** | `server_ip` | `127.0.0.1` | The IP address of *this* PXE server. Used to generate boot URLs. |
| **DHCP Next-Server** | `dhcp_next_server` | `127.0.0.1` | The IP clients should contact for TFTP/HTTP boot files (usually same as Server IP). |
| **iSCSI ACLs** | `iscsi_allowed_initiators`| `ALL` | **Security Critical:** Controls which clients can mount VHDs.<br>• `ALL`: Open to everyone (Simpler for labs).<br>• `192.168.1.50`: Only this IP can connect.<br>• `192.168.1.0/24`: Subnet range (requires compatible TGT version). |
| **Boot Timeout** | `boot_timeout` | `10` | Seconds to wait at the boot menu before auto-selecting the default option. |
| **Menu Title** | `menu_title` | `Super PXE Server by BQD Services LLC` | Custom text displayed at the top of the iPXE boot screen (e.g., "Company IT Lab"). |

---

**Troubleshooting**

**Problem: "Exec format error" when booting ISOs**

* **Cause:** The memdisk binary is corrupted or empty.  
* **Fix:** Re-run the installer or manually extract memdisk from syslinux.

**Problem: Windows Setup can't see the hard drive**

* **Cause:** The Windows ISO is missing VirtIO or Network drivers.  
* **Fix:** You may need to inject drivers into your boot.wim (Feature coming in v1.1).

**Problem: Client hangs at "Loading RAMDISK..."**

* **Cause:** You are booting a large ISO (like Fedora) via memdisk on a machine with insufficient RAM.  
* **Fix:** Add more RAM to the client or use a supported distro (Ubuntu/Windows).

## ---

**License**

**Proprietary / Closed Source (During Beta)**

The core orchestration logic ("The Brain"), installer script, and architectural designs are the intellectual property of **BQD Services LLC**. Unauthorized reproduction, distribution, or reverse engineering is strictly prohibited.
