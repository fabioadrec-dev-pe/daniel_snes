#!/usr/bin/env python3
"""Compile Java MIDI + WAV SFX into SNES SPC700 data: BRR samples + sequences.

The S-DSP only plays BRR. MIDI becomes a compact 60 Hz event stream for the
SPC700 driver (native sequencer), which is far smaller than PCM/OGG.
"""

from __future__ import annotations

import argparse
import math
import struct
import wave
from collections import defaultdict
from pathlib import Path

# Instruments in the BRR bank (must match src/spc.asm INST_*).
INST_PIANO = 0
INST_BASS = 1
INST_GUITAR = 2
INST_SQUARE = 3
INST_STRINGS = 4
INST_FLUTE = 5
INST_VIBES = 6
INST_PAD = 7
INST_HIT = 8
INST_KICK = 9
INST_SNARE = 10
INST_HAT = 11
INST_SFX0 = 12  # jump .. boss = 12..21

GM_TO_INST = {
    0: INST_PIANO,
    11: INST_VIBES,
    21: INST_SQUARE,
    24: INST_GUITAR,
    25: INST_GUITAR,
    30: INST_GUITAR,
    35: INST_BASS,
    37: INST_BASS,
    39: INST_BASS,
    48: INST_STRINGS,
    50: INST_STRINGS,
    52: INST_STRINGS,
    55: INST_HIT,
    71: INST_FLUTE,
    75: INST_FLUTE,
    81: INST_SQUARE,
    88: INST_PAD,
    91: INST_PAD,
    100: INST_PAD,
    119: INST_HAT,
    127: INST_SNARE,
}

SFX_NAMES = [
    "jump",
    "coin",
    "hurt",
    "defeat",
    "break",
    "victory",
    "gameover",
    "menu",
    "select",
    "boss",
]

OP_NOTE = 0x00  # 0x00-0x7F = MIDI note, next byte duration
OP_REST = 0x80
OP_INST = 0x81
OP_VOL = 0x82
OP_PAN = 0x83
OP_LOOP = 0xFE
OP_END = 0xFF

BASS_PROGRAMS = {35, 37, 39}

# The Java stage MIDI has more parts than the six SPC700 music voices.  Keep
# the authored musical roles instead of selecting only by note count: drums,
# bass, lead, two harmony parts and the guitar arpeggio.
STAGE_CHANNELS = (9, 1, 3, 2, 5, 8)


def read_vlq(data: bytes, i: int) -> tuple[int, int]:
    v = 0
    while True:
        b = data[i]
        i += 1
        v = (v << 7) | (b & 0x7F)
        if b < 0x80:
            return v, i


def parse_midi(path: Path) -> dict:
    data = path.read_bytes()
    assert data[:4] == b"MThd"
    hdr_len = struct.unpack(">I", data[4:8])[0]
    fmt, ntr, div = struct.unpack(">HHH", data[8:14])
    pos = 8 + hdr_len
    tempos: list[tuple[int, int]] = []
    events: list[tuple[int, int, str, int, int]] = []  # tick, ch, kind, a, b
    programs: dict[int, int] = {}
    while pos + 8 <= len(data):
        if data[pos : pos + 4] != b"MTrk":
            break
        ln = struct.unpack(">I", data[pos + 4 : pos + 8])[0]
        tr = data[pos + 8 : pos + 8 + ln]
        pos += 8 + ln
        i = 0
        tick = 0
        running = 0
        while i < len(tr):
            delta, i = read_vlq(tr, i)
            tick += delta
            b = tr[i]
            i += 1
            if b == 0xFF:
                t = tr[i]
                i += 1
                l, i = read_vlq(tr, i)
                payload = tr[i : i + l]
                i += l
                if t == 0x51 and l == 3:
                    tempos.append((tick, (payload[0] << 16) | (payload[1] << 8) | payload[2]))
            elif b in (0xF0, 0xF7):
                l, i = read_vlq(tr, i)
                i += l
            else:
                if b >= 0x80:
                    st = b
                    running = st
                    if st & 0xF0 in (0xC0, 0xD0):
                        d1 = tr[i]
                        i += 1
                        d2 = 0
                    else:
                        d1 = tr[i]
                        i += 1
                        d2 = tr[i]
                        i += 1
                else:
                    st = running
                    if st & 0xF0 in (0xC0, 0xD0):
                        d1, d2 = b, 0
                    else:
                        d1 = b
                        d2 = tr[i]
                        i += 1
                kind = st & 0xF0
                ch = st & 0x0F
                if kind == 0xC0:
                    programs[ch] = d1
                    events.append((tick, ch, "prog", d1, 0))
                elif kind == 0x90:
                    if d2:
                        events.append((tick, ch, "on", d1, d2))
                    else:
                        events.append((tick, ch, "off", d1, 0))
                elif kind == 0x80:
                    events.append((tick, ch, "off", d1, 0))
                elif kind == 0xB0:
                    if d1 == 7:
                        events.append((tick, ch, "vol", d2, 0))
                    elif d1 == 10:
                        events.append((tick, ch, "pan", d2, 0))
    if not tempos:
        tempos.append((0, 500000))
    tempos.sort()
    events.sort()
    return {"div": div, "tempos": tempos, "events": events, "programs": programs}


