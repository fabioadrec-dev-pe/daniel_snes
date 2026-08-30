#!/usr/bin/env python3
"""Headless SNES9x/libretro probe: title frame, then Start, then play frame."""

from __future__ import annotations

import ctypes
import sys
from pathlib import Path

from PIL import Image

CORE = "/usr/lib/x86_64-linux-gnu/libretro/snes9x_libretro.so"
RETRO_ENVIRONMENT_SET_PIXEL_FORMAT = 10
RETRO_ENVIRONMENT_GET_CAN_DUPE = 3
RETRO_PIXEL_FORMAT_RGB565 = 0
RETRO_PIXEL_FORMAT_XRGB8888 = 1
RETRO_MEMORY_SYSTEM_RAM = 2
JOY_START = 3


class GameInfo(ctypes.Structure):
    _fields_ = [
        ("path", ctypes.c_char_p),
        ("data", ctypes.c_void_p),
        ("size", ctypes.c_size_t),
        ("meta", ctypes.c_char_p),
    ]


pixfmt = RETRO_PIXEL_FORMAT_RGB565
frame = {"raw": b"", "w": 0, "h": 0, "pitch": 0}
want_start = False
KEEP = []


def keep(cb):
    KEEP.append(cb)
    return cb


@keep
@ctypes.CFUNCTYPE(ctypes.c_bool, ctypes.c_uint, ctypes.c_void_p)
def environment(cmd, data):
    global pixfmt
    if cmd == RETRO_ENVIRONMENT_SET_PIXEL_FORMAT and data:
        pixfmt = ctypes.cast(data, ctypes.POINTER(ctypes.c_int)).contents.value
        return True
    if cmd == RETRO_ENVIRONMENT_GET_CAN_DUPE and data:
        ctypes.cast(data, ctypes.POINTER(ctypes.c_bool)).contents.value = True
        return True
    return False


@keep
@ctypes.CFUNCTYPE(None, ctypes.c_void_p, ctypes.c_uint, ctypes.c_uint, ctypes.c_size_t)
def video_refresh(data, width, height, pitch):
    if not data or width == 0:
        return
    frame["raw"] = ctypes.string_at(data, pitch * height)
    frame["w"] = width
    frame["h"] = height
    frame["pitch"] = pitch


@keep
@ctypes.CFUNCTYPE(None)
def input_poll():
    return


@keep
@ctypes.CFUNCTYPE(ctypes.c_int16, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
def input_state(port, device, index, joyid):
    if port == 0 and joyid == JOY_START and want_start:
        return 1
    return 0


@keep
@ctypes.CFUNCTYPE(None, ctypes.c_int16, ctypes.c_int16)
def audio_sample(left, right):
    return


@keep
@ctypes.CFUNCTYPE(ctypes.c_size_t, ctypes.POINTER(ctypes.c_int16), ctypes.c_size_t)
def audio_batch(data, frames):
    return frames


def save_png(path: Path) -> None:
    raw, w, h, pitch = frame["raw"], frame["w"], frame["h"], frame["pitch"]
    if not raw or w == 0:
        raise SystemExit(f"no frame for {path}")
    rows = []
    if pixfmt == RETRO_PIXEL_FORMAT_XRGB8888:
        for y in range(h):
            row = raw[y * pitch : y * pitch + w * 4]
            rgb = bytearray()
            for x in range(w):
                b, g, r = row[x * 4], row[x * 4 + 1], row[x * 4 + 2]
                rgb += bytes((r, g, b))
            rows.append(bytes(rgb))
    else:
        for y in range(h):
            row = raw[y * pitch : y * pitch + w * 2]
            rgb = bytearray()
            for x in range(w):
                p = row[x * 2] | (row[x * 2 + 1] << 8)
                r = ((p >> 11) & 31) << 3
                g = ((p >> 5) & 63) << 2
                b = (p & 31) << 3
                rgb += bytes((r, g, b))
            rows.append(bytes(rgb))
    img = Image.frombytes("RGB", (w, h), b"".join(rows))
    img.save(path)
    print(f"wrote {path} {img.size} fmt={pixfmt}")


def dump_wram(core, tag: str) -> None:
    core.retro_get_memory_data.restype = ctypes.c_void_p
    core.retro_get_memory_size.restype = ctypes.c_size_t
    ptr = core.retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM)
    size = core.retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM)
    if not ptr or size < 96:
        print(tag, "no wram")
        return
    ram = ctypes.string_at(ptr, 128)

    def rb(i):
        return ram[i]

    def rw(i):
        return ram[i] | (ram[i + 1] << 8)

    print(
        f"{tag}: state={rb(2)} cam_x={rw(47)} col_need={rb(51)} "
        f"map_cols={rw(31)} pl=({rw(56)},{rw(58)}) enemies={rb(35)} "
        f"lives={rb(21)} nmi_ready={rb(3)} debug_step={rb(109)} "
        f"tmp_row={rw(76)} nmi_col_mc={rw(52)} dma_len={rw(98)}"
    )
    print(tag, "map7E2000", ctypes.string_at(ptr + 0x2000, 16).hex())


def main() -> None:
    global want_start
    rom_path = Path(sys.argv[1] if len(sys.argv) > 1 else "build/daniel.sfc")
    out = Path(sys.argv[2] if len(sys.argv) > 2 else "build")
    rom = rom_path.read_bytes()
    buf = ctypes.create_string_buffer(rom)

    core = ctypes.CDLL(CORE)
    core.retro_set_environment(environment)
    core.retro_set_video_refresh(video_refresh)
    core.retro_set_input_poll(input_poll)
    core.retro_set_input_state(input_state)
    core.retro_set_audio_sample(audio_sample)
    core.retro_set_audio_sample_batch(audio_batch)
    core.retro_init()

    info = GameInfo(str(rom_path).encode(), ctypes.addressof(buf), len(rom), None)
    core.retro_load_game.restype = ctypes.c_bool
    if not core.retro_load_game(ctypes.byref(info)):
        raise SystemExit("retro_load_game failed")
    try:
        core.retro_set_controller_port_device(0, 1)  # RETRO_DEVICE_JOYPAD
    except Exception:
        pass

    for _ in range(120):
        core.retro_run()
    dump_wram(core, "title")
    save_png(out / "probe_title.png")

    want_start = True
    for i in range(6):
        core.retro_run()
        dump_wram(core, f"start+{i}")
    want_start = False
    saved_play = False
    for i in range(90):
        core.retro_run()
        if i in (0, 2, 5, 10, 30, 89):
            dump_wram(core, f"play+{i}")
        ram = None
        try:
            ptr = core.retro_get_memory_data(2)
            if ptr:
                st = ctypes.string_at(ptr, 4)[2]
                if st == 2 and not saved_play:
                    save_png(out / "probe_play_live.png")
                    dump_wram(core, "play_live")
                    saved_play = True
        except Exception:
            pass
    dump_wram(core, "play")
    save_png(out / "probe_play.png")
    core.retro_deinit()


if __name__ == "__main__":
    main()
