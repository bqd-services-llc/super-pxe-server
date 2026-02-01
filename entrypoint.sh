#!/bin/bash

# 1. Start TFTP Service (Background)
service tftpd-hpa start

# 2. Start Nginx (Background)
service nginx start

# 3. Start the Brain (Foreground - keeps container alive)
# We use exec so it receives shutdown signals correctly
echo "Starting Super PXE Brain..."
cd /opt/super-pxe-server/brain
exec python3 -m uvicorn brain:app --host 0.0.0.0 --port 8000