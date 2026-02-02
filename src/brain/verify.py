from brain import scan_isos, scan_vhds, generate_iscsi_config
print("Running Python Logic Check...")
isos = scan_isos()
vhds = scan_vhds()
print(f"Found ISOs: {len(isos)}")
print(f"Found VHDs: {len(vhds)}")
generate_iscsi_config(vhds)
import os
if os.path.exists("../generated_configs/targets.conf"):
    print("SUCCESS: Target Config Generated.")
else:
    print("FAIL: Config missing.")