def midi_tick_to_frame(tick: int, tempos: list[tuple[int, int]], div: int) -> int:
    usec = 0.0
    t0 = 0
    tempo = tempos[0][1]
    for ts, tp in tempos:
        if ts >= tick:
            break
        usec += (ts - t0) * tempo / div
        t0, tempo = ts, tp
    usec += (tick - t0) * tempo / div
    return int(usec * 60.0 / 1_000_000.0)


def gm_inst(prog: int, ch: int) -> int:
    if ch == 9:
        return INST_KICK
    return GM_TO_INST.get(prog, INST_PIANO)


def is_drum_channel(parsed: dict, ch: int) -> bool:
    """MIDI channel 10 (zero-based 9) is GM percussion."""
    return ch == 9


def drum_inst(note: int) -> int:
    if note in (35, 36, 43, 41):
        return INST_KICK
    if note in (38, 39, 40, 37):
        return INST_SNARE
    return INST_HAT


def mono_events(ch_events: list, bass: bool) -> list[tuple[int, str, int, int, int]]:
    """(frame, kind, note, vel, inst_or_vol) with at most one sounding note."""
    sounding: list[tuple[int, int]] = []  # (note, vel)
    inst = INST_PIANO
    vol = 100
    out: list[tuple[int, str, int, int, int]] = []
    current: int | None = None

    def pick() -> tuple[int, int] | None:
        if not sounding:
            return None
        if bass:
            return min(sounding, key=lambda nv: nv[0])
        return sounding[-1]

    def emit_sel(frame: int) -> None:
        nonlocal current
        sel = pick()
        if sel is None:
            if current is not None:
                out.append((frame, "off", current, 0, 0))
                current = None
            return
        note, vel = sel
        if note != current:
            out.append((frame, "on", note, vel, inst))
            current = note

    for ev in ch_events:
        frame, kind, a, b = ev
        if kind == "prog":
            inst = gm_inst(a, 0)
            out.append((frame, "inst", inst, 0, 0))
        elif kind == "vol":
            vol = a
            out.append((frame, "vol", vol, 0, 0))
        elif kind == "pan":
            out.append((frame, "pan", a, 0, 0))
        elif kind == "on":
            sounding = [nv for nv in sounding if nv[0] != a]
            sounding.append((a, b))
            emit_sel(frame)
        elif kind == "off":
            sounding = [nv for nv in sounding if nv[0] != a]
            emit_sel(frame)
    if current is not None and ch_events:
        out.append((ch_events[-1][0] + 1, "off", current, 0, 0))
    return out


def drum_events(ch_events: list) -> list[tuple[int, str, int, int, int]]:
    out = []
    for frame, kind, a, b in ch_events:
        if kind == "on":
            out.append((frame, "inst", drum_inst(a), 0, 0))
            out.append((frame, "on", 60, b, 0))
            out.append((frame + 8, "off", 60, 0, 0))
        elif kind == "vol":
            out.append((frame, "vol", a, 0, 0))
        elif kind == "pan":
            out.append((frame, "pan", a, 0, 0))
    out.sort(key=lambda e: e[0])
    return out


