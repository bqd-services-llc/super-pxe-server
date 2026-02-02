# Release Archive

This directory contains the build artifacts for Super PXE Server.

## Structure

*   **v2.0.0/** - Latest Stable (Next-Gen Architecture, Diskless COW, Injection Support)
*   **v1.3/** - Legacy Stable (Critical: Replaced Network Downloads with Local Packages)
*   **v1.25/** - Old Stable (Security & Installer Fixes)
*   **v1.2/** - Beta Release (Initial Public Beta)
*   **v1.0/** - Legacy Tarballs (Pre-Debian Packaging)

## Usage

To install a specific version, navigate to the folder and run:
```bash
sudo dpkg -i super-pxe-server_*.deb
```

## License

**Proprietary / Freemium**

**Super PXE Server** is proprietary software developed by **BQD Services**.

*   **Community Use:** Free for personal and limited commercial use (subject to Community Edition feature limits).
*   **Enterprise Use:** Requires a paid subscription for full feature access beyond the trial period.
*   **Redistribution:** You may not redistribute modified versions of this software without express written permission.

The core orchestration logic ("The Brain"), installer script, and architectural designs are the intellectual property of **BQD Services**.
