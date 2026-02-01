#!/bin/bash

# Super PXE Server - All-in-One Installer & Verifier (v1.37)
# Target OS: Ubuntu 22.04 / 24.04 LTS (Debian-based recommended)
# Run as root.

LOG_FILE="/var/log/super_pxe_install.log"
PROJECT_DIR="/opt/super-pxe-server"
BRAIN_PORT=8000
SERVER_IP=$(hostname -I | awk '{print $1}')

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%T')] $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%T')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

err() {
    echo -e "${RED}[$(date +'%T')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

# --- 1. System Checks ---
log "Starting installation (v1.37)..."
if [ "$EUID" -ne 0 ]; then 
  err "Please run as root."
fi

log "Detected IP: $SERVER_IP"

# --- 2. Install Dependencies ---
log "Installing System Dependencies..."
apt-get update >> "$LOG_FILE" 2>&1
apt-get install -y nginx tftpd-hpa tgt nfs-kernel-server python3-pip python3-venv qemu-utils wget curl shim-signed ipxe syslinux-common >> "$LOG_FILE" 2>&1 || err "Failed to install packages."

# --- 3. Create Directory Structure ---
log "Creating Project Structure at $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"/{brain/static,config,storage/{isos,vhds,masters,drivers,diskless},generated_configs,tftpboot}
chmod -R 755 "$PROJECT_DIR"
chown -R nobody:nogroup "$PROJECT_DIR/storage"

# --- 3b. Install Branding ---
if [ -f "icon.png" ]; then
    log "Installing Branding Images..."
    cp icon.png "$PROJECT_DIR/brain/static/"
    cp banner.png "$PROJECT_DIR/brain/static/" 2>/dev/null || true
else
    warn "Branding images not found in current directory. Admin UI will lack logos."
fi

# --- 4. Deploy The "Brain" (Python Service) ---
log "Deploying the Brain Service (v1.37)..."

# Write requirements.txt
cat <<EOF > "$PROJECT_DIR/brain/requirements.txt"
fastapi
uvicorn
jinja2
python-multipart
requests
EOF

# Write config.json (Safely)
if [ -f "$PROJECT_DIR/brain/config.json" ]; then
    log "Config file exists. Skipping overwrite to preserve settings."
else
    log "Creating default config.json..."
    cat <<EOF > "$PROJECT_DIR/brain/config.json"
{
    "server_ip": "$SERVER_IP",
    "dhcp_next_server": "$SERVER_IP",
    "iscsi_allowed_initiators": "ALL",
    "boot_timeout": 10,
    "menu_title": "Super PXE Server (v1.37)",
    "admin_password": "admin"
}
EOF
fi

# Write static/index.html (Admin Dashboard - Enhanced)
cat <<EOF > "$PROJECT_DIR/brain/static/index.html"
$(cat gemini-projects/super-pxe-server/src/brain/static/index.html)
EOF

# Write brain.py (Updated for Config & API & Auth & Optimized Scanning)
cat <<EOF > "$PROJECT_DIR/brain/brain.py"
"""
Super PXE Server - Brain Service v1.38 (Optimized)
Copyright (c) 2026 BQD Services LLC. All Rights Reserved.
"""

import os
import logging
import json
import secrets
from fastapi import FastAPI, Request, Depends, HTTPException, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.responses import PlainTextResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
from typing import Optional

# Configuration
CURRENT_FILE = Path(__file__).resolve()

# Detect if running in Local Development or Production
if "src/brain" in str(CURRENT_FILE):
    # Local Dev
    PROJECT_ROOT = CURRENT_FILE.parent.parent.parent # super-pxe-server/
    STORAGE_ROOT = PROJECT_ROOT / "runtime" / "storage"
    CONFIG_FILE = CURRENT_FILE.parent / "config.json"
    GENERATED_DIR = PROJECT_ROOT / "runtime" / "generated_configs"
    STATIC_DIR = CURRENT_FILE.parent / "static"
else:
    # Production / Docker (flat structure: $PROJECT_DIR/brain)
    PROJECT_ROOT = Path("$PROJECT_DIR")
    STORAGE_ROOT = PROJECT_ROOT / "storage"
    CONFIG_FILE = PROJECT_ROOT / "brain/config.json"
    GENERATED_DIR = PROJECT_ROOT / "generated_configs"
    STATIC_DIR = PROJECT_ROOT / "brain/static"

ISO_DIR = STORAGE_ROOT / "isos"
VHD_DIR = STORAGE_ROOT / "vhds"

# Default Config
DEFAULT_CONFIG = {
    "server_ip": "$SERVER_IP",
    "dhcp_next_server": "$SERVER_IP",
    "iscsi_allowed_initiators": "ALL",
    "boot_timeout": 10,
    "menu_title": "Super PXE Server",
    "admin_password": "admin"
}

app = FastAPI()
security = HTTPBasic()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Brain")

# Serve Static Files (Dashboard)
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

class ConfigModel(BaseModel):
    server_ip: str
    dhcp_next_server: str
    iscsi_allowed_initiators: str
    boot_timeout: int
    menu_title: str
    admin_password: str

def load_config():
    config = DEFAULT_CONFIG.copy()
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r") as f:
                file_config = json.load(f)
                config.update(file_config)
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
    return config

def save_config(config_data):
    with open(CONFIG_FILE, "w") as f:
        json.dump(config_data, f, indent=4)

def get_current_username(credentials: HTTPBasicCredentials = Depends(security)):
    config = load_config()
    correct_password = config.get("admin_password", "admin")
    
    # Use secrets.compare_digest for constant-time comparison to prevent timing attacks
    if not secrets.compare_digest(credentials.password, correct_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username

# Optimized Shallow Scanning
def get_directory_contents(base_dir: Path, sub_path: str = ""):
    target_dir = (base_dir / sub_path).resolve()
    
    # Security: Ensure we don't escape STORAGE_ROOT
    if not str(target_dir).startswith(str(base_dir.resolve())):
        return [], []

    files = []
    dirs = []
    
    if not target_dir.exists():
        return files, dirs

    try:
        with os.scandir(target_dir) as it:
            for entry in it:
                rel_entry_path = os.path.join(sub_path, entry.name)
                if entry.is_dir(follow_symlinks=True):
                    dirs.append({
                        "name": entry.name,
                        "path": rel_entry_path
                    })
                elif entry.is_file(follow_symlinks=True):
                    files.append({
                        "name": entry.name,
                        "path": rel_entry_path,
                        "label": Path(entry.name).stem
                    })
    except Exception as e:
        logger.error(f"Error scanning directory {target_dir}: {e}")

    # Sort alphabetically
    files.sort(key=lambda x: x["name"].lower())
    dirs.sort(key=lambda x: x["name"].lower())
    
    return files, dirs

# Caches for Root level (for Dashboard/API compatibility)
ISO_CACHE = []
VHD_CACHE = []

def refresh_root_caches():
    global ISO_CACHE, VHD_CACHE
    isos, iso_dirs = get_directory_contents(ISO_DIR)
    ISO_CACHE = [f for f in isos if f['name'].endswith('.iso')]
    vhds, vhd_dirs = get_directory_contents(VHD_DIR)
    VHD_CACHE = [f for f in vhds if any(f['name'].endswith(ext) for ext in [".vhd", ".qcow2", ".img"])]

@app.on_event("startup")
async def startup_event():
    logger.info("Performing initial root asset scan...")
    refresh_root_caches()

def generate_iscsi_config(vhds, allowed_initiators="ALL"):
    config_lines = []
    for vhd in vhds:
        # Create a unique IQN based on path to avoid collisions
        safe_name = vhd['path'].lower().replace("/", "-").replace("\\\\\\\\", "-").replace("_", "-").replace(".", "-")
        iqn = f"iqn.2024-01.com.pxeserver:{safe_name}"
        config_lines.append(f"<target {iqn}>")
        config_lines.append(f"    backing-store {vhd['full_path']}")
        config_lines.append(f"    initiator-address {allowed_initiators}")
        config_lines.append("</target>")
    
    config_path = GENERATED_DIR / "targets.conf"
    with open(config_path, "w") as f:
        f.write("\n".join(config_lines))

# --- API Endpoints ---

@app.get("/")
async def read_root(username: str = Depends(get_current_username)):
    return FileResponse(STATIC_DIR / "index.html")

@app.get("/api/config")
async def get_config(username: str = Depends(get_current_username)):
    return load_config()

@app.post("/api/config")
async def update_config(config: ConfigModel, username: str = Depends(get_current_username)):
    save_config(config.dict())
    return {"status": "success", "config": config}

@app.get("/api/assets")
async def get_assets(username: str = Depends(get_current_username)):
    return {
        "isos": ISO_CACHE,
        "vhds": VHD_CACHE
    }

@app.post("/api/refresh")
async def refresh_assets(username: str = Depends(get_current_username)):
    refresh_root_caches()
    return {"status": "success", "isos": len(ISO_CACHE), "vhds": len(VHD_CACHE)}

# --- Boot Logic ---

@app.get("/boot.ipxe", response_class=PlainTextResponse)
async def get_menu(request: Request, path: str = "", type: str = "root"):
    config = load_config()
    server_ip = config.get("server_ip", "127.0.0.1")
    timeout = config.get("boot_timeout", 10) * 1000 
    title = config.get("menu_title", "Super PXE Server")

    script = ["#!ipxe", f"set timeout {timeout}", f"menu {title} - {path if path else 'Root'}"]
    
    if path:
        script.append(f"item --key 0 back .. Back to Previous")

    iso_files, iso_dirs = [], []
    vhd_files, vhd_dirs = [], []

    if type == "root" or type == "iso":
        iso_files, iso_dirs = get_directory_contents(ISO_DIR, path)
    
    if type == "root" or type == "vhd":
        vhd_files, vhd_dirs = get_directory_contents(VHD_DIR, path)

    # Render Directories
    if iso_dirs or vhd_dirs:
        script.append("item --gap -- Directories")
        for d in iso_dirs:
            script.append(f"item dir_iso_{hash(d['path'])} [DIR] {d['name']}")
        for d in vhd_dirs:
            script.append(f"item dir_vhd_{hash(d['path'])} [DIR] {d['name']}")

    # Render Files
    if iso_files:
        script.append("item --gap -- ISO Images")
        for f in iso_files:
            if f['name'].endswith(".iso"):
                script.append(f"item iso_{hash(f['path'])} {f['name']}")

    if vhd_files:
        script.append("item --gap -- VHD Images")
        active_vhds = []
        for f in vhd_files:
            if any(f['name'].endswith(ext) for ext in [".vhd", ".qcow2", ".img"]):
                full_path = str((VHD_DIR / f['path']).absolute())
                safe_name = f['path'].lower().replace("/", "-").replace("\\", "-").replace("_", "-").replace(".", "-")
                iqn = f"iqn.2024-01.com.pxeserver:{safe_name}"
                script.append(f"item vhd_{hash(f['path'])} {f['name']}")
                active_vhds.append({"iqn": iqn, "full_path": full_path, "path": f['path']})
        
        if active_vhds:
            generate_iscsi_config(active_vhds, config.get("iscsi_allowed_initiators", "ALL"))

    script.append("choose target && goto \${target}")

    # Navigation Logic
    if path:
        parent_path = os.path.dirname(path)
        script.append(f":back")
        script.append(f"chain http://{server_ip}:8000/boot.ipxe?path={parent_path}&type={type}")

    for d in iso_dirs:
        script.append(f":dir_iso_{hash(d['path'])}")
        script.append(f"chain http://{server_ip}:8000/boot.ipxe?path={d['path']}&type=iso")
    
    for d in vhd_dirs:
        script.append(f":dir_vhd_{hash(d['path'])}")
        script.append(f"chain http://{server_ip}:8000/boot.ipxe?path={d['path']}&type=vhd")

    for f in iso_files:
        if f['name'].endswith(".iso"):
            script.append(f":iso_{hash(f['path'])}")
            script.append(f"initrd http://{server_ip}/storage/isos/{f['path']}")
            script.append(f"chain http://{server_ip}/tftpboot/memdisk iso raw")

    for f in vhd_files:
        if any(f['name'].endswith(ext) for ext in [".vhd", ".qcow2", ".img"]):
            safe_name = f['path'].lower().replace("/", "-").replace("\\", "-").replace("_", "-").replace(".", "-")
            iqn = f"iqn.2024-01.com.pxeserver:{safe_name}"
            script.append(f":vhd_{hash(f['path'])}")
            script.append(f"sanboot iscsi:{server_ip}::::{iqn}")

    return "\n".join(script)
EOF


# Setup Python Venv and Install
log "Setting up Python environment..."
python3 -m venv "$PROJECT_DIR/brain/venv"
"$PROJECT_DIR/brain/venv/bin/pip" install -r "$PROJECT_DIR/brain/requirements.txt" >> "$LOG_FILE" 2>&1

# Create Systemd Service
log "Creating Systemd Service..."
cat <<EOF > /etc/systemd/system/super-pxe-brain.service
[Unit]
Description=Super PXE Brain Service
After=network.target

[Service]
User=root
WorkingDirectory=$PROJECT_DIR/brain
ExecStart=$PROJECT_DIR/brain/venv/bin/uvicorn brain:app --host 0.0.0.0 --port $BRAIN_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable super-pxe-brain --now

# --- 5. Configure Nginx ---
log "Configuring Nginx..."
cat <<EOF > /etc/nginx/sites-available/super-pxe
server {
    listen 80;
    server_name _;
    
    # Serve Boot Files
    location /tftpboot/ {
        alias $PROJECT_DIR/tftpboot/; 
        autoindex on;
    }

    # Serve Storage (ISOs)
    location /storage/ {
        alias $PROJECT_DIR/storage/; 
        autoindex on;
    }

    # Proxy API requests to Brain
    location / {
        proxy_pass http://127.0.0.1:$BRAIN_PORT;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/super-pxe /etc/nginx/sites-enabled/
systemctl restart nginx

# --- 6. Configure TFTP ---
log "Configuring TFTP..."
cat <<EOF > /etc/default/tftpd-hpa
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="$PROJECT_DIR/tftpboot"
TFTP_ADDRESS=":69"
TFTP_OPTIONS="--secure"
EOF

systemctl restart tftpd-hpa

# --- 7. Configure Bootloaders ---
log "Configuring Bootloaders (Copying from local system)..."
cd "$PROJECT_DIR/tftpboot" || err "Could not access tftpboot dir"

# Shim
if [ -f "/usr/lib/shim/shimx64.efi.signed" ]; then
    cp /usr/lib/shim/shimx64.efi.signed shim.efi
else
    warn "Missing shim-signed package. Secure Boot unavailable."
fi

# iPXE
if [ -f "/usr/lib/ipxe/ipxe.efi" ]; then
    cp /usr/lib/ipxe/ipxe.efi ipxe.efi
    cp /usr/lib/ipxe/undionly.kpxe undionly.kpxe
else
    warn "Missing ipxe package. PXE boot unavailable."
fi

# Memdisk
if [ -f "/usr/lib/syslinux/memdisk" ]; then
    cp /usr/lib/syslinux/memdisk memdisk
else
    warn "Missing syslinux-common package."
    touch memdisk
fi

# Wimboot (Download from GitHub with timeout)
log "Downloading wimboot..."
wget -q --timeout=20 -O wimboot https://github.com/ipxe/wimboot/releases/latest/download/wimboot || warn "Failed to download wimboot."

chmod 755 *

# --- 7. Configure Bootloaders ---
log "Running Verification Tests..."

# Check Ports
netstat -tuln | grep -E ":80|:69|:$BRAIN_PORT" >> "$LOG_FILE"

# Test Brain API
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$BRAIN_PORT/boot.ipxe)
if [ "$HTTP_CODE" -eq 200 ]; then
    log "PASS: Brain Service is replying correctly."
else
    warn "FAIL: Brain Service returned HTTP $HTTP_CODE"
fi

log "Installation Complete! (v1.38)"
log "Use this info for your DHCP Server:"
log "  Next-Server: $SERVER_IP"
log "  Boot Filename: shim.efi (UEFI) or undionly.kpxe (BIOS)"
log "  Admin Console: http://$SERVER_IP/"
log "Full log available at: $LOG_FILE"

exit 0
