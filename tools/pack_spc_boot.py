#!/usr/bin/env python3
"""Cut the linked SPC image down to the bytes that belong at ARAM $0200.

wlalink -b emits from the first used address, so file offset 0 is already
ARAM $0200 (the driver). Do not skip 0x200 or the CPU uploads garbage.
"""
from pathlib import Path
import sys

raw_path = Path(sys.argv[1] if len(sys.argv) > 1 else "build/spc_raw.bin")
out_bin = Path(sys.argv[2] if len(sys.argv) > 2 else "src/gen/spc_boot.bin")
out_inc = Path(sys.argv[3] if len(sys.argv) > 3 else "src/gen/spc_size.inc")
data = raw_path.read_bytes()
if len(data) < 16:
    raise SystemExit(f"spc image too small: {len(data)}")
end = len(data)
while end > 16 and data[end - 1] in (0x00,):
    end -= 1
blob = data[:end]
# Driver starts CLRP / MOV X,#$EF (or MOV X,#$EF if CLRP is omitted).
if blob[:3] != bytes((0x20, 0xCD, 0xEF)) and blob[:2] != bytes((0xCD, 0xEF)):
    raise SystemExit(f"spc_boot does not start with driver (got {blob[:8].hex()})")
out_bin.write_bytes(blob)
out_inc.write_text(f".DEFINE SPC_BOOT_SIZE {len(blob)}\n")
print(f"spc_boot {len(blob)} bytes (ARAM $0200-${0x200+end:04X})")
if len(blob) > 32768:
    raise SystemExit("spc_boot exceeds 32 KiB LoROM bank")
