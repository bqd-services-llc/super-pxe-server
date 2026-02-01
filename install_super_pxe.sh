#!/bin/bash

# Super PXE Server - All-in-One Installer & Verifier (v2.0 Next-Gen)
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
log "Starting installation (v2.0 Next-Gen)..."
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
# Ensure new directories for v2.0 (injections, overlays) are created
mkdir -p "$PROJECT_DIR"/{brain/static,config,storage/{isos,vhds,masters,drivers,diskless,injections,overlays},generated_configs,tftpboot}
chmod -R 755 "$PROJECT_DIR"
chown -R nobody:nogroup "$PROJECT_DIR/storage"

# --- 3b. Install Branding ---
# Check standard locations (current dir or assets/ subdir)
if [ -f "super-pxe-server/assets/icon.png" ]; then
    log "Installing Branding Images from assets/..."
    cp super-pxe-server/assets/icon.png "$PROJECT_DIR/brain/static/"
    cp super-pxe-server/assets/banner.png "$PROJECT_DIR/brain/static/" 2>/dev/null || true
elif [ -f "assets/icon.png" ]; then
    log "Installing Branding Images from assets/..."
    cp assets/icon.png "$PROJECT_DIR/brain/static/"
    cp assets/banner.png "$PROJECT_DIR/brain/static/" 2>/dev/null || true
elif [ -f "icon.png" ]; then
    log "Installing Branding Images from current dir..."
    cp icon.png "$PROJECT_DIR/brain/static/"
    cp banner.png "$PROJECT_DIR/brain/static/" 2>/dev/null || true
else
    warn "Branding images not found. Admin UI will lack logos."
fi

# --- 4. Deploy The "Brain" (Python Service) ---
log "Deploying the Brain Service (v2.0)..."

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
    "menu_title": "Super PXE Server (v2.0 Next-Gen)",
    "admin_password": "admin",
    "clients": []
}
EOF
fi

