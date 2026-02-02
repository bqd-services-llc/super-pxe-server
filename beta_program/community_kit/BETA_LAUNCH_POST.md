# Beta Launch Announcement Template

**Headline Options:**
1.  *Strict/Sysadmin:* "Super PXE: An open-source, zero-config network boot appliance (Alternative to iVentoy/Netboot.xyz)"
2.  *Casual/Homelab:* "I built a 'Drop-and-Boot' PXE server because I hate configuring TFTP. Looking for beta testers!"
3.  *Feature-Focused:* "Boot Windows 11 and Ubuntu over the network without configuring DHCP options manually."

---

## Post Body (Reddit / Hacker News)

**[PROJECT NAME]** is a new automated network boot appliance designed to make PXE booting as easy as copying files to a USB drive.

**The Problem:**
Setting up a PXE server usually involves editing `dhcpd.conf`, messing with TFTP paths, chaining bootloaders (Legacy vs UEFI), and manually extracting kernel files. It's fragile and annoying to maintain.

**The Solution:**
I've built a Python-based orchestration engine ("The Brain") that watches a folder.
*   Drop an ISO? **It boots.** (Ubuntu, Debian, Fedora)
*   Drop a VHD? **It mounts it as an iSCSI target.** (Diskless Windows/Linux)
*   **Secure Boot?** Handled automatically via a signed shim.

**Key Features in Beta v1.0:**
*   ✅ **Native Windows Boot:** Uses `wimboot` for fast HTTP transfer (not slow TFTP).
*   ✅ **Per-Client Persistence:** Boot a single "Master" diskless image on 50 PCs; each PC gets its own Copy-on-Write overlay.
*   ✅ **Zero Config:** No editing config files. Just drag-and-drop.

**What I need from you:**
I'm looking for 10-20 testers to try this on different hardware (Intel NUCs, Dell Optiplex, custom builds).
1.  Install the server (Ubuntu 22.04 required).
2.  Try to boot a Windows or Linux ISO.
3.  Run the included `./tools/collect_debug_logs.sh` if it breaks.

**Link to Repo:** [INSERT LINK HERE]
**Documentation:** [INSERT DOCS LINK]

Thanks for checking it out! I'll be hanging out in the comments to answer questions about the iSCSI implementation.

---

## Discord / Chat Blast (Short Form)

**Looking for Beta Testers: Super PXE Server**
Hey everyone, I'm working on a new PXE appliance that automates network booting (similar to iVentoy but designed for permanent setups). It handles Secure Boot and iSCSI targets automatically.

If you have an Ubuntu VM and a spare laptop to network boot, I'd love your feedback!
**Repo:** [LINK]
