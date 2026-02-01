FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    tftpd-hpa \
    tgt \
    python3 \
    python3-pip \
    python3-venv \
    qemu-utils \
    wget \
    curl \
    supervisor \
    net-tools \
    iproute2 \
    kmod \
    && rm -rf /var/lib/apt/lists/*

# 2. Setup Project Structure
WORKDIR /opt/super-pxe-server
COPY runtime/ ./
COPY src/brain/ ./brain/
# icon.png and banner.png are now inside src/brain/static/

# 3. Setup Python Environment
RUN python3 -m venv ./brain/venv && \
    ./brain/venv/bin/pip install fastapi uvicorn jinja2 python-multipart requests

# 4. Configure Services
# Nginx
COPY packaging/server/etc/nginx/sites-available/super-pxe /etc/nginx/sites-available/default
# TFTP
COPY packaging/server/etc/default/tftpd-hpa /etc/default/tftpd-hpa

# 5. Bootloaders (Download during build to save startup time)
WORKDIR /opt/super-pxe-server/tftpboot
RUN wget -q -O shim.efi http://archive.ubuntu.com/ubuntu/dists/jammy/main/uefi/shim-signed/current/shimx64.efi.signed && \
    wget -q -O ipxe.efi http://boot.ipxe.org/ipxe.efi && \
    wget -q -O undionly.kpxe http://boot.ipxe.org/undionly.kpxe && \
    wget -q -O wimboot https://github.com/ipxe/wimboot/releases/latest/download/wimboot && \
    touch memdisk

# 6. Copy Docker Specific Configs
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 7. Ports
# 80 (HTTP), 69/udp (TFTP), 3260 (iSCSI), 8000 (Admin)
EXPOSE 80 69/udp 3260 8000

# 8. Entrypoint
ENTRYPOINT ["/entrypoint.sh"]

