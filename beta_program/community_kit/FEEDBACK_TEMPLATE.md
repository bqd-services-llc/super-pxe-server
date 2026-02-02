# Beta Tester Feedback Form

Please copy and paste this into a **GitHub Issue** or email it to the maintainer.

## 1. Environment Basics
*   **Server OS:** (e.g., Ubuntu 22.04 VM, Raspberry Pi 4, Bare Metal)
*   **Client Hardware:** (e.g., Dell Optiplex 7050, Custom PC with Realtek NIC)
*   **Network Setup:** (e.g., Unifi Switch, Home Router, Enterprise VLANs)

## 2. Test Results

### ISO Booting
*   **Did the iPXE Menu appear?** [Yes/No]
*   **Which ISO did you try?** (e.g., ubuntu-22.04.iso)
*   **Did it boot successfully?** [Yes/No]
*   **Notes:** (Any errors observed?)

### Diskless Boot (VHD) - *Optional*
*   **Did you try booting a VHD?** [Yes/No]
*   **OS in VHD:** (e.g., Windows 10)
*   **Result:** (e.g., BSOD, Hang, Success)

## 3. General Feedback
*   **Installation Experience:** (Was the `install_super_pxe.sh` script easy to use?)
*   **Bugs Encountered:**
*   **Feature Requests:**

---

## 4. Debug Logs
Please run the following command on your server and attach the resulting file:

```bash
sudo ./tools/collect_debug_logs.sh
```

**[Attach super-pxe-debug-report.tar.gz here]**
