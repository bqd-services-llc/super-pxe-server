# Beta Acquisition Strategy

This document outlines the tactical plan for locating and recruiting high-quality beta testers.

## 1. The "Homelab" Core (High Volume)
**Target Profile:** Enthusiasts with spare hardware and patience for alpha software.
*   **Where:** 
    *   Reddit: **r/homelab**
    *   Reddit: **r/selfhosted**
*   **Tactics:**
    *   **Flair:** Use "Project/Tool" or "Showoff".
    *   **Headline:** Use Option 2 from `BETA_LAUNCH_POST.md`: *"I built a 'Drop-and-Boot' PXE server because I hate configuring TFTP..."*
    *   **Timing:** Post **Tuesday or Wednesday at 8:00 AM EST** (Hits US morning & EU afternoon).
    *   **Engagement:** Reply immediately. Pivot questions into test requests: *"Does it support UEFI?" -> "It should! Would you be willing to test it on your hardware?"*

## 2. The "Hardware Enthusiasts" (High Technical Skill)
**Target Profile:** Users with complex networks (VLANs, 10GbE) who will find edge-case networking bugs.
*   **Where:**
    *   **ServeTheHome Forums** (Networking / DIY Server section)
    *   **Level1Techs Forum**
*   **Tactics:**
    *   **Tone:** Highly technical. Focus on the **iSCSI** and **Copy-on-Write** architecture.
    *   **The Hook:** "Replacing USB installs with 10GbE network booting. Automating the backend with Python. Needs testing on Realtek vs Intel NICs."

## 3. The "Pro" Audience (Viral Potential)
**Target Profile:** Developers and Sysadmins who will critique code and security.
*   **Where:** **Hacker News (news.ycombinator.com)**
*   **Tactics:**
    *   **Title Format:** MUST be **"Show HN: Super PXE Server - Open source, zero-config network booting"**.
    *   **Expectation:** Be ready for 100+ installs in an hour if it hits the front page. Prioritize `collect_debug_logs.sh` usage.

## 4. Direct Outreach (Influencers)
**Target Profile:** "Tutorial" creators looking for content.
*   **Where:** YouTube channels (10k-50k subs), Linux blogs.
*   **Pitch:** 
    > "Hi [Name], I built a tool that sets up a full PXE server in 2 minutes. It might make a good 'Quick Project' video for your channel. I'm looking for beta feedback before v1.0."

## 5. Discord Communities
**Target Profile:** Real-time feedback and troubleshooting.
*   **Where:** TechnoTim, NetworkChuck, Homelab Discords.
*   **Tactics:**
    *   Post in `#self-promotion` or `#projects`.
    *   **Ask for Help:** Don't just advertise. *"Looking for someone with an MSI Z690 motherboard to test a Secure Boot shim bug. Anyone available?"*

---

## Execution Checklist

1.  [ ] **Tuesday 8:00 AM:** Post to **r/homelab**.
2.  [ ] **Tuesday 8:15 AM:** Post "Show HN" to **Hacker News**.
3.  [ ] **Wednesday:** Post technical deep-dive on **ServeTheHome**.
4.  [ ] **Daily:** Monitor GitHub Issues. Reply to every bug report asking for:
    ```bash
    wget https://your-repo/beta_program/tools/collect_debug_logs.sh && sudo ./collect_debug_logs.sh
    ```
