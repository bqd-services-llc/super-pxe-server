import os
import logging
import json
import secrets
import subprocess
import shutil
import uuid
import time
import platform
import hashlib
from fastapi import FastAPI, Request, Depends, HTTPException, status, UploadFile, File
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.responses import PlainTextResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
from typing import Optional, List, Dict, Any

# --- Licensing Engine ---

class LicenseManager:
    def __init__(self, config_dir: Path):
        self.config_dir = config_dir
        self.license_file = config_dir / ".license_store"
        self.machine_id = self._get_machine_id()
        self.trial_days = 60
        self.status = self._refresh_status()

    def _get_machine_id(self):
        mid_path = Path("/etc/machine-id")
        if mid_path.exists():
            return mid_path.read_text().strip()
        return platform.node() # Fallback to hostname

    def _refresh_status(self):
        # 1. Check for Enterprise Key (Placeholder logic)
        # In production, this would verify a signed JWT/key
        config = load_config()
        if config.get("license_key") and "SPS-ENT-" in config.get("license_key"):
            # Simple check for demo: key must contain machine_id hash
            expected = hashlib.sha256(self.machine_id.encode()).hexdigest()[:8].upper()
            if expected in config.get("license_key"):
                return {"type": "ENTERPRISE", "message": "Enterprise Subscription Active"}

        # 2. Check/Start Trial
        if not self.license_file.exists():
            start_ts = time.time()
            self._save_store({"start_ts": start_ts, "machine_id": self.machine_id})
        
        store = self._read_store()
        if store.get("machine_id") != self.machine_id:
            return {"type": "EXPIRED", "message": "Hardware ID Mismatch"}

        elapsed = time.time() - store.get("start_ts", 0)
        remaining = self.trial_days - (elapsed / 86400)

        if remaining <= 0:
            return {"type": "EXPIRED", "message": "Trial Expired - Community Edition Limits Applied"}
        
        return {"type": "TRIAL", "days_left": int(remaining), "message": f"Trial Active ({int(remaining)} days left)"}

    def _read_store(self):
        try:
            return json.loads(self.license_file.read_text())
        except: return {}

    def _save_store(self, data):
        self.license_file.write_text(json.dumps(data))

    def is_enterprise(self):
        return self.status["type"] == "ENTERPRISE" or self.status["type"] == "TRIAL"

    def check_feature(self, feature: str, current_count: int = 0):
        """Returns (allowed: bool, error_msg: str)"""
        is_ent = self.is_enterprise()
        
        if feature == "diskless_overlay":
            # Community allows exactly ONE overlay
            if not is_ent and current_count >= 1:
                return False, "Community Edition limited to 1 persistent workstation. Upgrade to Enterprise for unlimited diskless nodes."
        
        if feature == "injection":
            if not is_ent:
                return False, "Automated Injection is an Enterprise-only feature."
                
        return True, ""

# --- Configuration & Paths ---
CURRENT_FILE = Path(__file__).resolve()

# Detect Environment
if "src/brain" in str(CURRENT_FILE):
    PROJECT_ROOT = CURRENT_FILE.parent.parent.parent
    RUNTIME_ROOT = PROJECT_ROOT / "runtime"
    CONFIG_FILE = CURRENT_FILE.parent / "config.json"
    STATIC_DIR = CURRENT_FILE.parent / "static"
else:
    PROJECT_ROOT = Path("/opt/super-pxe-server")
    RUNTIME_ROOT = PROJECT_ROOT
    CONFIG_FILE = PROJECT_ROOT / "brain/config.json"
    STATIC_DIR = PROJECT_ROOT / "brain/static"

STORAGE_ROOT = RUNTIME_ROOT / "storage"
GENERATED_DIR = RUNTIME_ROOT / "generated_configs"
TFTP_ROOT = RUNTIME_ROOT / "tftpboot"

ISO_DIR = STORAGE_ROOT / "isos"
VHD_DIR = STORAGE_ROOT / "vhds"
INJECTION_DIR = STORAGE_ROOT / "injections"
OVERLAY_DIR = STORAGE_ROOT / "overlays"

