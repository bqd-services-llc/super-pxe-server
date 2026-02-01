#!/bin/bash
set -e

echo "--- Super PXE Docker Starting ---"

# 1. IP Detection
# In Docker, hostname -I often gives the internal container IP. 
# Users should override SERVER_IP env var if they want a specific announcement.
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
fi
echo "Using Server IP: $SERVER_IP"

# Update config.json
CONFIG_FILE="/opt/super-pxe-server/deploy/brain/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating default config..."
    cat <<EOF > "$CONFIG_FILE"
{
    "server_ip": "$SERVER_IP",
    "dhcp_next_server": "$SERVER_IP",
    "iscsi_allowed_initiators": "ALL",
    "boot_timeout": 10,
    "menu_title": "Super PXE Docker"
}
EOF
else
    # Update IP in existing config if it was default
    sed -i "s/127.0.0.1/$SERVER_IP/g" "$CONFIG_FILE"
fi

# 2. Permissions
# Ensure storage is writable (important if volume mounted)
chown -R nobody:nogroup /opt/super-pxe-server/deploy/storage
chmod -R 777 /opt/super-pxe-server/deploy/storage

# 3. Start Supervisor (manages all processes)
exec /usr/bin/supervisord