def emit_track(evs: list[tuple[int, str, int, int, int]], is_drum: bool) -> bytes:
    """3-byte events: [delta_from_prev][op][arg], terminated by LOOP."""
    blob = bytearray()
    t = 0
    last_inst = -1
    last_vol = -1
    last_pan = -1
    pending: tuple[int, int, int] | None = None  # start, note, vel

    last_end = 0

    def emit(frame: int, op: int, arg: int) -> None:
        nonlocal t, last_end, blob
        gap = max(0, frame - t)
        while gap > 254:
            blob += bytes((254, OP_REST, 254))
            t += 254
            gap = max(0, frame - t)
        blob += bytes((gap, op & 0xFF, arg & 0xFF))
        t = frame
        last_end = max(last_end, frame)

    def flush(end: int) -> None:
        nonlocal pending, last_end
        if pending is None:
            return
        start, note, _vel = pending
        dur = max(6, min(254, end - start))
        emit(start, note & 0x7F, dur)
        last_end = max(last_end, start + dur)
        pending = None

    for frame, kind, a, b, _ in evs:
        if kind == "inst":
            if pending:
                flush(frame)
            if a != last_inst:
                emit(frame, OP_INST, a)
                last_inst = a
        elif kind == "vol":
            if a != last_vol:
                emit(frame, OP_VOL, max(1, min(127, a)))
                last_vol = a
        elif kind == "pan":
            pan = 1 if a <= 48 else 3 if a >= 80 else 2
            if pan != last_pan:
                emit(frame, OP_PAN, pan)
                last_pan = pan
        elif kind == "on":
            if pending:
                flush(frame)
            pending = (frame, a, b)
        elif kind == "off":
            if pending:
                flush(frame)
    if pending:
        flush(pending[0] + 16)
    emit(max(t, last_end), OP_LOOP, 0)
    # Drop leading delay so the first note is heard immediately.
    i = 0
    while i + 3 <= len(blob):
        op = blob[i + 1]
        if op == OP_LOOP:
            break
        blob[i] = 0
        if op < 0x80:
            break
        i += 3
    return bytes(blob)


def pick_channels(parsed: dict, n: int = 6) -> list[int]:
    counts: dict[int, int] = defaultdict(int)
    for _t, ch, kind, _a, _b in parsed["events"]:
        if kind == "on":
            counts[ch] += 1
    progs = parsed["programs"]
    chosen: list[int] = []
    # Always take drums + a bass if present.
    if 9 in counts and is_drum_channel(parsed, 9):
        chosen.append(9)
    bass_ch = None
    for ch, p in progs.items():
        if p in BASS_PROGRAMS and ch != 9:
            bass_ch = ch
            break
    if bass_ch is not None:
        chosen.append(bass_ch)
    rest = sorted((c for c in counts if c not in chosen), key=lambda c: -counts[c])
    for c in rest:
        if len(chosen) >= n:
            break
        chosen.append(c)
    return chosen[:n]