# Write static/index.html (Admin Dashboard - Enhanced)
# We embed the HTML content directly here to make the installer standalone-capable if cat'd
cat <<'HTML_EOF' > "$PROJECT_DIR/brain/static/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Super PXE | Enterprise Dashboard</title>
    <!-- Google Fonts: Montserrat -->
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&display=swap" rel="stylesheet">
    <!-- Bootstrap 5 & Icons -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css">
    <style>
        :root {
            --sidebar-width: 260px;
            --sps-blue: #1E3A8A;
            --sps-silver: #94A3B8;
            --sps-white: #FFFFFF;
            --sps-bolt: #F59E0B;
            --bg: #F8FAFC;
            --text-dark: #1E293B;
        }
        body { background-color: var(--bg); font-family: 'Montserrat', sans-serif; color: var(--text-dark); overflow-x: hidden; }

        /* Sidebar */
        .sidebar { width: var(--sidebar-width); height: 100vh; position: fixed; background: var(--sps-blue); color: var(--sps-white); transition: all 0.3s; z-index: 1000; }
        .sidebar .nav-link { color: rgba(255,255,255,0.7); padding: 12px 20px; border-radius: 0; border-left: 4px solid transparent; font-weight: 600; }
        .sidebar .nav-link:hover, .sidebar .nav-link.active { background: rgba(255,255,255,0.1); color: var(--sps-white); border-left-color: var(--sps-bolt); }
        .sidebar .brand { padding: 25px 20px; font-weight: 700; font-size: 1.3rem; border-bottom: 1px solid rgba(255,255,255,0.1); letter-spacing: 1px; }

        /* Main Content */
        .main-content { margin-left: var(--sidebar-width); padding: 30px; transition: all 0.3s; }

        /* Cards */
        .card { border: 1px solid var(--sps-silver); border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.02); }
        .card-header { background-color: var(--sps-white); border-bottom: 1px solid var(--sps-silver); font-weight: 700; color: var(--sps-blue); }

        .stat-card { background: white; border: 1px solid var(--sps-silver); border-radius: 8px; padding: 20px; display: flex; align-items: center; gap: 15px; }
        .stat-card .icon-box { width: 50px; height: 50px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; background: rgba(30, 58, 138, 0.1); color: var(--sps-blue); }

        .btn-primary { background-color: var(--sps-bolt); border-color: var(--sps-bolt); color: var(--sps-blue); font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }
        .btn-primary:hover { background-color: #D97706; border-color: #D97706; color: var(--sps-blue); }

        .btn-outline-primary { border-color: var(--sps-blue); color: var(--sps-blue); }
        .btn-outline-primary:hover { background-color: var(--sps-blue); color: var(--sps-white); }

        /* Search Bar */
        .search-box { position: relative; }
        .search-box i { position: absolute; left: 15px; top: 12px; color: var(--sps-silver); }
        .search-box input { padding-left: 45px; border-radius: 6px; border: 1px solid var(--sps-silver); }
        .search-box input:focus { border-color: var(--sps-blue); box-shadow: 0 0 0 0.25rem rgba(30, 58, 138, 0.1); }

        .status-online { color: #10B981; }
        .loading-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(255,255,255,0.8); display: none; align-items: center; justify-content: center; z-index: 2000; }

        h2, h3, h5 { font-weight: 700; color: var(--sps-blue); }
        .text-primary { color: var(--sps-blue) !important; }

        .dir-item { cursor: pointer; background-color: #f1f5f9; }
        .dir-item:hover { background-color: #e2e8f0; }
        .breadcrumb-item a { text-decoration: none; color: var(--sps-blue); font-weight: 600; }
    </style>
</head>
<body>

    <div class="loading-overlay" id="global-loader">
        <div class="spinner-border text-primary" role="status"></div>
    </div>

    <!-- Sidebar -->
    <div class="sidebar">
        <div class="brand d-flex align-items-center gap-2">
            <img src="/static/icon.png" width="32" height="32" alt="Logo">
            <span>SUPER PXE</span>
        </div>
        <nav class="nav flex-column mt-3">
            <a class="nav-link active" id="nav-dash" href="#" onclick="showPage('dash')"><i class="bi bi-speedometer2 me-2"></i> Dashboard</a>
            <a class="nav-link" id="nav-storage" href="#" onclick="showPage('storage')"><i class="bi bi-hdd-network me-2"></i> Storage & Assets</a>
            <a class="nav-link" id="nav-clients" href="#" onclick="showPage('clients')"><i class="bi bi-laptop me-2"></i> Clients & Automation</a>
            <a class="nav-link" id="nav-settings" href="#" onclick="showPage('settings')"><i class="bi bi-gear me-2"></i> System Settings</a>
        </nav>
        <div class="mt-auto p-3 text-muted small border-top border-secondary">
            Version v2.0 (Next-Gen)<br>&copy; 2026 BQD Services
        </div>
    </div>

    <!-- Main Content -->
    <div class="main-content">
        
        <!-- Page: Dashboard -->
        <div id="page-dash">
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h2 class="fw-bold">Dashboard</h2>
                <div class="badge bg-success-subtle text-success p-2 rounded-pill px-3 border border-success">
                    <i class="bi bi-check-circle-fill me-1"></i> System Online
                </div>
            </div>

            <div class="row g-4 mb-4">
                <div class="col-md-4">
                    <div class="stat-card">
                        <div class="icon-box bg-primary-subtle text-primary"><i class="bi bi-disc"></i></div>
                        <div>
                            <div class="text-muted small">Total ISOs (Root)</div>
                            <h3 class="fw-bold mb-0" id="stat-isos">0</h3>
                        </div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="stat-card">
                        <div class="icon-box bg-info-subtle text-info"><i class="bi bi-file-earmark-binary"></i></div>
                        <div>
                            <div class="text-muted small">Total VHDs (Root)</div>
                            <h3 class="fw-bold mb-0" id="stat-vhds">0</h3>
                        </div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="stat-card">
                        <div class="icon-box bg-warning-subtle text-warning"><i class="bi bi-cpu"></i></div>
                        <div>
                            <div class="text-muted small">Active Sessions</div>
                            <h3 class="fw-bold mb-0" id="stat-sessions">0</h3>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card mb-4">
                <div class="card-body">
                    <h5 class="card-title fw-bold mb-4">Network Quick Info</h5>
                    <div class="row text-center">
                        <div class="col-6 col-md-3 border-end">
                            <div class="small text-muted">Server IP</div>
                            <div class="fw-bold" id="info-ip">--</div>
                        </div>
                        <div class="col-6 col-md-3 border-end">
                            <div class="small text-muted">DHCP Option 66</div>
                            <div class="fw-bold text-primary" id="info-dhcp">--</div>
                        </div>
                        <div class="col-6 col-md-3 border-end">
                            <div class="small text-muted">UEFI Bootfile</div>
                            <div class="fw-bold">shim.efi</div>
                        </div>
                        <div class="col-6 col-md-3">
                            <div class="small text-muted">Legacy Bootfile</div>
                            <div class="fw-bold">undionly.kpxe</div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-header bg-white">Active Connections (Live)</div>
                <div class="card-body p-0">
                    <table class="table table-hover mb-0">
                        <thead>
                            <tr>
                                <th>Type</th>
                                <th>Client Address / Initiator</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody id="session-list">
                            <tr><td colspan="3" class="text-center text-muted p-4">No active sessions</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- Page: Storage -->
        <div id="page-storage" style="display:none">
            <div class="d-flex justify-content-between align-items-center mb-4">
                <div>
                    <h2 class="fw-bold mb-1">Storage & Assets</h2>
                    <nav aria-label="breadcrumb">
                        <ol class="breadcrumb" id="storage-breadcrumb">
                            <li class="breadcrumb-item"><a href="#" onclick="browse('', 'root')">Root</a></li>
                        </ol>
                    </nav>
                </div>
                <div class="d-flex gap-2">
                    <button class="btn btn-outline-primary" onclick="document.getElementById('injection-upload').click()">
                        <i class="bi bi-upload"></i> Upload Injection
                    </button>
                    <input type="file" id="injection-upload" hidden onchange="uploadInjection(this)">
                    <button class="btn btn-primary" id="refresh-btn" onclick="refreshAssets()">
                        <i class="bi bi-arrow-clockwise"></i> Refresh Library
                    </button>
                </div>
            </div>

            <div class="search-box mb-4">
                <i class="bi bi-search"></i>
                <input type="text" class="form-control" id="asset-search" placeholder="Search in current view..." onkeyup="filterAssets()">
            </div>

            <div class="row g-4">
                <div class="col-md-4">
                    <div class="card h-100">
                        <div class="card-header bg-white fw-bold d-flex justify-content-between align-items-center">
                            <span>OS Installers (ISOs)</span>
                            <span class="badge bg-secondary" id="count-isos">0</span>
                        </div>
                        <div class="card-body p-0">
                            <div class="list-group list-group-flush" id="iso-list" style="max-height: 600px; overflow-y: auto;">
                                <!-- Items -->
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="card h-100">
                        <div class="card-header bg-white fw-bold d-flex justify-content-between align-items-center">
                            <span>Disk Images (VHDs)</span>
                            <span class="badge bg-secondary" id="count-vhds">0</span>
                        </div>
                        <div class="card-body p-0">
                            <div class="list-group list-group-flush" id="vhd-list" style="max-height: 600px; overflow-y: auto;">
                                <!-- Items -->
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-md-4">
                    <div class="card h-100 border-warning">
                        <div class="card-header bg-warning-subtle fw-bold d-flex justify-content-between align-items-center text-warning-emphasis">
                            <span>Injections (Kickstart/Preseed)</span>
                            <span class="badge bg-warning text-dark" id="count-injections">0</span>
                        </div>
                        <div class="card-body p-0">
                            <div class="list-group list-group-flush" id="injection-list" style="max-height: 600px; overflow-y: auto;">
                                <!-- Items -->
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Page: Clients -->
        <div id="page-clients" style="display:none">
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h2 class="fw-bold">Clients & Automation</h2>
                <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addClientModal">
                    <i class="bi bi-plus-lg"></i> Add Client Mapping
                </button>
            </div>

            <div class="card">
                <div class="card-header bg-white">MAC-to-Image Mappings (Auto-Boot)</div>
                <div class="card-body p-0 table-responsive">
                    <table class="table table-hover mb-0 align-middle">
                        <thead class="table-light">
                            <tr>
                                <th>MAC Address</th>
                                <th>Target Image</th>
                                <th>Type</th>
                                <th>Advanced</th>
                                <th class="text-end">Actions</th>
                            </tr>
                        </thead>
                        <tbody id="client-mapping-list">
                            <!-- Items -->
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- Page: Settings -->
        <div id="page-settings" style="display:none">
            <h2 class="fw-bold mb-4">System Settings</h2>
            <div class="card">
                <div class="card-body">
                    <form id="config-form">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <label class="form-label fw-bold">Menu Title</label>
                                <input type="text" class="form-control" id="menu_title" name="menu_title">
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-bold">Boot Menu Timeout (sec)</label>
                                <input type="number" class="form-control" id="boot_timeout" name="boot_timeout">
                            </div>
                            <div class="col-md-12">
                                <label class="form-label fw-bold">Admin Password</label>
                                <input type="password" class="form-control" id="admin_password" name="admin_password" placeholder="Leave blank to keep current">
                            </div>
                            <hr class="my-4">
                            <h5 class="fw-bold"><i class="bi bi-shield-lock me-2"></i>Advanced Networking</h5>
                            <div class="col-md-4">
                                <label class="form-label">Server IP</label>
                                <input type="text" class="form-control" id="server_ip" name="server_ip">
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">DHCP Next-Server</label>
                                <input type="text" class="form-control" id="dhcp_next_server" name="dhcp_next_server">
                            </div>
                            <div class="col-md-4">
                                <label class="form-label">iSCSI Allowed Initiators</label>
                                <input type="text" class="form-control" id="iscsi_allowed_initiators" name="iscsi_allowed_initiators">
                            </div>
                        </div>
                        <div class="mt-4">
                            <button type="submit" class="btn btn-primary px-5">Save Configuration</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>

    </div>

    <!-- Modals -->
    <div class="modal fade" id="addClientModal" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header bg-light">
                    <h5 class="modal-title fw-bold">Add Client Mapping</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <form id="client-form">
                        <div class="row g-3">
                            <div class="col-md-6">
                                <label class="form-label fw-bold">MAC Address</label>
                                <input type="text" class="form-control font-monospace" id="new-client-mac" placeholder="AA:BB:CC:DD:EE:FF" required>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label fw-bold">Hostname (Optional)</label>
                                <input type="text" class="form-control" id="new-client-hostname" placeholder="e.g. workstation-01">
                            </div>
                            
                            <div class="col-md-8">
                                <label class="form-label fw-bold">Target Image Name</label>
                                <input type="text" class="form-control font-monospace" id="new-client-image" placeholder="ubuntu.iso or win10.vhd" required>
                                <div class="form-text">Type exact filename from Storage library.</div>
                            </div>
                            <div class="col-md-4">
                                <label class="form-label fw-bold">Image Type</label>
                                <select class="form-select" id="new-client-type" onchange="toggleClientFields()">
                                    <option value="iso">ISO (Installer)</option>
                                    <option value="vhd">VHD (Disk Image)</option>
                                </select>
                            </div>

                            <!-- VHD Specific -->
                            <div class="col-12" id="field-overlay" style="display:none">
                                <div class="form-check form-switch p-3 border rounded bg-light">
                                    <input class="form-check-input" type="checkbox" id="new-client-overlay">
                                    <label class="form-check-label fw-bold" for="new-client-overlay">Enable Persistent Overlay (Copy-On-Write)</label>
                                    <div class="small text-muted mt-1">
                                        Creates a private QCOW2 difference disk for this client. 
                                        Changes will be saved to the overlay, keeping the Master VHD pristine.
                                    </div>
                                </div>
                            </div>

                            <!-- ISO Specific -->
                            <div class="col-md-6" id="field-injection">
                                <label class="form-label fw-bold">Injection File (Kickstart/Preseed)</label>
                                <select class="form-select" id="new-client-injection">
                                    <option value="">(None)</option>
                                    <!-- Populated via JS -->
                                </select>
                            </div>
                            <div class="col-md-6" id="field-kernel">
                                <label class="form-label fw-bold">Kernel Arguments</label>
                                <input type="text" class="form-control font-monospace" id="new-client-kernel" placeholder="quiet splash">
                            </div>
                        </div>

                        <div class="mt-4 pt-3 border-top text-end">
                            <button type="button" class="btn btn-secondary me-2" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-primary px-4">Add Mapping</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        let currentPath = "";
        let currentType = "root";
        let allAssets = { isos: [], iso_dirs: [], vhds: [], vhd_dirs: [], injections: [] };
        let currentConfig = {};

        function showPage(page) {
            ['dash', 'storage', 'clients', 'settings'].forEach(p => {
                const el = document.getElementById('page-' + p);
                if (el) el.style.display = (p === page) ? 'block' : 'none';
                const nav = document.getElementById('nav-' + p);
                if (nav) nav.classList.toggle('active', p === page);
            });
        }
        
        function toggleClientFields() {
            const type = document.getElementById('new-client-type').value;
            const isVhd = type === 'vhd';
            document.getElementById('field-overlay').style.display = isVhd ? 'block' : 'none';
            document.getElementById('field-injection').style.display = !isVhd ? 'block' : 'none';
            document.getElementById('field-kernel').style.display = !isVhd ? 'block' : 'none';
        }

        async function loadData() {
            try {
                const config = await fetch('/api/config').then(r => r.json());
                currentConfig = config;
                
                document.getElementById('info-ip').innerText = config.server_ip;
                document.getElementById('info-dhcp').innerText = config.dhcp_next_server;

                for (const [key, value] of Object.entries(config)) {
                    const el = document.getElementById(key);
                    if (el && key !== 'admin_password') el.value = value;
                }

                await browse("", "root");
                await loadSessions();
                renderClients();
            } catch (err) {
                console.error('Failed to load data:', err);
            }
        }

        async function loadSessions() {
            try {
                const sessions = await fetch('/api/sessions').then(r => r.json());
                document.getElementById('stat-sessions').innerText = sessions.length;
                const list = document.getElementById('session-list');
                if (sessions.length) {
                    list.innerHTML = sessions.map(s => `
                        <tr>
                            <td><span class="badge bg-info">${s.type.toUpperCase()}</span></td>
                            <td><code>${s.client}</code></td>
                            <td><span class="text-success">Connected</span></td>
                        </tr>
                    `).join('');
                } else {
                    list.innerHTML = '<tr><td colspan="3" class="text-center text-muted p-4">No active sessions</td></tr>';
                }
            } catch (e) {}
        }

        async function browse(path, type) {
            currentPath = path;
            currentType = type;
            try {
                const assets = await fetch(`/api/assets?path=${encodeURIComponent(path)}&type=${type}`).then(r => r.json());
                allAssets = assets;
                const bc = document.getElementById('storage-breadcrumb');
                bc.innerHTML = '<li class="breadcrumb-item"><a href="#" onclick="browse(\'\', \'root\')">Root</a></li>';
                if (path) {
                    const parts = path.split('/');
                    let accumulated = "";
                    parts.forEach((p, i) => {
                        accumulated += (i === 0 ? p : "/" + p);
                        if (i === parts.length - 1) bc.innerHTML += `<li class="breadcrumb-item active">${p}</li>`;
                        else bc.innerHTML += `<li class="breadcrumb-item"><a href="#" onclick="browse('${accumulated}', '${type}')">${p}</a></li>`;
                    });
                }
                if (!path && type === "root") {
                    document.getElementById('stat-isos').innerText = assets.isos.length;
                    document.getElementById('stat-vhds').innerText = assets.vhds.length;
                    document.getElementById('count-injections').innerText = assets.injections ? assets.injections.length : 0;
                }
                renderAssets(assets);
                populateInjectionSelect(assets.injections);
            } catch (err) {}
        }
        
        function populateInjectionSelect(injections) {
            const sel = document.getElementById('new-client-injection');
            if (!injections) return;
            const current = sel.value;
            sel.innerHTML = '<option value="">(None)</option>' + 
                injections.map(f => `<option value="${f.name}">${f.name}</option>`).join('');
            if (current) sel.value = current;
        }

        async function uploadInjection(input) {
            if (!input.files[0]) return;
            const formData = new FormData();
            formData.append("file", input.files[0]);
            
            try {
                const res = await fetch('/api/upload_injection', {
                    method: 'POST',
                    body: formData
                }).then(r => r.json());
                
                if (res.status === 'success') {
                    alert('Injection file uploaded successfully!');
                    refreshAssets();
                } else {
                    alert('Upload failed: ' + res.message);
                }
            } catch(e) { alert('Error uploading file'); }
            input.value = ''; // Reset
        }

        function renderAssets(assets) {
            const isoList = document.getElementById('iso-list');
            const vhdList = document.getElementById('vhd-list');
            const injList = document.getElementById('injection-list');

            let isoHtml = "";
            if (assets.iso_dirs) isoHtml += assets.iso_dirs.map(d => `
                <div class="list-group-item dir-item" onclick="browse('${d.path}', 'iso')">
                    <div class="d-flex align-items-center gap-3"><i class="bi bi-folder-fill text-warning fs-4"></i><div class="fw-bold">${d.name}</div></div>
                </div>`).join('');
            if (assets.isos) isoHtml += assets.isos.map(f => `
                <div class="list-group-item">
                    <div class="d-flex align-items-center gap-3"><i class="bi bi-file-earmark-code text-primary fs-4"></i><div class="text-truncate"><div class="fw-bold text-truncate">${f.name}</div><div class="text-muted small">/storage/isos/${f.path}</div></div></div>
                </div>`).join('');
            isoList.innerHTML = isoHtml || '<div class="p-4 text-center text-muted">Empty</div>';
            document.getElementById('count-isos').innerText = (assets.isos ? assets.isos.length : 0) + (assets.iso_dirs ? assets.iso_dirs.length : 0);

            let vhdHtml = "";
            if (assets.vhd_dirs) vhdHtml += assets.vhd_dirs.map(d => `
                <div class="list-group-item dir-item" onclick="browse('${d.path}', 'vhd')">
                    <div class="d-flex align-items-center gap-3"><i class="bi bi-folder-fill text-warning fs-4"></i><div class="text-truncate"><div class="fw-bold text-truncate">${f.name}</div><div class="text-muted small">${f.path}</div></div></div>
                </div>`).join('');
            if (assets.vhds) vhdHtml += assets.vhds.map(f => `
                <div class="list-group-item">
                    <div class="d-flex align-items-center gap-3"><i class="bi bi-hdd-fill text-info fs-4"></i><div class="text-truncate"><div class="fw-bold text-truncate">${f.name}</div><div class="text-muted small">${f.path}</div></div></div>
                </div>`).join('');
            vhdList.innerHTML = vhdHtml || '<div class="p-4 text-center text-muted">Empty</div>';
            document.getElementById('count-vhds').innerText = (assets.vhds ? assets.vhds.length : 0) + (assets.vhd_dirs ? assets.vhd_dirs.length : 0);
            
            let injHtml = "";
            if (assets.injections) injHtml += assets.injections.map(f => `
                <div class="list-group-item">
                    <div class="d-flex align-items-center gap-3"><i class="bi bi-file-text text-warning fs-4"></i><div class="text-truncate"><div class="fw-bold text-truncate">${f.name}</div></div></div>
                </div>`).join('');
            if (injList) injList.innerHTML = injHtml || '<div class="p-4 text-center text-muted">Empty</div>';
        }

        function renderClients() {
            const list = document.getElementById('client-mapping-list');
            const clients = currentConfig.clients || [];
            if (clients.length) {
                list.innerHTML = clients.map((c, i) => `
                    <tr>
                        <td>
                            <div class="fw-bold font-monospace">${c.mac}</div>
                            ${c.hostname ? `<div class="small text-muted"><i class="bi bi-pc-display me-1"></i>${c.hostname}</div>` : ''}
                        </td>
                        <td class="font-monospace">${c.image}</td>
                        <td><span class="badge bg-secondary">${c.type.toUpperCase()}</span></td>
                        <td>
                            ${c.overlay ? '<span class="badge bg-success"><i class="bi bi-layers-fill me-1"></i>Persistent Overlay</span>' : ''}
                            ${c.injection_file ? '<div class="small text-primary"><i class="bi bi-file-earmark-text me-1"></i>Inj: ' + c.injection_file + '</div>' : ''}
                            ${c.kernel_args ? '<div class="small text-muted text-truncate" style="max-width: 150px;">' + c.kernel_args + '</div>' : ''}
                        </td>
                        <td class="text-end">
                            <button class="btn btn-sm btn-outline-danger" onclick="deleteClient(${i})"><i class="bi bi-trash"></i></button>
                        </td>
                    </tr>
                `).join('');
            } else {
                list.innerHTML = '<tr><td colspan="5" class="text-center text-muted p-4">No client mappings defined</td></tr>';
            }
        }

        async function deleteClient(index) {
            currentConfig.clients.splice(index, 1);
            saveCurrentConfig();
        }

        async function saveCurrentConfig() {
            const loader = document.getElementById('global-loader');
            loader.style.display = 'flex';
            try {
                await fetch('/api/config', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(currentConfig)
                });
                renderClients();
            } finally { loader.style.display = 'none'; }
        }

        document.getElementById('client-form').addEventListener('submit', e => {
            e.preventDefault();
            const mac = document.getElementById('new-client-mac').value;
            const image = document.getElementById('new-client-image').value;
            const type = document.getElementById('new-client-type').value;
            
            const hostname = document.getElementById('new-client-hostname').value;
            const overlay = document.getElementById('new-client-overlay').checked;
            const injection = document.getElementById('new-client-injection').value;
            const kernel = document.getElementById('new-client-kernel').value;

            if (!currentConfig.clients) currentConfig.clients = [];
            
            const clientData = { mac, image, type, hostname };
            if (type === 'vhd') clientData.overlay = overlay;
            if (type === 'iso') {
                if (injection) clientData.injection_file = injection;
                if (kernel) clientData.kernel_args = kernel;
            }
            
            currentConfig.clients.push(clientData);
            saveCurrentConfig();
            bootstrap.Modal.getInstance(document.getElementById('addClientModal')).hide();
            e.target.reset();
            toggleClientFields(); // Reset field visibility
        });

        document.getElementById('config-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(e.target);
            const data = Object.fromEntries(formData.entries());
            Object.assign(currentConfig, data);
            saveCurrentConfig();
            alert('Settings saved!');
        });

        function filterAssets() {
            const term = document.getElementById('asset-search').value.toLowerCase();
            const filtered = {
                isos: allAssets.isos.filter(f => f.name.toLowerCase().includes(term)),
                iso_dirs: allAssets.iso_dirs.filter(d => d.name.toLowerCase().includes(term)),
                vhds: allAssets.vhds.filter(f => f.name.toLowerCase().includes(term)),
                vhd_dirs: allAssets.vhd_dirs.filter(d => d.name.toLowerCase().includes(term)),
                injections: allAssets.injections.filter(f => f.name.toLowerCase().includes(term))
            };
            renderAssets(filtered);
        }

        async function refreshAssets() {
            document.getElementById('global-loader').style.display = 'flex';
            try {
                await fetch('/api/refresh', { method: 'POST' });
                await loadData();
            } finally { document.getElementById('global-loader').style.display = 'none'; }
        }

        loadData();
        setInterval(loadSessions, 10000);
    </script>
</body>
</html>
HTML_EOF

# Write brain.py (Updated for Config & API & Auth & Optimized Scanning)
cat <<'PYTHON_EOF' > "$PROJECT_DIR/brain/brain.py"
"""
Super PXE Server - Brain Service v2.0 (Next-Gen)
Copyright (c) 2026 BQD Services. All Rights Reserved.
"""

import os
import logging
import json
import secrets
import subprocess
import shutil
import uuid
from fastapi import FastAPI, Request, Depends, HTTPException, status, UploadFile, File
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.responses import PlainTextResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from pathlib import Path
from typing import Optional, List, Dict, Any

# --- Configuration & Paths ---
CURRENT_FILE = Path(__file__).resolve()

# Detect Environment (Simplified for deployed env)
if "src/brain" in str(CURRENT_FILE):
    # Local Dev (Unlikely in deployed installer, but kept for safety)
    PROJECT_ROOT = CURRENT_FILE.parent.parent.parent
    RUNTIME_ROOT = PROJECT_ROOT / "runtime"
    CONFIG_FILE = CURRENT_FILE.parent / "config.json"
    STATIC_DIR = CURRENT_FILE.parent / "static"
else:
    # Production / Docker (Standard Path)
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
    "clients": [] 
}

