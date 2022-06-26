#!/usr/bin/env python3
"""Generate the Double-Slit Lab app icon set."""
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "DoubleSlitLab", "Resources", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(OUT, exist_ok=True)

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# Deep-blue background with a soft radial lift behind the optical axis.
bg = Image.new("RGB", (S, S), (6, 10, 18))
pix = bg.load()
for y in range(S):
    for x in range(S):
        dx = (x - 520) / 720.0
        dy = (y - 470) / 720.0
        r = min(1.0, math.hypot(dx, dy))
        v = int(28 * (1.0 - r) ** 2.2)
        pix[x, y] = (6 + v // 2, 11 + v, 19 + int(v * 1.5))

mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=218, fill=255)
img.paste(bg, (0, 0), mask)

draw = ImageDraw.Draw(img)

# Optical table.
draw.rounded_rectangle((86, 724, 938, 790), radius=28, fill=(22, 29, 40, 255))
draw.rounded_rectangle((86, 724, 938, 742), radius=14, fill=(39, 49, 65, 255))
for x in (154, 870):
    draw.rounded_rectangle((x - 24, 790, x + 24, 884), radius=18, fill=(16, 21, 30, 255))

# Laser head.
draw.rounded_rectangle((108, 560, 300, 674), radius=42, fill=(35, 43, 56, 255))
draw.rounded_rectangle((112, 567, 244, 667), radius=36, fill=(48, 57, 73, 255))
draw.ellipse((268, 577, 321, 657), fill=(73, 84, 102, 255))
draw.ellipse((281, 590, 309, 644), fill=(255, 74, 80, 255))

# Beam and diffraction fan.
beam_glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
gd = ImageDraw.Draw(beam_glow)
gd.line((304, 617, 492, 617), fill=(255, 55, 62, 230), width=16)
gd.polygon([(486, 617), (958, 350), (958, 884)], fill=(255, 52, 62, 38))
beam_glow = beam_glow.filter(ImageFilter.GaussianBlur(12))
img.alpha_composite(beam_glow)
draw.line((304, 617, 492, 617), fill=(255, 112, 116, 255), width=6)
draw.line((304, 615, 492, 615), fill=(255, 228, 228, 255), width=2)

# Slit plate and its two openings.
draw.rounded_rectangle((474, 284, 536, 892), radius=24, fill=(129, 140, 158, 255))
draw.rounded_rectangle((480, 290, 530, 886), radius=20, fill=(63, 73, 90, 255))
for cy in (474, 616):
    draw.rounded_rectangle((484, cy - 56, 526, cy + 12), radius=20, fill=(5, 9, 15, 255))
    draw.rounded_rectangle((486, cy - 53, 524, cy + 7), radius=18, fill=(8, 14, 24, 255))

# Detector screen.
screen_glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(screen_glow)
for i in range(22):
    t = i / 21.0
    x = 604 + t * 338
    envelope = math.exp(-((t - 0.48) ** 2) / 0.20)
    intensity = (0.5 + 0.5 * math.cos(t * math.pi * 14.0)) ** 2
    alpha = int(240 * intensity * envelope)
    if alpha <= 2:
        continue
    band = 12
    sd.rectangle((x - band / 2, 330, x + band / 2, 870), fill=(255, 40 + int(60 * (1 - t)), 55, alpha))
screen_glow = screen_glow.filter(ImageFilter.GaussianBlur(10))
img.alpha_composite(screen_glow)

# Screen frame.
draw.rounded_rectangle((586, 268, 976, 912), radius=30, outline=(127, 139, 158, 235), width=14)
draw.rounded_rectangle((598, 280, 964, 900), radius=22, outline=(23, 31, 44, 255), width=8)

# Central bright fringe, plus crisp screen edge.
draw.rounded_rectangle((586, 268, 976, 912), radius=30, outline=(125, 139, 159, 140), width=3)

# Subtle diagonal glass highlight.
sheen = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sh = ImageDraw.Draw(sheen)
sh.polygon([(76, 0), (400, 0), (170, 1024), (0, 1024), (0, 720)], fill=(255, 255, 255, 8))
sheen = sheen.filter(ImageFilter.GaussianBlur(40))
img.alpha_composite(sheen)

# Re-apply the rounded mask.
img.putalpha(ImageChops.multiply(img.getchannel("A"), mask))

sizes = [16, 32, 64, 128, 256, 512, 1024]
for size in sizes:
    resized = img.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(os.path.join(OUT, f"icon_{size}x{size}.png"))

contents = {
    "images": [
        {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
        {"filename": "icon_32x32.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
        {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
        {"filename": "icon_64x64.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
        {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
        {"filename": "icon_256x256.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
        {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
        {"filename": "icon_512x512.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
        {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
        {"filename": "icon_1024x1024.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
    ],
    "info": {"author": "xcode", "version": 1},
}
with open(os.path.join(OUT, "Contents.json"), "w", encoding="utf-8") as f:
    json.dump(contents, f, indent=2)
with open(os.path.join(ROOT, "DoubleSlitLab", "Resources", "Assets.xcassets", "Contents.json"), "w", encoding="utf-8") as f:
    json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)

print("Wrote app icon set to", OUT)
