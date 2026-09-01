#!/usr/bin/env python3
"""Convert Daniel do Bolo Java assets into SNES CHR/maps/palettes.

Reads the LibGDX asset tree and bakes StageFactory maps with a java.util.Random
replica so the five stages match the PC game.
"""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageEnhance

# ----- java.util.Random -------------------------------------------------------


class JavaRandom:
    MULTIPLIER = 0x5DEECE66D
    ADDEND = 0xB
    MASK = (1 << 48) - 1

    def __init__(self, seed: int) -> None:
        self.seed = (seed ^ self.MULTIPLIER) & self.MASK

    def next(self, bits: int) -> int:
        self.seed = (self.seed * self.MULTIPLIER + self.ADDEND) & self.MASK
        return self.seed >> (48 - bits)

    def next_int(self, n: int) -> int:
        if n <= 0:
            raise ValueError(n)
        if n & -n == n:
            return (n * self.next(31)) >> 31
        while True:
            bits = self.next(31)
            val = bits % n
            if bits - val + (n - 1) >= 0:
                return val


# ----- StageFactory replica ---------------------------------------------------

AIR, GRASS, DIRT, BRICK, PLATFORM, SPIKE, STONE, DECO = range(8)
ROWS = 14
TILE = 16
TOTAL_STAGES = 5

ENEMY_IDS = {"walker": 0, "flyer": 1, "fast": 2, "tank": 3, "boss": 4}


def enemy_pool(stage: int) -> list[str]:
    return [
        ["walker"],
        ["walker", "flyer"],
        ["walker", "flyer", "fast"],
        ["walker", "fast", "tank"],
        ["walker", "flyer", "fast", "tank"],
    ][stage]