# --- App Setup ---
app = FastAPI()
security = HTTPBasic()
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Brain")

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
        safe_name = vhd['path'].lower().replace("/", "-").replace("\", "-").replace("_", "-").replace(".", "-")
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
    return load_config()

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

def generate_client_boot_script(client: Dict, server_ip: str) -> str:
    script = ["#!ipxe"]
    script.append("set boot_url http://{server_ip}:8000")
    script.append("set client_mac ${net0/mac}") # Use actual MAC
    
    # iSCSI Boot for VHDs
    if client['type'] == 'vhd':
        safe_mac = client['mac'].replace(":", "").lower()
        safe_image = client['image'].lower().replace("/", "-").replace(".", "-")
        iqn = f"iqn.2024-01.com.pxeserver:{safe_mac}:{safe_image}"
        
        if client.get('overlay'):
            # Use the overlay target if enabled
            script.append(f"sanboot iscsi:${{server_ip}}::::{iqn}")
        else:
            # Use the generic VHD target (read-only)
            safe_generic_name = client['image'].lower().replace("/", "-").replace(".", "-")
            generic_iqn = f"iqn.2024-01.com.pxeserver:{safe_generic_name}"
            script.append(f"sanboot iscsi:${{server_ip}}::::{generic_iqn}")
            
    # ISO Boot
    elif client['type'] == 'iso':
        iso_path = f"/storage/isos/{client['image']}"
        script.append(f"initrd {iso_path}")
        script.append("chain http://${server_ip}/tftpboot/memdisk iso raw")
        
        # Add kernel args and injection if specified
        if client.get('kernel_args'):
            script.append(f"kernel http://${{server_ip}}/tftpboot/vmlinuz {client['kernel_args']}") # Assuming vmlinuz is available
        if client.get('injection_file'):
            injection_url = f"http://${{server_ip}}/injections/{client['injection_file']}"
            script.append(f"params += ---url=${{injection_url}}") # Example for some bootloaders
            # Add other injection-related params as needed

    else:
        script.append("# Unknown client type")

    script.append("boot")
    return "\n".join(script)


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
            safe_name = f['path'].lower().replace("/", "-").replace("\", "-").replace("_", "-").replace(".", "-")
            iqn = f"iqn.2024-01.com.pxeserver:{safe_name}"
            script.append(f":vhd_{hash(f['path'])}")
            script.append(f"sanboot iscsi:{server_ip}::::{iqn}")
            
    return "\n".join(script)
PYTHON_EOF


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

    # Serve Injections
    location /injections/ {
        alias $PROJECT_DIR/storage/injections/; 
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

log "Installation Complete! (v2.0 Next-Gen)"
log "License: 60-Day Enterprise Trial Active. Reverts to Community Edition (Free) automatically."
log "Use this info for your DHCP Server:"
log "  Next-Server: $SERVER_IP"
log "  Boot Filename: shim.efi (UEFI) or undionly.kpxe (BIOS)"
log "  Admin Console: http://$SERVER_IP/"
log "Full log available at: $LOG_FILE"

exit 0