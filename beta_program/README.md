# Beta Program Operations

This directory contains all tools and documents required to manage the Beta Phase.
**These files are isolated from the core application logic.**

## 1. Acquisition (Locating Testers)
*   **`community_kit/BETA_LAUNCH_POST.md`**: A pre-written announcement tailored for r/homelab, Hacker News, and Discord. It focuses on the "Zero Config" value proposition to attract technical users.

## 2. Evaluation (Assessing Results)
*   **`tools/collect_debug_logs.sh`**: A safe script for testers to run. It gathers:
    *   Network Configs (IP/Routes)
    *   Service Logs (Brain/iSCSI)
    *   Directory Listings
    *   *Excludes sensitive data (ISOs/Keys).*
*   **`community_kit/FEEDBACK_TEMPLATE.md`**: A structured form for testers to report bugs (ISO boot success/fail, hardware details).

## Usage
**To collect logs from a tester:**
Ask them to run:
```bash
wget https://your-repo/beta_program/tools/collect_debug_logs.sh
chmod +x collect_debug_logs.sh
sudo ./collect_debug_logs.sh
```