def build_stage(stage_index: int) -> dict:
    boss = stage_index == TOTAL_STAGES - 1
    cols = 64 if boss else (96 + stage_index * 24)
    g = [[AIR] * cols for _ in range(ROWS)]
    rnd = JavaRandom(1000 + stage_index)
    ground_h = 2
    top_row = ground_h - 1

    coins: list[tuple[int, int]] = []
    enemies: list[tuple[int, int, int]] = []
    checkpoints: list[tuple[int, int]] = []

    for c in range(cols):
        g[top_row][c] = GRASS
        for r in range(top_row):
            g[r][c] = DIRT

    pit = [False] * cols
    if not boss:
        pit_count = 2 + stage_index * 2
        for _ in range(pit_count):
            length = 2 + rnd.next_int(2 + stage_index)
            start = 10 + rnd.next_int(max(1, cols - 25))
            for c in range(start, min(cols - 8, start + length)):
                for r in range(top_row + 1):
                    g[r][c] = AIR
                pit[c] = True
                if stage_index >= 2:
                    g[0][c] = SPIKE

    platforms = 2 if boss else (4 + stage_index * 2)
    for _ in range(platforms):
        length = 3 + rnd.next_int(3)
        row = 4 + rnd.next_int(5)
        start = 8 + rnd.next_int(max(1, cols - 16))
        end = min(cols - 4, start + length)
        # Max held jump is ~89px. Floor stand is y=32, so row 7+ (stand 128+)
        # cannot be reached. Keep pit crossings at row 4 (48px hop).
        if any(pit[c] for c in range(start, end)):
            row = 4
        for c in range(start, end):
            g[row][c] = PLATFORM
            coins.append((c * TILE, (row + 1) * TILE))
    # Wide spiked pits with no stepping stone: 3-tile platform at row 4.
    c = 0
    while c < cols:
        if pit[c] and g[0][c] == SPIKE:
            s = c
            while c < cols and pit[c]:
                c += 1
            e = c - 1
            if e - s + 1 >= 4 and not any(
                g[r][x] == PLATFORM for r in range(ROWS) for x in range(s, e + 1)
            ):
                mid = (s + e) // 2
                for x in range(max(s, mid - 1), min(e, mid + 1) + 1):
                    g[4][x] = PLATFORM
                    coins.append((x * TILE, 5 * TILE))
        else:
            c += 1

    for c in range(6, cols - 6, 6):
        if not pit[c]:
            coins.append((c * TILE, (top_row + 2) * TILE))

    coins.append(((cols - 12) * TILE, (ROWS - 3) * TILE))

    if boss:
        enemies.append((ENEMY_IDS["boss"], (cols - 20) * TILE, ground_h * TILE))
        enemies.append((ENEMY_IDS["walker"], (cols // 2) * TILE, ground_h * TILE))
    else:
        pool = enemy_pool(stage_index)
        for _ in range(3 + stage_index * 2):
            c = 12 + rnd.next_int(max(1, cols - 20))
            if pit[c]:
                continue
            typ = pool[rnd.next_int(len(pool))]
            ey = (top_row + 4) * TILE if typ == "flyer" else ground_h * TILE
            enemies.append((ENEMY_IDS[typ], c * TILE, ey))

    for col in (cols // 3, (2 * cols) // 3):
        col = max(4, min(cols - 5, col))
        if pit[col]:
            col += 1
        checkpoints.append((col * TILE, ground_h * TILE))

    return {
        "cols": cols,
        "rows": ROWS,
        "grid": g,
        "player_x": 2 * TILE,
        "player_y": ground_h * TILE,
        "goal_x": (cols - 10) * TILE,
        "goal_y": ground_h * TILE,
        "boss": int(boss),
        "enemies": enemies,
        "coins": coins,
        "checkpoints": checkpoints,
    }


def pack_one_stage(st: dict) -> bytes:
    cols = st["cols"]
    rows = st["rows"]
    body = bytearray()
    body += struct.pack(
        "<HBBHHHHBBBB",
        cols,
        rows,
        st["boss"],
        st["player_x"],
        st["player_y"],
        st["goal_x"],
        st["goal_y"],
        len(st["enemies"]),
        len(st["coins"]),
        len(st["checkpoints"]),
        0,
    )
    for r in range(rows):
        body += bytes(st["grid"][r])
    for typ, x, y in st["enemies"]:
        body += struct.pack("<BHH", typ, x, y)
    for x, y in st["coins"]:
        body += struct.pack("<HH", x, y)
    for x, y in st["checkpoints"]:
        body += struct.pack("<HH", x, y)
    return bytes(body)


def pack_stages(stages: list[dict], out: Path) -> list[bytes]:
    blobs = [pack_one_stage(st) for st in stages]
    for i, b in enumerate(blobs):
        (out / f"stage{i}.bin").write_bytes(b)
    return blobs


# ----- SNES graphics ----------------------------------------------------------


def pal_colors(im_or_bytes, count: int) -> list[tuple[int, int, int]]:
    if hasattr(im_or_bytes, "getpalette"):
        pal = im_or_bytes.getpalette() or []
    else:
        pal = im_or_bytes or []
    n = min(count, len(pal) // 3)
    colors = [(pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2]) for i in range(n)]
    while len(colors) < count:
        colors.append((0, 0, 0))
    return colors


def to_bgr555(r: int, g: int, b: int) -> int:
    return (r >> 3) | ((g >> 3) << 5) | ((b >> 3) << 10)


def encode_4bpp_tile(indices: list[int]) -> bytes:
    out = bytearray(32)
    for row in range(8):
        p0 = p1 = p2 = p3 = 0
        for col in range(8):
            v = indices[row * 8 + col] & 15
            bit = 7 - col
            if v & 1:
                p0 |= 1 << bit
            if v & 2:
                p1 |= 1 << bit
            if v & 4:
                p2 |= 1 << bit
            if v & 8:
                p3 |= 1 << bit
        out[row * 2] = p0
        out[row * 2 + 1] = p1
        out[16 + row * 2] = p2
        out[16 + row * 2 + 1] = p3
    return bytes(out)


def encode_2bpp_tile(indices: list[int]) -> bytes:
    out = bytearray(16)
    for row in range(8):
        p0 = p1 = 0
        for col in range(8):
            v = indices[row * 8 + col] & 3
            bit = 7 - col
            if v & 1:
                p0 |= 1 << bit
            if v & 2:
                p1 |= 1 << bit
        out[row * 2] = p0
        out[row * 2 + 1] = p1
    return bytes(out)


def palette_bytes(colors: list[tuple[int, int, int]], count: int = 16) -> bytes:
    out = bytearray()
    for i in range(count):
        if i < len(colors):
            r, g, b = colors[i]
        else:
            r = g = b = 0
        val = to_bgr555(r, g, b)
        out += struct.pack("<H", val)
    return bytes(out)


def quantize_opaque(im: Image.Image, colors: int = 16) -> tuple[Image.Image, list[tuple[int, int, int]]]:
    rgb = im.convert("RGB")
    q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette() or [0] * (colors * 3)
    n = min(colors, len(pal) // 3)
    entries = [(pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2]) for i in range(n)]
    while len(entries) < colors:
        entries.append((0, 0, 0))
    img = q.convert("P")
    # Color 0 is SNES transparent. Put the darkest entry there so photo
    # holes match the real background instead of the CGRAM backdrop.
    dark = min(range(colors), key=lambda i: entries[i][0] + entries[i][1] + entries[i][2])
    if dark != 0:
        entries[0], entries[dark] = entries[dark], entries[0]
        px = img.load()
        w, h = img.size
        for y in range(h):
            for x in range(w):
                v = px[x, y] % colors
                if v == 0:
                    px[x, y] = dark
                elif v == dark:
                    px[x, y] = 0
    pal_bytes = [c for rgb in entries for c in rgb]
    img.putpalette(pal_bytes + [0] * (768 - len(pal_bytes)))
    return img, entries


def image_to_4bpp_tiles(im: Image.Image, palette: list[tuple[int, int, int]]) -> bytes:
    """Split a palette image into row-major 8x8 4bpp tiles."""
    w, h = im.size
    tiles = bytearray()
    px = im.load()
    for ty in range(h // 8):
        for tx in range(w // 8):
            idx = []
            for y in range(8):
                for x in range(8):
                    idx.append(px[tx * 8 + x, ty * 8 + y] & 15)
            tiles += encode_4bpp_tile(idx)
    return bytes(tiles)


def image_to_unique_4bpp(
    im: Image.Image, max_tiles: int = 700, nearest: bool = False
) -> tuple[bytes, bytes, int]:
    """8x8 unique tiles + 32x32 SNES tilemap (palette 1). CHR stays below BG3 at $5000."""
    w, h = im.size
    px = im.load()
    cols, rows = w // 8, h // 8
    seen: dict[bytes, int] = {}
    tiles: list[bytes] = []
    ids: list[int] = []
    for ty in range(rows):
        for tx in range(cols):
            raw = bytes(px[tx * 8 + x, ty * 8 + y] & 15 for y in range(8) for x in range(8))
            idx = seen.get(raw)
            if idx is None:
                if len(tiles) >= max_tiles:
                    if nearest and tiles:
                        idx = min(
                            range(len(tiles)),
                            key=lambda i: sum(abs(a - b) for a, b in zip(raw, tiles[i])),
                        )
                    else:
                        idx = 0
                    seen[raw] = idx
                else:
                    idx = len(tiles)
                    seen[raw] = idx
                    tiles.append(raw)
            ids.append(idx)
    chr_data = bytearray()
    for t in tiles:
        chr_data += encode_4bpp_tile(list(t))
    attr = 1 << 10
    tilemap = bytearray()
    for y in range(32):
        for x in range(32):
            if y < rows and x < cols:
                tile = ids[y * cols + x]
            else:
                tile = 0
            tilemap += struct.pack("<H", (tile & 0x3FF) | attr)
    return bytes(chr_data), bytes(tilemap), len(tiles)


def rgba_frames(path: Path, fw: int, fh: int) -> list[Image.Image]:
    im = Image.open(path).convert("RGBA")
    n = im.width // fw
    return [im.crop((i * fw, 0, (i + 1) * fw, fh)) for i in range(n)]


def pad_to(im: Image.Image, tw: int, th: int) -> Image.Image:
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    x = (tw - im.width) // 2
    y = th - im.height  # feet on the bottom
    if y < 0:
        y = 0
    canvas.paste(im, (x, y), im)
    return canvas


def scale_to(im: Image.Image, tw: int, th: int) -> Image.Image:
    return im.resize((tw, th), Image.Resampling.NEAREST)


def quantize_sprite_frames(
    frames: list[Image.Image],
) -> tuple[list[Image.Image], list[tuple[int, int, int]]]:
    """Shared 15-color palette + transparent index 0 across frames."""
    merged = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        merged.paste(fr, (i * fr.width, 0), fr)
    opaque = Image.new("RGB", merged.size, (0, 0, 0))
    mask = merged.split()[-1]
    opaque.paste(merged.convert("RGB"), mask=mask)
    q = opaque.quantize(colors=15, method=Image.Quantize.MEDIANCUT)
    colors = [(0, 0, 0)] + pal_colors(q, 15)
    indexed_frames = []
    qpx = q.load()
    mpx = mask.load()
    fw, fh = frames[0].size
    for i in range(len(frames)):
        out = Image.new("P", (fw, fh))
        out.putpalette([c for rgb in colors for c in rgb] + [0] * (768 - 16 * 3))
        opx = out.load()
        ox = i * fw
        for y in range(fh):
            for x in range(fw):
                if mpx[ox + x, y] < 16:
                    opx[x, y] = 0
                else:
                    opx[x, y] = 1 + (qpx[ox + x, y] % 15)
        indexed_frames.append(out)
    return indexed_frames, colors


def frames_to_chr(frames: list[Image.Image]) -> bytes:
    out = bytearray()
    for fr in frames:
        out += image_to_4bpp_tiles(fr, [])
    return bytes(out)


class ObjSheet:
    """SNES OBJ VRAM is 16 tiles (128px) wide. 16x16 uses T,T+1,T+16,T+17;
    32x32 uses those plus T+2,T+3 and T+32.. so frames must sit on that grid.
    """

    def __init__(self) -> None:
        self.tiles: list[bytes] = []
        self.n_rows = 0
        self.row = 0
        self.col = 0
        self.band_h = 0

    def _ensure(self, rows: int) -> None:
        while self.n_rows < rows:
            self.tiles.extend([bytes(32)] * 16)
            self.n_rows += 1

    def start_actor(self, th: int) -> None:
        tht = th // 8
        if self.col != 0 or (self.band_h and self.band_h != tht):
            self.row += self.band_h if self.band_h else 0
            self.col = 0
        self.band_h = tht

    def add_frame(self, im: Image.Image, tw: int, th: int) -> int:
        twt, tht = tw // 8, th // 8
        if self.col + twt > 16:
            self.row += self.band_h
            self.col = 0
        self._ensure(self.row + tht)
        px = im.load()
        base = self.row * 16 + self.col
        for ty in range(tht):
            for tx in range(twt):
                idx = [
                    px[tx * 8 + x, ty * 8 + y] & 15
                    for y in range(8)
                    for x in range(8)
                ]
                self.tiles[(self.row + ty) * 16 + (self.col + tx)] = encode_4bpp_tile(idx)
        self.col += twt
        return base

    def to_bytes(self) -> bytes:
        return b"".join(self.tiles)


def make_font_chr() -> tuple[bytes, dict[str, int]]:
    """8x8 2bpp font. 0 empty, 1 white glyph, 2 dark outline (CRT contrast)."""
    glyphs = (
        " !\"#$%&'()*+,-./0123456789:;<=>?@"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_."
    )
    img = Image.new("P", (8 * 16, 8 * 6), 0)
    img.putpalette([0, 0, 0, 255, 255, 255, 32, 32, 48, 80, 80, 80] + [0] * (768 - 12))
    font = None
    for candidate in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/freefont/FreeMono.ttf",
    ):
        p = Path(candidate)
        if p.exists():
            font = ImageFont.truetype(str(p), 8)
            break
    mapping: dict[str, int] = {}
    mapping[" "] = 0
    tiles = bytearray(encode_2bpp_tile([0] * 64))
    m7 = bytearray(64)  # tile 0 empty, 8bpp row-major for Mode 7
    index = 1
    for ch in glyphs:
        if ch == " ":
            continue
        cell = Image.new("P", (8, 8), 0)
        cell.putpalette(img.getpalette())
        d = ImageDraw.Draw(cell)
        # Inset 1px so the outline has room on the left/top of the tile.
        if font is not None:
            d.text((1, 0), ch, fill=1, font=font)
        else:
            d.text((1, 0), ch, fill=1)
        mapping[ch] = index
        px = cell.load()
        ink = [[1 if (px[x, y] & 3) else 0 for x in range(8)] for y in range(8)]
        idx: list[int] = []
        for y in range(8):
            for x in range(8):
                if ink[y][x]:
                    idx.append(1)
                    continue
                ring = False
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dx == 0 and dy == 0:
                            continue
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < 8 and 0 <= nx < 8 and ink[ny][nx]:
                            ring = True
                            break
                    if ring:
                        break
                idx.append(2 if ring else 0)
        tiles += encode_2bpp_tile(idx)
        m7 += bytes(idx)
        index += 1
    mapping["."] = mapping.get(".", index - 1)
    return bytes(tiles), mapping, bytes(m7)


_FOLD_ASCII = str.maketrans(
    "ÁÀÂÃÄáàâãäÉÈÊËéèêëÍÌÎÏíìîïÓÒÔÕÖóòôõöÚÙÛÜúùûüÇçÑñÝý",
    "AAAAAaaaaaEEEEeeeeIIIIiiiiOOOOOoooooUUUUuuuuCcNnYy",
)


def fold_ascii(text: str) -> str:
    return text.translate(_FOLD_ASCII)


def make_m7_hdma() -> bytes:
    """Star Wars trapezoid on M7A only (M7D stays 1:1 so glyphs are not shredded).

    2-line bands: small/narrow at the top, wide at the bottom.
    """
    band = 2
    far = 0x01C0   # 1.75x zoom-out at y=0
    near = 0x00A8  # 0.66x zoom-in at y=223
    b = (near * 223) // (far - near)
    a = far * b
    out = bytearray()
    y = 0
    while y < 224:
        n = min(band, 224 - y)
        sc = a // (y + b)
        sc = max(0x00A0, min(0x0200, sc))
        out.append(n)
        out += struct.pack("<H", sc & 0xFFFF)
        y += n
    out.append(0)
    return bytes(out)


def encode_text_line(text: str, mapping: dict[str, int], width: int) -> list[int]:
    ids = [mapping.get(ch, mapping.get(" ", 0)) for ch in fold_ascii(text).upper()]
    if len(ids) > width:
        ids = ids[:width]
    pad = width - len(ids)
    left = pad // 2
    return [0] * left + ids + [0] * (width - left - len(ids))


# Brasilia Teimosa street names from the Java PresentationScreen list.
BRASILIA_STREETS = [
    "Avenida Brasília Formosa",
    "Rua Delfim",
    "Rua Golfinho",
    "Rua Gustavo Krause",
    "Rua Medusa",
    "Rua Vereador Romildo Gomes",
    "Rua Badejo",
    "Rua Roberto Magalhães",
    "Rua Estrela do Mar",
    "Rua Marcos Antônio de Oliveira Maciel",
    "Rua Paru",
    "Rua João Batista de Oliveira Figueiredo",
    "Rua das Orquídeas",
    "Rua Espardate",
    "Rua Esmerindo de Oliveira",
    "Rua Anequim",
    "Rua Poraquê",
    "Rua Serra",
    "Rua Dragão do Mar",
    "Rua Albacora",
    "Rua Artur Bernardes",
    "Rua Dagoberto Pires",
    "Rua Afrânio",
    "Rua França",
    "Rua do Jaú",
    "Rua Assunção",
    "Rua das Angélicas",
    "Rua Doutor Paes de Melo",
    "Rua da Amizade",
    "Rua Arabaiana",
    "Rua João Marques dos Anjos",
    "Rua Ricardo Câmara",
    "Rua Brazópolis",
    "Rua Porto Feliz",
    "Rua Alagoinha",
    "Rua Marechal Hermes",
    "Rua Raimundo Vicente",
    "Rua Japerica",
    "Rua Salgado Filho",
    "Rua Nanuque",
    "Rua Quatá",
    "Rua Manituba",
    "Rua Investigador Eraldo Ferreira Viana",
    "Rua Copaíba",
    "Rua Nova Germano",
    "Rua Pargo",
    "Rua Km-1 da Barra",
    "Rua Piraúna",
    "Rua da Vitória",
    "Rua Sobreiro",
    "Rua Galboa",
    "Rua Palombeta",
]


def wrap_street_name(text: str, width: int = 32) -> list[str]:
    t = fold_ascii(text).upper().strip()
    if not t:
        return [""]
    out: list[str] = []
    while t:
        if len(t) <= width:
            out.append(t)
            break
        chunk = t[:width]
        sp = chunk.rfind(" ")
        if sp <= 0:
            out.append(t[:width])
            t = t[width:].strip()
        else:
            out.append(t[:sp])
            t = t[sp + 1 :].strip()
    return out


def pack_street_lines(mapping: dict[str, int]) -> tuple[bytes, int, int]:
    """32-byte centered font rows. Long street names wrap so nothing is cut."""
    lines: list[str] = [
        "BRASILIA TEIMOSA",
        "AS RUAS DO BAIRRO",
        "",
    ]
    for name in BRASILIA_STREETS:
        wrapped = wrap_street_name(name, 32)
        lines.extend(wrapped)
        if len(wrapped) > 1:
            lines.append("")  # gap after a wrapped name
    blob = bytearray()
    for text in lines:
        blob += bytes(encode_text_line(text, mapping, 32))
    n = len(lines)
    # 16px per line, plus one screen so the last name can leave the top.
    scroll_end = n * 16 + 224
    return bytes(blob), n, scroll_end


ENDING_STORY = (
    "Finalmente, depois de uma infancia que passou fome e aguentar "
    "clientes de sua barraca (quer dizer, APAPINHA), Daniel do Bolo, "
    "homem nascido e criado em Brasilia Teimosa, ganhou a Mega Sena, "
    "deu dinheiro para os parentes e amigos, e finalmente realiozou o "
    "sonho de comprar um iate e curtir festinhas em alto mar. "
    "Mas nao foi facil: precisou ir pra Noronha enfrentar como mestre "
    "final do jogo ARAPINHA (isso, o boneco feio que e o mestre so "
    "podia ser ele), que apos receber uma lapda de Serra Grannde "
    "resolveu ajudar com o sonho de Daniel."
)

ENDING_CREDITS = [
    "DANIEL DO BOLO'S ADVENTURE",
    "",
    "Voce venceu!",
    "",
    "GAME DESIGN",
    "fabio_ad",
    "",
    "PROGRAMACAO (JAVA / LIBGDX)",
    "fabio_ad",
    "",
    "ARTE PIXEL (16 BITS)",
    "fabio_ad",
    "",
    "MUSICA E EFEITOS",
    "fabio_ad",
    "",
    "AMBIENTACAO",
    "Bairro Brasilia Teimosa",
    "Recife/PE",
    "",
    "Obrigado por jogar!",
    "",
    "PONTOS 00000",
]


def wrap_paragraph(text: str, width: int = 28) -> list[str]:
    out: list[str] = []
    for para in fold_ascii(text).replace("\n", " ").split("  "):
        para = para.strip()
        if not para:
            continue
        words = para.split()
        line = ""
        for w in words:
            trial = w if not line else line + " " + w
            if len(trial) <= width:
                line = trial
            else:
                if line:
                    out.append(line)
                line = w if len(w) <= width else w[:width]
        if line:
            out.append(line)
    return out


def pack_ending_lines(mapping: dict[str, int], lines: list[str]) -> tuple[bytes, int, int]:
    blob = bytearray()
    for text in lines:
        blob += bytes(encode_text_line(text, mapping, 32))
    n = len(lines)
    scroll_end = n * 8 + 224
    return bytes(blob), n, scroll_end


def crop_dark_margins(im: Image.Image, thresh: int = 48) -> Image.Image:
    rgb = im.convert("RGB")
    px = rgb.load()
    w, h = rgb.size
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r + g + b >= thresh:
                if x < minx:
                    minx = x
                if y < miny:
                    miny = y
                if x > maxx:
                    maxx = x
                if y > maxy:
                    maxy = y
    if maxx < minx:
        return rgb
    pad = 8
    minx = max(0, minx - pad)
    miny = max(0, miny - pad)
    maxx = min(w - 1, maxx + pad)
    maxy = min(h - 1, maxy + pad)
    return rgb.crop((minx, miny, maxx + 1, maxy + 1))


# ----- main -------------------------------------------------------------------


def write_meta(path: Path, **defs: int | str) -> None:
    lines = ["; Auto-generated by tools/port_assets.py. Do not edit.\n"]
    for k, v in defs.items():
        if isinstance(v, str):
            lines.append(f'.DEFINE {k} {v}\n')
        else:
            lines.append(f".DEFINE {k} {v}\n")
    path.write_text("".join(lines))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--assets",
        default="/run/media/fabio/Dados/Fabio/dan-java/DanielDoBolosAdventure/assets",
    )
    ap.add_argument("--out", default="src/gen")
    args = ap.parse_args()
    assets = Path(args.assets)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    stages = [build_stage(i) for i in range(TOTAL_STAGES)]
    blobs = pack_stages(stages, out)
    meta: dict[str, int] = {}
    for i, (st, b) in enumerate(zip(stages, blobs)):
        meta[f"STAGE{i}_BYTES"] = len(b)
        print(
            f"stage {i+1}: {st['cols']}x{st['rows']}  "
            f"enemies={len(st['enemies'])} coins={len(st['coins'])} "
            f"bytes={len(b)} goal_x={st['goal_x']}"
        )

    # Tileset: 8 tiles of 16x16 → 32 8x8 tiles, 4bpp, 16 colors.
    ts = Image.open(assets / "tiles" / "tileset.png").convert("RGBA")
    # Rebuild: keep transparency of tile 0.
    rgb = Image.new("RGB", ts.size, (0, 0, 0))
    rgb.paste(ts.convert("RGB"), mask=ts.split()[-1])
    ts_q = rgb.quantize(colors=15, method=Image.Quantize.MEDIANCUT)
    ts_colors = [(0, 0, 0)] + pal_colors(ts_q, 15)
    ts_idx = Image.new("P", ts.size)
    ts_idx.putpalette([c for rgb_ in ts_colors for c in rgb_] + [0] * (768 - 48))
    qpx = ts_q.load()
    mpx = ts.split()[-1].load()
    ipx = ts_idx.load()
    for y in range(ts.height):
        for x in range(ts.width):
            if mpx[x, y] < 16:
                ipx[x, y] = 0
            else:
                ipx[x, y] = 1 + (qpx[x, y] % 15)
    (out / "tileset.chr").write_bytes(image_to_4bpp_tiles(ts_idx, ts_colors))

    # Sprites
    def take(path: str, fw: int, fh: int, tw: int, th: int, which: list[int] | None, scale: bool = False):
        frames = rgba_frames(assets / path, fw, fh)
        if which is not None:
            frames = [frames[i] for i in which]
        fitted = [scale_to(f, tw, th) if scale else pad_to(f, tw, th) for f in frames]
        indexed, colors = quantize_sprite_frames(fitted)
        return indexed, colors, len(indexed), tw, th

    # Player 24x32 → 32x32, key frames.
    player_idx = [0, 1, 2, 4, 6, 10, 11, 12, 14, 15, 16]
    sheet = ObjSheet()
    pals = []
    tile = 0

    def append_spr(name: str, frames: list[Image.Image], tw: int, th: int, pal: list[tuple[int, int, int]], new_band: bool = True):
        nonlocal tile
        if new_band:
            sheet.start_actor(th)
        bases = [sheet.add_frame(fr, tw, th) for fr in frames]
        pals.append(pal)
        meta[f"SPR_{name}_TILE"] = bases[0]
        meta[f"SPR_{name}_FRAMES"] = len(frames)
        meta[f"SPR_{name}_W"] = tw
        meta[f"SPR_{name}_H"] = th
        meta[f"SPR_{name}_STRIDE"] = tw // 8
        tile = sheet.n_rows * 16

    d, pal, n, tw, th = take("sprites/daniel.png", 24, 32, 32, 32, player_idx)
    append_spr("PLAYER", d, tw, th, pal)
    d, pal, n, tw, th = take("sprites/enemy_walker.png", 24, 24, 32, 32, None)
    append_spr("WALKER", d, tw, th, pal)
    d, pal, n, tw, th = take("sprites/enemy_flyer.png", 16, 16, 16, 16, None)
    append_spr("FLYER", d, tw, th, pal)
    d, pal, n, tw, th = take("sprites/coin.png", 16, 16, 16, 16, [0, 2])
    append_spr("COIN", d, tw, th, pal, new_band=False)
    d, pal, n, tw, th = take("sprites/enemy_fast.png", 16, 16, 16, 16, None)
    append_spr("FAST", d, tw, th, pal, new_band=False)
    d, pal, n, tw, th = take("sprites/enemy_tank.png", 24, 24, 32, 32, None)
    append_spr("TANK", d, tw, th, pal)
    d, pal, n, tw, th = take("sprites/boss.png", 48, 48, 48, 48, None)
    append_spr("BOSS", d, tw, th, pal)
    # 64×64 castle as four 32×32 quadrants (fits OBJ VRAM $6000–$7FFF).
    raw, pal, n, tw, th = take("sprites/castle.png", 80, 56, 64, 64, [0], scale=True)
    big = raw[0]
    quads = [
        big.crop((0, 0, 32, 32)),
        big.crop((32, 0, 64, 32)),
        big.crop((0, 32, 32, 64)),
        big.crop((32, 32, 64, 64)),
    ]
    append_spr("CASTLE", quads, 32, 32, pal)

    spr_chr = sheet.to_bytes()
    if tile > 512:
        raise SystemExit(f"OBJ sheet {tile} tiles exceeds 512 (VRAM $6000-$7FFF)")
    (out / "sprites.chr").write_bytes(spr_chr)
    meta["SPRITE_CHR_BYTES"] = len(spr_chr)
    meta["SPRITE_TILE_COUNT"] = tile
    print(f"sprites: rows={sheet.n_rows} tiles={tile} bytes={len(spr_chr)}")

    # Palettes blob: BG1 tileset (16) + 8 sprite pals (16 each, first 8 used) + slot for BG2
    pal_blob = bytearray()
    pal_blob += palette_bytes(ts_colors, 16)  # CGRAM $00 BG1
    # CGRAM $10 will be filled per-stage from bg pals; placeholder
    pal_blob += palette_bytes([(0, 0, 0)] * 16, 16)
    pal_blob += palette_bytes([(0, 0, 0), (255, 255, 255), (255, 220, 80), (40, 40, 40)], 16)  # BG3
    for pal in pals:
        pal_blob += palette_bytes(pal, 16)
    while len(pals) < 8:
        pal_blob += palette_bytes([(0, 0, 0)] * 16, 16)
        pals.append([(0, 0, 0)] * 16)
    (out / "shared_pal.bin").write_bytes(bytes(pal_blob[: 16 * 2 * 3]))  # BG1 + dummy BG2 + BG3
    spr_pal = bytearray()
    for pal in pals[:8]:
        spr_pal += palette_bytes(pal, 16)
    (out / "sprite_pal.bin").write_bytes(bytes(spr_pal))

    # Backgrounds 256x224 → 32x28 tiles, 16 colors, identity map, palette 1.
    bg_names = [f"bg_stage{i}.png" for i in range(1, 6)] + ["menu_bg.png"]
    out_names = [f"bg{i}" for i in range(1, 6)] + ["menu"]
    bg_lens = []
    for src_name, dst in zip(bg_names, out_names):
        # Keep the title-screen source in the repository so it is reproducible
        # even when the original Java asset folder is not mounted.
        local_menu = Path(__file__).resolve().parent.parent / "assets" / "menu_bg.png"
        source = local_menu if dst == "menu" and local_menu.exists() else assets / "textures" / src_name
        im = Image.open(source).convert("RGB")
        if dst == "menu":
            im = crop_dark_margins(im)
        im = im.resize((256, 224), Image.Resampling.NEAREST)
        if dst == "menu" and local_menu.exists():
            # A photo can generate almost one unique tile per 8x8 block.
            # Pixelating at 128x112 keeps the image inside the SNES tile budget
            # while the final framebuffer remains the native 256x224 size.
            im = im.resize((128, 112), Image.Resampling.BILINEAR)
            im = im.resize((256, 224), Image.Resampling.NEAREST)
        q, colors = quantize_opaque(im, 16)
        chr_data, tilemap, ntiles = image_to_unique_4bpp(q, max_tiles=700)
        (out / f"{dst}.chr").write_bytes(chr_data)
        (out / f"{dst}.map").write_bytes(tilemap)
        (out / f"{dst}.pal").write_bytes(palette_bytes(colors, 16))
        bg_lens.append(len(chr_data))
        print(f"{dst}: unique={ntiles} chr={len(chr_data)} map={len(tilemap)}")
    for i, n in enumerate(bg_lens[:5], 1):
        meta[f"BG{i}_CHR_BYTES"] = n
    meta["MENU_CHR_BYTES"] = bg_lens[5]

    end_im = Image.open(assets / "textures" / "ending_bg.jpg").convert("RGB")
    # 8:7 already; crop sky so faces and the joke bubble fill 256x224.
    ew, eh = end_im.size
    cw, ch = 400, 350
    left = max(0, (ew - cw) // 2)
    top = max(0, eh - ch - 8)
    end_im = end_im.crop((left, top, left + cw, top + ch))
    end_im = end_im.resize((256, 224), Image.Resampling.LANCZOS)
    end_im = ImageEnhance.Contrast(end_im).enhance(1.12)
    end_q, end_colors = quantize_opaque(end_im, 16)
    end_chr, end_map, end_ntiles = image_to_unique_4bpp(end_q, max_tiles=752, nearest=True)
    (out / "ending.chr").write_bytes(end_chr)
    (out / "ending.map").write_bytes(end_map)
    (out / "ending.pal").write_bytes(palette_bytes(end_colors, 16))
    veil = [(int(r * 0.45), int(g * 0.45), int(b * 0.45)) for r, g, b in end_colors]
    (out / "ending_veil.pal").write_bytes(palette_bytes(veil, 16))
    meta["ENDING_CHR_BYTES"] = len(end_chr)
    print(f"ending: unique={end_ntiles} chr={len(end_chr)}")

    font_chr, mapping, font_m7 = make_font_chr()
    (out / "font.chr").write_bytes(font_chr)
    (out / "font_m7.bin").write_bytes(font_m7)
    meta["FONT_TILE_COUNT"] = len(font_chr) // 16
    meta["FONT_M7_BYTES"] = len(font_m7)
    (out / "fontmap.inc").write_text(
        "; glyph -> tile\n"
        + "".join(
            f".DEFINE FONT_{'SPC' if ch == ' ' else (ch if ch.isalnum() else 'X' + str(ord(ch)))} {idx}\n"
            for ch, idx in mapping.items()
            if ch.isalnum() or ch in " <>:/'!"
        )
    )

    sine = bytes((int(round(math.sin(i * 2 * math.pi / 256) * 20)) & 0xFF) for i in range(256))
    (out / "sine.bin").write_bytes(sine)

    meta["TILESET_CHR_BYTES"] = 8 * 4 * 32
    meta["BG_MAP_BYTES"] = 32 * 32 * 2
    meta["STAGE_COUNT"] = 5
    meta["MAP_ROWS"] = 14
    for k, n in [
        ("PLAYER_IDLE0", 0),
        ("PLAYER_IDLE1", 1),
        ("PLAYER_WALK0", 2),
        ("PLAYER_WALK1", 3),
        ("PLAYER_RUN", 4),
        ("PLAYER_JUMP", 5),
        ("PLAYER_FALL", 6),
        ("PLAYER_CROUCH", 7),
        ("PLAYER_HURT", 8),
        ("PLAYER_DEAD", 9),
        ("PLAYER_WIN", 10),
    ]:
        meta[f"PL_{k}"] = n

    # String tables as raw font tile ids, 32 bytes each, $FF terminated not needed if fixed.
    strings = {
        "STR_TITLE1": "DANIEL DO BOLO",
        "STR_TITLE2": "ADVENTURE",
        "STR_START": "PRESS START",
        "STR_CREDIT": "BY FABIO AD",
        "STR_PAUSA": "PAUSA",
        "STR_OVER": "GAME OVER",
        "STR_WIN": "VOCE VENCEU",
        "STR_HUD1": "DANIEL X",
        "STR_PEIXES": "PEIXES",
        "STR_PONTOS": "PONTOS",
        "STR_FASE": "FASE",
        "STR_TEMPO": "TEMPO",
        "STR_NOVO": "NOVO JOGO",
        "STR_SAIR": "SAIR",
        "STR_MFASE": "FASE: 0",
        "STR_MVIDAS": "VIDAS: 0",
        "STR_HINTADJ": "ESQ/DIR AJUSTAR",
        "STR_HINTGO": "START CONFIRMA",
        "STR_SONHO": "O SONHO",
    }
    str_bin = bytearray()
    str_off = {}
    for name, text in strings.items():
        str_off[name] = len(str_bin)
        line = encode_text_line(text, mapping, 32)
        str_bin += bytes(line)
    (out / "strings.bin").write_bytes(bytes(str_bin))
    for name, off in str_off.items():
        meta[name] = off

    streets_bin, n_streets, scroll_end = pack_street_lines(mapping)
    (out / "streets.bin").write_bytes(streets_bin)
    meta["STREET_COUNT"] = n_streets
    meta["STREET_SCROLL_END"] = scroll_end

    story_lines = ["", "O SONHO", ""] + wrap_paragraph(ENDING_STORY, 28)
    story_bin, n_story, story_end = pack_ending_lines(mapping, story_lines)
    (out / "ending_story.bin").write_bytes(story_bin)
    meta["END_STORY_COUNT"] = n_story
    meta["END_STORY_SCROLL_END"] = story_end

    cred_lines: list[str] = []
    for line in ENDING_CREDITS:
        wrapped = wrap_paragraph(line, 30) if line else [""]
        cred_lines.extend(wrapped if wrapped else [""])
    cred_bin, n_cred, cred_end = pack_ending_lines(mapping, cred_lines)
    (out / "ending_credits.bin").write_bytes(cred_bin)
    meta["END_CREDITS_COUNT"] = n_cred
    meta["END_CREDITS_SCROLL_END"] = cred_end
    meta["END_SCORE_LINE"] = n_cred - 1
    meta["END_SCORE_COL"] = 17

    m7_hdma = make_m7_hdma()
    (out / "m7persp.bin").write_bytes(m7_hdma)
    meta["M7_HDMA_BYTES"] = len(m7_hdma)
    print(f"streets: lines={n_streets} bytes={len(streets_bin)} scroll_end={scroll_end}")
    print(f"ending story={n_story} credits={n_cred} scroll={story_end}/{cred_end}")
    print(f"mode7 font={len(font_m7)} hdma={len(m7_hdma)}")

    write_meta(out / "meta.inc", **meta)
    # Also dump a small C-like report
    (out / "README.txt").write_text(
        "Generated SNES assets for Daniel do Bolo Adventure.\n"
        f"Sprite 8x8 tiles: {tile}\n"
        f"Sprite CHR bytes: {len(spr_chr)}\n"
        f"Stages packed: {sum(len(b) for b in blobs)} bytes\n"
    )
    print(f"wrote {out}  sprite_tiles={tile}  spr_chr={len(spr_chr)}")


if __name__ == "__main__":
    main()
