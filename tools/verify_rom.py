#!/usr/bin/env python3
"""Sanity-check a LoROM image before hardware tests."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

ROM_SIZE = 524288  # 512 KiB
HEADER = 0x7FC0


def fail(message: str) -> None:
    print(f"verify: FAIL: {message}")
    sys.exit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: verify_rom.py build/daniel.sfc")

    path = Path(sys.argv[1])
    data = path.read_bytes()

    if len(data) != ROM_SIZE:
        fail(f"size is {len(data)}, expected {ROM_SIZE}")

    name = data[0x7FC0:0x7FD5]
    map_mode = data[0x7FD5]
    cart_type = data[0x7FD6]
    rom_size = data[0x7FD7]
    sram_size = data[0x7FD8]
    country = data[0x7FD9]
    checksum = struct.unpack_from("<H", data, 0x7FDE)[0]
    complement = struct.unpack_from("<H", data, 0x7FDC)[0]

    native_nmi = struct.unpack_from("<H", data, 0x7FEA)[0]
    emu_reset = struct.unpack_from("<H", data, 0x7FFC)[0]
    emu_nmi = struct.unpack_from("<H", data, 0x7FFA)[0]

    if map_mode != 0x20:
        fail(f"map mode ${map_mode:02X}, expected $20 (LoROM SlowROM)")
    if cart_type != 0x00:
        fail(f"cartridge type ${cart_type:02X}, expected $00 (ROM only)")
    if rom_size != 0x09:
        fail(f"ROM size byte ${rom_size:02X}, expected $09 (512 KiB)")
    if sram_size != 0x00:
        fail(f"SRAM size ${sram_size:02X}, expected $00")
    if country != 0x01:
        fail(f"country ${country:02X}, expected $01 (NTSC)")
    if (checksum + complement) & 0xFFFF != 0xFFFF:
        fail(f"checksum ${checksum:04X} / complement ${complement:04X} are not inverses")
    if native_nmi == 0x0000:
        fail("native NMI vector is $0000")
    if emu_nmi == 0x0000:
        fail("emulation NMI vector is $0000")
    if emu_reset == 0x0000:
        fail("RESET vector is $0000")
    if emu_reset < 0x8000:
        fail(f"RESET vector ${emu_reset:04X} is not in LoROM ($8000-$FFFF)")

    title = name.decode("ascii", errors="replace").rstrip("\x00 ")
    print(f"verify: OK  {path}")
    print(f"  title     {title!r}")
    print(f"  map       LoROM SlowROM NTSC, ROM only, 512 KiB")
    print(f"  reset     ${emu_reset:04X}")
    print(f"  nmi       native ${native_nmi:04X}  emu ${emu_nmi:04X}")
    print(f"  checksum  ${checksum:04X}")


if __name__ == "__main__":
    main()
