#!/bin/bash

# Super PXE Server - Beta Debug Collector
# This script collects non-sensitive configuration and logs to help developers debug boot issues.

OUTPUT_DIR="/tmp/super-pxe-debug-$(date +%s)"
ARCHIVE_NAME="super-pxe-debug-report.tar.gz"
PROJECT_ROOT="/opt/super-pxe-server" # Standard install location

echo "---------------------------------------------------------"
echo "   Super PXE Server - Beta Debug Collector"
echo "---------------------------------------------------------"
echo "This script will collect:"
echo "1. Network Configuration (IPs, Routes)"
echo "2. Service Logs (Brain, Nginx, TGTD)"
echo "3. Directory Structure (List of ISOs/VHDs)"
echo "4. Generated Configs (iSCSI targets, iPXE menus)"
echo ""
echo "It will NOT collect: ISO files, VHD disk images, or SSH keys."
echo "---------------------------------------------------------"

mkdir -p "$OUTPUT_DIR"

# 1. System Info
echo "Collecting System Info..."
echo "--- OS Release ---" > "$OUTPUT_DIR/system_info.txt"
cat /etc/os-release >> "$OUTPUT_DIR/system_info.txt"
echo -e "\n--- Memory ---" >> "$OUTPUT_DIR/system_info.txt"
free -h >> "$OUTPUT_DIR/system_info.txt"
echo -e "\n--- Disk Space ---" >> "$OUTPUT_DIR/system_info.txt"
df -h >> "$OUTPUT_DIR/system_info.txt"
echo -e "\n--- IP Address ---" >> "$OUTPUT_DIR/system_info.txt"
ip addr >> "$OUTPUT_DIR/system_info.txt"
echo -e "\n--- Routing ---" >> "$OUTPUT_DIR/system_info.txt"
ip route >> "$OUTPUT_DIR/system_info.txt"
echo -e "\n--- Ports Listening ---" >> "$OUTPUT_DIR/system_info.txt"
ss -tulpn | grep -E '80|69|3260' >> "$OUTPUT_DIR/system_info.txt"

# 2. Service Logs (Last 500 lines)
echo "Collecting Logs..."
if systemctl list-units --full -all | grep -q "super-pxe-brain.service"; then
    journalctl -u super-pxe-brain -n 500 > "$OUTPUT_DIR/brain_service.log"
else
    echo "Brain service not found!" > "$OUTPUT_DIR/brain_service.log"
fi

# 3. Project Configs (If they exist in current dir or opt)
# Check standard install path first, then current dir
if [ -d "$PROJECT_ROOT" ]; then
    SEARCH_ROOT="$PROJECT_ROOT"
else
    SEARCH_ROOT="$(pwd)"
fi

echo "Collecting Configs from $SEARCH_ROOT..."
mkdir -p "$OUTPUT_DIR/configs"

# Copy generated configs (menu.ipxe, targets.conf)
if [ -d "$SEARCH_ROOT/deploy/generated_configs" ]; then
    cp -r "$SEARCH_ROOT/deploy/generated_configs" "$OUTPUT_DIR/configs/"
fi

# List storage contents (Recursive ls, not the files themselves)
echo "Listing Storage Directory..."
if [ -d "$SEARCH_ROOT/deploy/storage" ]; then
    ls -R "$SEARCH_ROOT/deploy/storage" > "$OUTPUT_DIR/storage_listing.txt"
fi

# 4. Check Dependencies
echo "Checking Dependencies..."
echo "--- Syslinux/Memdisk ---" > "$OUTPUT_DIR/dependencies.txt"
if [ -f "/usr/lib/syslinux/memdisk" ]; then echo "Found"; else echo "Missing"; fi >> "$OUTPUT_DIR/dependencies.txt"
echo "--- Wimtools ---" >> "$OUTPUT_DIR/dependencies.txt"
which wimlib-imagex >> "$OUTPUT_DIR/dependencies.txt" 2>&1

# Compress
echo "Compressing report..."
tar -czf "$ARCHIVE_NAME" -C "/tmp" "$(basename "$OUTPUT_DIR")"

echo ""
echo "SUCCESS! Report generated at: $(pwd)/$ARCHIVE_NAME"
echo "Please submit this file along with your feedback."
rm -rf "$OUTPUT_DIR"