# Ensure directories exist
for d in [ISO_DIR, VHD_DIR, INJECTION_DIR, OVERLAY_DIR, GENERATED_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# Default Config
DEFAULT_CONFIG = {
    "server_ip": "127.0.0.1",
    "dhcp_next_server": "127.0.0.1",
    "iscsi_allowed_initiators": "ALL",
    "boot_timeout": 10,
    "menu_title": "Super PXE Server (Next-Gen)",
    "admin_password": "admin",
    "license_key": "",
    "clients": [] 
}

# --- App Setup ---
app = FastAPI()
security = HTTPBasic()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Brain")

licenser = LicenseManager(CONFIG_FILE.parent)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
# Serve injections via HTTP
app.mount("/injections", StaticFiles(directory=INJECTION_DIR), name="injections")

# --- Models ---

class ClientModel(BaseModel):
    mac: str
    image: str # Path relative to ISO_DIR or VHD_DIR
    type: str # 'iso' or 'vhd'
    # Advanced Options
    hostname: Optional[str] = None
    overlay: bool = False # For VHD: Use Copy-On-Write overlay?
    injection_file: Optional[str] = None # Filename in INJECTION_DIR
    kernel_args: Optional[str] = None # Extra args for ISO/Linux boot

class ConfigModel(BaseModel):
    server_ip: str
    dhcp_next_server: str
    iscsi_allowed_initiators: str
    boot_timeout: int
    menu_title: str
    admin_password: str
    license_key: Optional[str] = ""
    clients: List[ClientModel]

# --- Helpers ---

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
    if isinstance(config_data.get('clients'), list):
        config_data['clients'] = [c if isinstance(c, dict) else c.dict() for c in config_data['clients']]
    
    # Enforce Limits on Save
    licenser.status = licenser._refresh_status() # Refresh status before check
    overlay_count = 0
    for client in config_data.get('clients', []):
        if client.get('overlay'):
            overlay_count += 1
            allowed, msg = licenser.check_feature("diskless_overlay", overlay_count)
            if not allowed:
                # Force disable overlay for excess clients in Community
                client['overlay'] = False
                logger.warning(f"Feature Limit: {msg}")
        
        if client.get('injection_file'):
            allowed, msg = licenser.check_feature("injection")
            if not allowed:
                client['injection_file'] = None
                logger.warning(f"Feature Limit: {msg}")

    with open(CONFIG_FILE, "w") as f:
        json.dump(config_data, f, indent=4)

def get_current_username(credentials: HTTPBasicCredentials = Depends(security)):
    config = load_config()
    correct_password = config.get("admin_password", "admin")
    if not secrets.compare_digest(credentials.password, correct_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect password",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username

def get_directory_contents(base_dir: Path, sub_path: str = ""):
    target_dir = (base_dir / sub_path).resolve()
    if not str(target_dir).startswith(str(base_dir.resolve())):
        return [], []
    files, dirs = [], []
    if not target_dir.exists():
        return files, dirs
    try:
        with os.scandir(target_dir) as it:
            for entry in it:
                rel_entry_path = os.path.join(sub_path, entry.name)
                if entry.is_dir(follow_symlinks=True):
                    dirs.append({"name": entry.name, "path": rel_entry_path})
                elif entry.is_file(follow_symlinks=True):
                    files.append({
                        "name": entry.name,
                        "path": rel_entry_path,
                        "size": entry.stat().st_size,
                        "label": Path(entry.name).stem
                    })
    except Exception as e:
        logger.error(f"Error scanning {target_dir}: {e}")
    files.sort(key=lambda x: x["name"].lower())
    dirs.sort(key=lambda x: x["name"].lower())
    return files, dirs

# --- Advanced Diskless Logic ---

def ensure_overlay(master_vhd_path: str, client_mac: str) -> str:
    """
    Creates a QCOW2 overlay for the given master VHD specific to the client.
    Returns the absolute path to the overlay file.
    """
    clean_mac = client_mac.replace(":", "").lower()
    master_full = (VHD_DIR / master_vhd_path).resolve()
    overlay_name = f"{clean_mac}_{Path(master_vhd_path).name}.qcow2"
    overlay_path = OVERLAY_DIR / overlay_name
    
    if not overlay_path.exists():
        logger.info(f"Creating overlay for {client_mac} on {master_vhd_path}")
        try:
            # qemu-img create -f qcow2 -b <backing_file> <overlay_file>
            subprocess.run(
                ["qemu-img", "create", "-f", "qcow2", "-F", "raw", "-b", str(master_full), str(overlay_path)],
                check=True, stdout=subprocess.DEVNULL
            )
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to create overlay: {e}")
            return str(master_full) # Fallback to master if fail
            
    return str(overlay_path)

def generate_iscsi_config_full(vhds: List[Dict], clients: List[Dict], allowed_initiators="ALL"):
    """
    Generates TGTD config for:
    1. Generic Read-Only masters (for guests/installers)
    2. Client-specific Writeable Overlays
    """
    config_lines = []
    
    # 1. Generic Masters (Read-Only recommended, but currently R/W in legacy)
    # We will make them Read-Only by default if accessed generically to prevent corruption
    for vhd in vhds:
        safe_name = vhd['path'].lower().replace("/", "-").replace("\\", "-").replace("_", "-").replace(".", "-")
        iqn = f"iqn.2024-01.com.pxeserver:{safe_name}"
        config_lines.append(f"<target {iqn}>")
        config_lines.append(f"    backing-store {vhd['full_path']}")
        config_lines.append(f"    initiator-address {allowed_initiators}")
        # config_lines.append("    readonly 1") # Uncomment to enforce safety for generic
        config_lines.append("</target>")

    # 2. Client Overlays
    for client in clients:
        if client.get('type') == 'vhd' and client.get('overlay'):
            overlay_path = ensure_overlay(client['image'], client['mac'])
            safe_mac = client['mac'].replace(":", "").lower()
            safe_image = client['image'].lower().replace("/", "-").replace(".", "-")
            iqn = f"iqn.2024-01.com.pxeserver:{safe_mac}:{safe_image}"
            
            config_lines.append(f"<target {iqn}>")
            config_lines.append(f"    backing-store {overlay_path}")
            config_lines.append(f"    initiator-address {allowed_initiators}") # Could restrict to client IP if known
            config_lines.append("</target>")

    config_path = GENERATED_DIR / "targets.conf"
    try:
        with open(config_path, "w") as f:
            f.write("\n".join(config_lines))
        # Reload TGTD (Optional: might disrupt. Ideally use tgt-admin --update) 
        # subprocess.run(["tgt-admin", "--update", "ALL"], check=False) 
    except Exception as e:
        logger.error(f"Failed to write iSCSI config: {e}")

# --- Caching ---
ISO_CACHE, VHD_CACHE = [], []

def refresh_root_caches():
    global ISO_CACHE, VHD_CACHE
    isos, _ = get_directory_contents(ISO_DIR)
    ISO_CACHE = [f for f in isos if f['name'].endswith('.iso')]
    vhds, _ = get_directory_contents(VHD_DIR)
    VHD_CACHE = [f for f in vhds if any(f['name'].endswith(ext) for ext in [".vhd", ".qcow2", ".img"])]
    
    # Trigger iSCSI config update based on current config + new files
    config = load_config()
    # Need to augment VHD_CACHE with full paths for generator
    vhd_list = []
    for f in VHD_CACHE:
         vhd_list.append({
             "path": f['path'],
             "full_path": str((VHD_DIR / f['path']).absolute())
         })
    generate_iscsi_config_full(vhd_list, config.get('clients', []), config.get("iscsi_allowed_initiators", "ALL"))

@app.on_event("startup")
async def startup_event():
    refresh_root_caches()

# --- API Endpoints ---

@app.get("/")
async def read_root(username: str = Depends(get_current_username)):
    return FileResponse(STATIC_DIR / "index.html")

@app.get("/api/config")
async def get_config(username: str = Depends(get_current_username)):
    config = load_config()
    licenser.status = licenser._refresh_status()
    config["license_status"] = licenser.status
    config["hardware_id"] = licenser.machine_id
    return config

@app.post("/api/config")
async def update_config(config: ConfigModel, username: str = Depends(get_current_username)):
    save_config(config.dict())
    refresh_root_caches() # Re-generate iSCSI targets
    return {"status": "success", "config": config}

@app.get("/api/assets")
async def get_assets(username: str = Depends(get_current_username), path: str = "", type: str = "root"):
    iso_files, iso_dirs = [], []
    vhd_files, vhd_dirs = [], []
    if type == "root" or type == "iso":
        iso_files, iso_dirs = get_directory_contents(ISO_DIR, path)
    if type == "root" or type == "vhd":
        vhd_files, vhd_dirs = get_directory_contents(VHD_DIR, path)
    
    injections, _ = get_directory_contents(INJECTION_DIR)
    
    return {
        "isos": iso_files, "iso_dirs": iso_dirs,
        "vhds": vhd_files, "vhd_dirs": vhd_dirs,
        "injections": injections,
        "current_path": path
    }

@app.post("/api/upload_injection")
async def upload_injection(file: UploadFile = File(...), username: str = Depends(get_current_username)):
    file_path = INJECTION_DIR / file.filename
    try:
        with open(file_path, "wb") as f:
            shutil.copyfileobj(file.file, f)
    except Exception as e:
        return {"status": "error", "message": str(e)}
    return {"status": "success", "filename": file.filename}

# --- Boot Logic (Next-Gen) ---

@app.get("/boot.ipxe", response_class=PlainTextResponse)
async def get_menu(request: Request, path: str = "", type: str = "root", mac: Optional[str] = None):
    config = load_config()
    server_ip = config.get("server_ip", "127.0.0.1")
    timeout = config.get("boot_timeout", 10) * 1000 
    title = config.get("menu_title", "Super PXE Server")

    # 1. Client-Specific Auto-Boot
    if mac:
        mac_norm = mac.lower().replace("-", ":")
        for client in config.get("clients", []):
            if client['mac'].lower() == mac_norm:
                return generate_client_boot_script(client, server_ip)

    # 2. Standard Menu
    script = ["#!ipxe", f"set timeout {timeout}", f"menu {title} - {path if path else 'Root'}"]
    if path:
        script.append(f"item --key 0 back .. Back to Previous")

    iso_files, iso_dirs = [], []
    vhd_files, vhd_dirs = [], []
    
    if type == "root" or type == "iso":
        iso_files, iso_dirs = get_directory_contents(ISO_DIR, path)
    if type == "root" or type == "vhd":
        vhd_files, vhd_dirs = get_directory_contents(VHD_DIR, path)

    # Directories
    if iso_dirs or vhd_dirs:
        script.append("item --gap -- Directories")
        for d in iso_dirs: script.append(f"item dir_iso_{hash(d['path'])} [DIR] {d['name']}")
        for d in vhd_dirs: script.append(f"item dir_vhd_{hash(d['path'])} [DIR] {d['name']}")

    # Files
    if iso_files:
        script.append("item --gap -- ISO Images")
        for f in iso_files:
            if f['name'].endswith(".iso"): script.append(f"item iso_{hash(f['path'])} {f['name']}")

    if vhd_files:
        script.append("item --gap -- VHD Images")
        for f in vhd_files:
            if any(f['name'].endswith(ext) for ext in [".vhd", ".qcow2", ".img"]):
                script.append(f"item vhd_{hash(f['path'])} {f['name']}")

    script.append("choose target && goto ${target}")

    # Menu Handlers
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

def generate_client_boot_script(client: Dict, server_ip: str) -> str:
    script = ["#!ipxe", f"echo Auto-booting client {client['mac']}..."]
    
    if client['type'] == 'iso':
        # Advanced ISO Injection Logic
        script.append(f"echo Loading ISO: {client['image']}")
        script.append(f"initrd http://{server_ip}/storage/isos/{client['image']}")
        
        # Inject Kernel Args if present
        kernel_args = client.get('kernel_args', '')
        
        # Inject Injection File if present (append to kernel args or as initrd?)
        # For simplicity, we assume standard 'inst.ks' or 'autoinstall' patterns for now.
        if client.get('injection_file'):
            injection_url = f"http://{server_ip}/injections/{client['injection_file']}"
            script.append(f"echo Injections: {client['injection_file']}")
            # Heuristic: If it looks like a kickstart, append inst.ks
            if client['injection_file'].endswith(".cfg") or client['injection_file'].endswith(".ks"):
                kernel_args += f" inst.ks={injection_url}"
            # Heuristic: If it looks like user-data, append ds=nocloud-net...
            elif "user-data" in client['injection_file']:
                 kernel_args += f" ds=nocloud-net;s={injection_url.replace('user-data', '')}"

        if kernel_args:
             script.append(f"imgargs memdisk iso raw {kernel_args}")
        
        script.append(f"chain http://{server_ip}/tftpboot/memdisk iso raw")

    elif client['type'] == 'vhd':
        safe_name = client['image'].lower().replace("/", "-").replace("\\", "-").replace("_", "-").replace(".", "-")
        
        if client.get('overlay'):
            # Use the specific client target
            safe_mac = client['mac'].replace(":", "").lower()
            safe_image = client['image'].lower().replace("/", "-").replace(".", "-")
            iqn = f"iqn.2024-01.com.pxeserver:{safe_mac}:{safe_image}"
            script.append(f"echo Booting with Persistent Overlay...")
        else:
            # Use the generic target
            iqn = f"iqn.2024-01.com.pxeserver:{safe_name}"
            
        script.append(f"sanboot iscsi:{server_ip}::::{iqn}")
        
    return "\n".join(script)