def compile_stage_midi(path: Path, voice_limit: int = 6) -> bytes:
    """Compile the Java stage MIDI with the six most musical source parts."""
    parsed = parse_midi(path)
    channels = [ch for ch in STAGE_CHANNELS if ch in {
        ev[1] for ev in parsed["events"] if ev[2] == "on"
    }][:voice_limit]
    by_ch: dict[int, list] = defaultdict(list)
    for tick, ch, kind, a, b in parsed["events"]:
        frame = midi_tick_to_frame(tick, parsed["tempos"], parsed["div"])
        by_ch[ch].append((frame, kind, a, b))

    encoded: list[bytes] = []
    # Keep the relative balance from the Java MIDI while leaving headroom for
    # the long bass/lead notes.  The dense guitar and chord ostinatos are the
    # main source of the muddy mix on six SNES voices.
    mix_gain = {9: 48, 1: 100, 3: 100, 2: 72, 5: 64, 8: 48}

    def mix_events(evs: list[tuple[int, str, int, int, int]], ch: int):
        gain = mix_gain.get(ch, 80)
        out = [(0, "vol", (100 * gain + 63) // 127, 0, 0)]
        pan_seen = False
        for frame, kind, a, b, c in evs:
            if kind == "vol":
                a = (a * gain + 63) // 127
            elif kind == "pan":
                # The MIDI contains repeated pan sweeps (especially on the
                # accordion part).  One initial position preserves separation
                # without spending the SPC song budget on controller noise.
                if pan_seen:
                    continue
                pan_seen = True
            out.append((frame, kind, a, b, c))
        return out

    for ch in channels:
        raw = by_ch[ch]
        if is_drum_channel(parsed, ch):
            evs = mix_events(drum_events(raw), ch)
            encoded.append(emit_track(evs, True))
        else:
            prog = parsed["programs"].get(ch, 0)
            evs = mono_events(raw, bass=prog in BASS_PROGRAMS)
            seeded = [(0, "inst", gm_inst(prog, ch), 0, 0)] + mix_events(evs, ch)
            encoded.append(emit_track(seeded, False))
    while len(encoded) < 6:
        encoded.append(bytes((254, OP_REST, 254, 0, OP_LOOP, 0)))

    header = bytearray(16)
    header[0] = 6
    off = 16
    for i, track in enumerate(encoded):
        struct.pack_into("<H", header, 2 + i * 2, off)
        off += len(track)
    return bytes(header) + b"".join(encoded)


def compile_midi(path: Path, voice_limit: int = 6) -> bytes:
    parsed = parse_midi(path)
    channels = pick_channels(parsed, voice_limit)
    by_ch: dict[int, list] = defaultdict(list)
    inst_at: dict[int, int] = dict(parsed["programs"])
    for tick, ch, kind, a, b in parsed["events"]:
        frame = midi_tick_to_frame(tick, parsed["tempos"], parsed["div"])
        by_ch[ch].append((frame, kind, a, b))
    tracks: list[bytes] = []
    for ch in channels:
        raw = by_ch.get(ch, [])
        if ch == 9:
            evs = drum_events(raw)
            tracks.append(emit_track(evs, True))
            continue
        prog = inst_at.get(ch, 0)
        evs = mono_events(raw, bass=prog in BASS_PROGRAMS)
        # Seed instrument.
        seeded = [(0, "inst", gm_inst(prog, ch), 0, 0)] + evs
        tracks.append(emit_track(seeded, False))
    while len(tracks) < 6:
        tracks.append(bytes((254, OP_REST, 254, 0, OP_LOOP, 0)))
    header = bytearray(16)
    header[0] = 6
    off = 16
    for i, tr in enumerate(tracks):
        struct.pack_into("<H", header, 2 + i * 2, off)
        off += len(tr)
    return bytes(header) + b"".join(tracks)


def compile_melody(notes: list[tuple[int | None, int]], inst: int, vol: int = 90) -> bytes:
    """notes: (midi or None, duration_frames). 3-byte events."""
    blob = bytearray()
    blob += bytes((0, OP_INST, inst, 0, OP_VOL, vol))
    prev = 0
    for note, dur in notes:
        d = max(1, min(254, dur))
        if note is None:
            blob += bytes((prev, OP_REST, d))
        else:
            blob += bytes((prev, note & 0x7F, d))
        prev = d
    blob += bytes((prev, OP_LOOP, 0))
    header = bytearray(16)
    header[0] = 6
    struct.pack_into("<H", header, 2, 16)
    empty = bytes((254, OP_REST, 254, 0, OP_LOOP, 0))
    off = 16 + len(blob)
    for i in range(1, 6):
        struct.pack_into("<H", header, 2 + i * 2, off)
        off += len(empty)
    return bytes(header) + bytes(blob) + empty * 5


def encode_brr(pcm: list[int], loop: bool) -> bytes:
    if not pcm:
        pcm = [0] * 16
    pcm = [max(-32767, min(32767, int(x))) for x in pcm]
    while len(pcm) % 16:
        pcm.append(0)
    out = bytearray()
    n = len(pcm) // 16
    for bi in range(n):
        chunk = pcm[bi * 16 : (bi + 1) * 16]
        mx = max((abs(x) for x in chunk), default=1) or 1
        shift = 0
        while (7 << shift) < mx and shift < 12:
            shift += 1
        nibbles = []
        for s in chunk:
            q = int(round(s / float(1 << shift))) if shift else int(round(s))
            q = max(-8, min(7, q))
            nibbles.append(q & 15)
        last = bi == n - 1
        header = (shift << 4) | ((1 if loop and last else 0) << 1) | (1 if last else 0)
        packed = bytes((nibbles[i] << 4) | nibbles[i + 1] for i in range(0, 16, 2))
        out.append(header)
        out += packed
    return bytes(out)


def wave_cycle(kind: str, n: int = 32, amp: int = 18000) -> list[int]:
    out = []
    for i in range(n):
        p = i / n
        if kind == "sine":
            s = math.sin(2 * math.pi * p)
        elif kind == "tri":
            s = 4 * abs(p - 0.5) - 1
        elif kind == "saw":
            s = 2 * p - 1
        elif kind == "square":
            s = 1.0 if p < 0.5 else -1.0
        elif kind == "guitar":
            # A raw sawtooth aliases badly when the 32-sample BRR loop is
            # transposed.  Keep the bright attack but use only low harmonics.
            s = (0.72 * math.sin(2 * math.pi * p)
                 + 0.22 * math.sin(4 * math.pi * p)
                 + 0.08 * math.sin(6 * math.pi * p))
        elif kind == "strings":
            # Softer than a sawtooth, leaving sustained choir/string notes
            # present without filling the mix with high-frequency fizz.
            s = (0.78 * math.sin(2 * math.pi * p)
                 + 0.17 * math.sin(4 * math.pi * p)
                 + 0.05 * math.sin(6 * math.pi * p))
        elif kind == "piano":
            s = 0.7 * math.sin(2 * math.pi * p) + 0.25 * math.sin(4 * math.pi * p)
        elif kind == "pad":
            s = 0.5 * math.sin(2 * math.pi * p) + 0.3 * math.sin(4 * math.pi * p + 0.4)
        else:
            s = math.sin(2 * math.pi * p)
        out.append(int(amp * s))
    return out


def gen_kick() -> list[int]:
    n = 160
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = 160 * (1 - t) + 40 * t
        phase += freq / 16000.0
        env = (1 - t) ** 2
        out.append(int(22000 * math.sin(2 * math.pi * phase) * env))
    return out


def gen_snare() -> list[int]:
    n = 192
    out = []
    x = 1
    for i in range(n):
        t = i / n
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF
        noise = ((x >> 16) / 32768.0) * 2 - 1
        tone = math.sin(2 * math.pi * 180 * i / 16000.0)
        env = (1 - t) ** 1.5
        out.append(int(18000 * (0.35 * tone + 0.65 * noise) * env))
    return out


def gen_hat() -> list[int]:
    n = 96
    out = []
    x = 7
    for i in range(n):
        t = i / n
        x = (x * 1664525 + 1013904223) & 0x7FFFFFFF
        noise = ((x >> 16) / 32768.0) * 2 - 1
        env = (1 - t) ** 3
        out.append(int(12000 * noise * env))
    return out


def gen_hit() -> list[int]:
    n = 64
    return [int(20000 * math.sin(2 * math.pi * i / 16) * ((n - i) / n)) for i in range(n)]


def resample_mono(samples: list[int], src_rate: int, dst_rate: int) -> list[int]:
    if src_rate == dst_rate:
        return samples
    n = int(len(samples) * dst_rate / src_rate)
    out = []
    for i in range(n):
        pos = i * src_rate / dst_rate
        i0 = int(pos)
        f = pos - i0
        a = samples[i0] if i0 < len(samples) else 0
        b = samples[i0 + 1] if i0 + 1 < len(samples) else 0
        out.append(int(a * (1 - f) + b * f))
    return out


def load_wav_mono(path: Path) -> tuple[list[int], int]:
    with wave.open(str(path), "rb") as w:
        nch = w.getnchannels()
        sw = w.getsampwidth()
        rate = w.getframerate()
        n = w.getnframes()
        raw = w.readframes(n)
    samples = []
    if sw == 2:
        fmt = "<" + "h" * (len(raw) // 2)
        vals = struct.unpack(fmt, raw)
        if nch == 1:
            samples = list(vals)
        else:
            samples = [vals[i] for i in range(0, len(vals), nch)]
    else:
        samples = [(b - 128) * 256 for b in raw[::nch]]
    return samples, rate


def pitch_table() -> bytes:
    # 32-sample loop @ 32 kHz → 1000 Hz at pitch $1000.
    out = bytearray()
    for n in range(128):
        freq = 440.0 * (2.0 ** ((n - 69) / 12.0))
        p = int(freq / 1000.0 * 4096.0)
        p = max(0x0040, min(0x3FFF, p))
        out += struct.pack("<H", p)
    return bytes(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--java", type=Path, required=True)
    ap.add_argument("--assets", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    out: Path = args.out
    out.mkdir(parents=True, exist_ok=True)

    waves = [
        ("piano", True, wave_cycle("piano")),
        ("bass", True, wave_cycle("tri", amp=20000)),
        ("guitar", True, wave_cycle("guitar", amp=14000)),
        ("square", True, wave_cycle("square", amp=12000)),
        ("strings", True, wave_cycle("strings", amp=10000)),
        ("flute", True, wave_cycle("sine", amp=16000)),
        ("vibes", True, wave_cycle("sine", amp=17000)),
        ("pad", True, wave_cycle("pad", amp=12000)),
        ("hit", False, gen_hit()),
        ("kick", False, gen_kick()),
        ("snare", False, gen_snare()),
        ("hat", False, gen_hat()),
    ]
    brr_blob = bytearray()
    dir_blob = bytearray(64 * 4)
    starts = []
    loops = []
    addr = 0x1000
    for name, loop, pcm in waves:
        brr = encode_brr(pcm, loop)
        starts.append(addr)
        loops.append(addr if loop else addr)
        brr_blob += brr
        addr += len(brr)
        print(f"inst {name}: {len(brr)} bytes loop={loop}")

    sfx_dir = args.assets / "sfx"
    for i, name in enumerate(SFX_NAMES):
        samples, rate = load_wav_mono(sfx_dir / f"{name}.wav")
        samples = resample_mono(samples, rate, 12000)
        peak = max((abs(x) for x in samples), default=1) or 1
        if peak < 8000:
            g = 16000 / peak
            samples = [int(x * g) for x in samples]
        brr = encode_brr(samples, False)
        starts.append(addr)
        loops.append(addr)
        brr_blob += brr
        addr += len(brr)
        print(f"sfx {name}: {len(brr)} bytes")

    for i, (st, lp) in enumerate(zip(starts, loops)):
        struct.pack_into("<HH", dir_blob, i * 4, st, lp)

    (out / "spc_pitch.bin").write_bytes(pitch_table())
    (out / "spc_dir.bin").write_bytes(bytes(dir_blob))
    (out / "spc_brr.bin").write_bytes(bytes(brr_blob))

    java: Path = args.java
    songs = {
        "song_menu.bin": compile_midi(java / "menu_lady.mid", voice_limit=4),
        "song_stage.bin": compile_stage_midi(java / "music.mid"),
        "song_boss.bin": compile_midi(java / "boss.mid", voice_limit=4),
        "song_victory.bin": compile_melody(
            [(72, 9), (76, 9), (79, 9), (84, 18), (79, 9), (84, 30)] * 2,
            INST_SQUARE,
        ),
        "song_gameover.bin": compile_melody(
            [(67, 24), (65, 24), (64, 24), (62, 24), (60, 48), (None, 24)],
            INST_STRINGS,
            vol=80,
        ),
    }
    for name, blob in songs.items():
        if len(blob) > 0x8000:
            raise SystemExit(f"{name} exceeds the 32 KiB SPC song upload window: {len(blob)} bytes")
        (out / name).write_bytes(blob)
        print(f"{name}: {len(blob)} bytes")
    (out / "spc_songmeta.inc").write_text(
        f".DEFINE SONG_MENU_BYTES {len(songs['song_menu.bin'])}\n"
        f".DEFINE SONG_STAGE_BYTES {len(songs['song_stage.bin'])}\n"
        f".DEFINE SONG_BOSS_BYTES {len(songs['song_boss.bin'])}\n"
        f".DEFINE SONG_VICTORY_BYTES {len(songs['song_victory.bin'])}\n"
        f".DEFINE SONG_GAMEOVER_BYTES {len(songs['song_gameover.bin'])}\n"
    )
    print(f"brr end ${0x0700 + len(brr_blob):04X} total brr={len(brr_blob)}")


if __name__ == "__main__":
    main()
