"""Generate the Android and iOS launcher icons without external packages."""

import json
import math
from pathlib import Path
import struct
import subprocess
import zlib


ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
pixels = bytearray(SIZE * SIZE * 3)


def blend(x, y, color, alpha=1.0):
    if not (0 <= x < SIZE and 0 <= y < SIZE) or alpha <= 0:
        return
    at = (y * SIZE + x) * 3
    for channel, value in enumerate(color):
        pixels[at + channel] = round(
            pixels[at + channel] * (1 - alpha) + value * alpha
        )


def rounded_rect(left, top, right, bottom, radius, color, opacity=1.0):
    center_x = (left + right) / 2
    center_y = (top + bottom) / 2
    half_w = (right - left) / 2 - radius
    half_h = (bottom - top) / 2 - radius
    for y in range(max(0, top - 2), min(SIZE, bottom + 2)):
        for x in range(max(0, left - 2), min(SIZE, right + 2)):
            qx = abs(x + 0.5 - center_x) - half_w
            qy = abs(y + 0.5 - center_y) - half_h
            distance = (
                math.hypot(max(qx, 0), max(qy, 0))
                + min(max(qx, qy), 0)
                - radius
            )
            blend(x, y, color, max(0, min(1, 0.5 - distance)) * opacity)


def circle(center_x, center_y, radius, color):
    for y in range(max(0, center_y - radius - 2), min(SIZE, center_y + radius + 2)):
        for x in range(max(0, center_x - radius - 2), min(SIZE, center_x + radius + 2)):
            distance = math.hypot(x + 0.5 - center_x, y + 0.5 - center_y)
            blend(x, y, color, max(0, min(1, radius + 0.5 - distance)))


def stroke(x1, y1, x2, y2, width, color):
    dx = x2 - x1
    dy = y2 - y1
    length_sq = dx * dx + dy * dy
    left = max(0, int(min(x1, x2) - width))
    right = min(SIZE, int(max(x1, x2) + width + 2))
    top = max(0, int(min(y1, y2) - width))
    bottom = min(SIZE, int(max(y1, y2) + width + 2))
    for y in range(top, bottom):
        for x in range(left, right):
            projection = ((x - x1) * dx + (y - y1) * dy) / length_sq
            t = max(0, min(1, projection))
            distance = math.hypot(x - (x1 + t * dx), y - (y1 + t * dy))
            blend(x, y, color, max(0, min(1, width / 2 + 0.5 - distance)))


def chunk(tag, data):
    return (
        struct.pack('>I', len(data))
        + tag
        + data
        + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = b''.join(
        b'\x00' + pixels[y * SIZE * 3 : (y + 1) * SIZE * 3]
        for y in range(SIZE)
    )
    image = (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(rows, 9))
        + chunk(b'IEND', b'')
    )
    path.write_bytes(image)


def resize(master, destination, size):
    subprocess.run(
        ['sips', '-z', str(size), str(size), str(master), '--out', str(destination)],
        check=True,
        capture_output=True,
    )


for y in range(SIZE):
    for x in range(SIZE):
        shade = (x + y) / (2 * SIZE)
        at = (y * SIZE + x) * 3
        pixels[at : at + 3] = bytes(
            (round(18 + shade * 13), round(63 + shade * 29), round(58 + shade * 21))
        )

rounded_rect(249, 181, 790, 864, 93, (3, 31, 29), 0.22)
rounded_rect(226, 158, 767, 841, 93, (250, 250, 243))
circle(341, 305, 29, (232, 125, 98))
rounded_rect(402, 286, 662, 318, 16, (24, 76, 69))
rounded_rect(326, 390, 661, 421, 15, (172, 197, 184))
stroke(396, 496, 512, 612, 37, (18, 63, 58))
stroke(628, 496, 512, 612, 37, (18, 63, 58))
stroke(512, 594, 512, 744, 39, (18, 63, 58))
stroke(417, 643, 607, 643, 34, (18, 63, 58))
stroke(417, 695, 607, 695, 34, (18, 63, 58))
circle(747, 755, 102, (232, 125, 98))
stroke(695, 754, 733, 790, 25, (255, 255, 255))
stroke(733, 790, 805, 718, 25, (255, 255, 255))

master = ROOT / 'assets' / 'app_icon.png'
write_png(master)

android_sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
}
for density, size in android_sizes.items():
    resize(
        master,
        ROOT / 'android' / 'app' / 'src' / 'main' / 'res' / f'mipmap-{density}' / 'ic_launcher.png',
        size,
    )

icon_dir = ROOT / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
manifest = json.loads((icon_dir / 'Contents.json').read_text())
for image in manifest['images']:
    width = float(image['size'].split('x')[0])
    scale = int(image['scale'][0])
    size = round(width * scale)
    resize(master, icon_dir / image['filename'], size)

print('Generated mobile launcher icons from assets/app_icon.png')
