# Super PXE Server

 <img width="3168" height="1344" alt="banner" src="https://github.com/user-attachments/assets/d867580f-8a88-4792-aa7c-afdefa786b30" />

**Drop. Boot. Done.**

**Copyright © 2026 BQD Services LLC. All Rights Reserved.**

## Overview
Super PXE Server (SPS) is an advanced, automated network boot appliance designed to unify the best features of tools like **iVentoy** and **Enterprise Diskless Solutions**.

It provides a "Drop-and-Boot" experience: simply place an ISO, VHD, or Disk Image into a folder, and the server automatically:
1.  **Detects** the file.
2.  **Generates** the necessary backend configuration (iSCSI targets, NFS exports).
3.  **Updates** the dynamic iPXE boot menu.
4.  **Handles** complex logic like **Secure Boot** chaining and **Copy-on-Write Snapshots**.

---

## Key Capabilities

### 1. Web Admin Interface (New in v1.37)
* **Visual Dashboard:** Manage your server from any browser.
* **Asset Detection:** Automatically scans and lists detected ISOs and VHDs.
* **Safe Configuration:** "Advanced Mode" prevents accidental network misconfigurations (DHCP/IP settings).


https://github.com/user-attachments/assets/2b0a6516-1098-4a1b-8604-cc5692299a34


### 2. Zero-Config Booting
* **ISOs:** Drop Linux or Windows installers into `/storage/isos`.
    * **Windows:** Uses `wimboot` for native, high-speed HTTP booting.
    * **Linux (Ubuntu/Debian):** Uses Kernel Extraction for instant booting.
    * **Legacy/Other:** Falls back to `memdisk`.
* **VHDs:** Drop `.vhd` or `.qcow2` files into `/storage/vhds` to automatically map them as iSCSI targets.

### 3. Diskless Workstation Engine
* **Golden Image Support:** Run an entire lab (e.g., 50+ PCs) from a single "Master" OS image.
* **Automatic Snapshots:** When a client boots a Master image, the server automatically creates a **Copy-on-Write (CoW)** snapshot for that specific client.
* **Individual Persistence:** Each diskless client gets its own persistent overlay, preserving user data while keeping the Master image pristine.

### 4. Enterprise-Grade Security
* **Secure Boot Compatible:** Includes a pre-configured boot chain using a Microsoft-Signed Shim (`shim.efi`).
* **Client Isolation:** The iSCSI backend restricts target access by IP.

---

## Compatibility Matrix

**Current v1.0 Support Status:**

| OS Type | Boot Method | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Windows 10 / 11** | `wimboot` | ✅ **Native** | Fast load. Works with Secure Boot. |
| **Ubuntu 20.04+** | Kernel Extraction | ✅ **Native** | Supports `casper` boot arguments. |
| **Debian / Mint** | Kernel Extraction | ✅ **Native** | Automatic detection. |
| **Fedora / RHEL** | `memdisk` | ⚠️ **Experimental** | Requires loading full ISO to RAM. Client needs 4GB+ RAM. |
| **Arch / Other** | `memdisk` | ⚠️ **Experimental** | May fail on older BIOS/Hardware. |

---

## Installation

**Prerequisites:**
* **OS:** Ubuntu 22.04 LTS or 24.04 LTS (Fresh Install Recommended).
* **Network:** Wired Ethernet connection with a Static IP is highly recommended.

### Method 1: Debian Package (Recommended)
This is the cleanest installation method. It handles all dependencies (Nginx, Python, TGT, etc.) automatically.

1.  **Download the latest package:**
    ```bash
    wget [https://github.com/bqd-services-llc/super-pxe-server/releases/tag/v1.37](https://github.com/bqd-services-llc/super-pxe-server/releases/download/v1.37/super-pxe-server_1.37_amd64.deb)
    ```

2.  **Install via apt:**
    ```bash
    sudo apt install ./super-pxe-server_1.37_amd64.deb
    ```

3.  **Access the Dashboard:**
    Open your browser and navigate to: `http://<your-server-ip>:8000`

### Method 2: Docker Container
Ideal for testing or containerized labs.
*Note: Requires `--network host` to handle DHCP/TFTP broadcast traffic.*

```bash
docker run -d \
  --name super-pxe \
  --network host \
  --restart always \
  -v /opt/super-pxe/storage:/opt/super-pxe-server/storage \
  ghcr.io/bqdservices/super-pxe-server:latest

```

### Method 3: Manual Script

If you cannot use the .deb package or Docker, you can use the raw installer script:

```bash
wget [https://raw.githubusercontent.com/YourRepo/super-pxe/main/install_super_pxe.sh](https://raw.githubusercontent.com/YourRepo/super-pxe/main/install_super_pxe.sh)
chmod +x install_super_pxe.sh
sudo ./install_super_pxe.sh

```

---

## 🔧 Beta Program Tools

If you are participating in the **Smoke Test** or **Beta Program**, please install the additional diagnostics toolkit. This provides log collection and debug utilities.

1. **Install the Beta Tools:**
```bash
wget [https://github.com/YourRepo/releases/download/v1.37/super-pxe-beta-tools_1.37_all.deb](https://github.com/YourRepo/releases/download/v1.37/super-pxe-beta-tools_1.37_all.deb)
sudo apt install ./super-pxe-beta-tools_1.37_all.deb

```


2. **Usage:**
This package adds the `sps-debug` command to your system.
```bash
# Generate a bug report archive
sudo sps-debug --collect

# View live server logs
sudo sps-debug --logs

```



---

## Troubleshooting

**Problem: "Exec format error" when booting ISOs**

* **Cause:** The `memdisk` binary is corrupted or empty.
* **Fix:** Re-install the package to restore the binary.

**Problem: Windows Setup can't see the hard drive**

* **Cause:** The Windows ISO is missing VirtIO or Network drivers.
* **Fix:** You may need to inject drivers into your `boot.wim`.

**Problem: Client hangs at "Loading RAMDISK..."**

* **Cause:** You are booting a large ISO via `memdisk` on a machine with insufficient RAM.
* **Fix:** Add more RAM to the client or use a supported distro (Ubuntu/Windows).

---

## License

**Proprietary / Closed Source (During Beta)**
The core orchestration logic ("The Brain"), installer script, and architectural designs are the intellectual property of **BQD Services LLC**. Unauthorized reproduction, distribution, or reverse engineering is strictly prohibited.

```

```
