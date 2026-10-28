#!/usr/bin/env python3
"""Composes the README media from frames recorded by
test/render/readme_media_test.dart.

    python3 tool/readme_media.py <frames dir> docs/media

Each clip becomes an animated WebP card: the recorded block on a warm
Monokai surface with an accent glow, rounded and lifted on a soft shadow,
a slow camera push, and a loop that cross-fades its end into its start.
The banner is a still: the name and three screens fanned out.
"""
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / 'assets' / 'fonts'
SURFACE = (42, 39, 32)
SURFACE_DEEP = (28, 26, 21)
INK = (250, 247, 240)
MUTED = (186, 178, 160)
ACCENT = {
    'pink': (254, 86, 133),
    'orange': (253, 151, 31),
    'yellow': (255, 216, 102),
    'green': (166, 226, 46),
    'cyan': (102, 217, 239),
    'lavender': (171, 157, 242),
}

# clip: (index, accent, kind, logical crop override)
CLIPS = {
    'lobby': ('01', 'pink', 'phone', None),
    'rage': ('02', 'pink', 'block', None),
    'bard': ('03', 'orange', 'block', None),
    'wind': ('04', 'yellow', 'block', None),
    'volley': ('05', 'lavender', 'block', None),
    'druid': ('06', 'green', 'block', None),
    'cast': ('07', 'cyan', 'block', (0, 176, 390, 668)),
    'climb': ('08', 'cyan', 'phone', None),
    'dice': ('09', 'yellow', 'block', None),
    'history': ('10', 'pink', 'phone', None),
}
FPS = 30
SCALE = 2  # frames are recorded at twice the logical size


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


def ease(t):
    return 0.5 - 0.5 * math.cos(math.pi * max(0.0, min(1.0, t)))


def backdrop(w, h, accent):
    """Warm surface, a vertical fall-off and two soft accent glows."""
    bg = Image.new('RGB', (w, h), SURFACE)
    grad = Image.linear_gradient('L').resize((w, h))
    deep = Image.new('RGB', (w, h), SURFACE_DEEP)
    bg = Image.composite(deep, bg, grad)
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    r = int(w * 0.62)
    d.ellipse((w - r, -r // 2, w + r // 2, r), fill=accent + (92,))
    r2 = int(w * 0.45)
    d.ellipse((-r2 // 2, h - r2, r2, h + r2 // 2), fill=accent + (40,))
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.16))
    bg = bg.convert('RGBA')
    bg.alpha_composite(glow)
    return bg


def rounded(img, radius):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius, fill=255)
    out = img.convert('RGBA')
    out.putalpha(ImageChops.multiply(out.getchannel('A'), mask))
    return out, mask


def shadow_for(mask, accent, blur, spread_alpha=150):
    """A dark lift shadow and an accent under-glow for a rounded shape."""
    pad = blur * 3
    w, h = mask.size
    canvas = Image.new('RGBA', (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    dark = Image.new('RGBA', mask.size, (0, 0, 0, spread_alpha))
    dark.putalpha(mask.point(lambda v: v * spread_alpha // 255))
    canvas.alpha_composite(dark, (pad, pad + blur // 2))
    tint = Image.new('RGBA', mask.size, accent + (70,))
    tint.putalpha(mask.point(lambda v: v * 70 // 255))
    canvas.alpha_composite(tint, (pad, pad + blur))
    return canvas.filter(ImageFilter.GaussianBlur(blur)), pad


def chip(text, accent):
    """The index chip: the accent outline of the app's peek titles."""
    f = font('Rubik-SemiBold.ttf', 26)
    tw = f.getbbox(text)[2]
    w, h = tw + 36, 46
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, w - 1, h - 1), h // 2, fill=accent + (36,), outline=accent + (160,), width=2)
    d.text((18, h // 2), text, font=f, fill=accent + (255,), anchor='lm')
    return img


def frames_of(clip_dir):
    return sorted(p for p in clip_dir.glob('*.png'))


def crop_rect(clip_dir, override):
    if override:
        l, t, w, h = override
    else:
        meta = clip_dir / 'crop.json'
        if not meta.exists():
            return None
        c = json.loads(meta.read_text())
        l, t, w, h = c['l'], c['t'], c['w'], c['h']
    pad = 6
    return (int((l - pad) * SCALE), int((t - pad) * SCALE), int((l + w + pad) * SCALE), int((t + h + pad) * SCALE))


def compose_clip(name, frames_dir, out_dir, work):
    index, accent_name, kind, override = CLIPS[name]
    accent = ACCENT[accent_name]
    clip_dir = frames_dir / name
    frames = frames_of(clip_dir)
    if not frames:
        print(f'skip {name}: no frames')
        return
    first = Image.open(frames[0])
    if kind == 'phone':
        W, H = 760, 1040
        box = (0, 0, first.width, first.height)
        target_h = H - 150
        radius = 52
    else:
        W, H = 760, 760
        box = crop_rect(clip_dir, override) or (0, 0, first.width, first.height)
        target_h = None
        radius = 40
    bw, bh = box[2] - box[0], box[3] - box[1]
    if kind == 'phone':
        s = target_h / bh
    else:
        s = min((W - 110) / bw, (H - 170) / bh)
    sw, sh = int(bw * s), int(bh * s)
    _, mask = rounded(Image.new('RGB', (sw, sh)), radius)
    if kind != 'phone':
        # The block's lower edge dissolves: the sheet goes on below it.
        fade = Image.linear_gradient('L').resize((sw, 70)).transpose(Image.FLIP_TOP_BOTTOM)
        edge = Image.new('L', (sw, sh), 255)
        edge.paste(fade, (0, sh - 70))
        mask = ImageChops.multiply(mask, edge)
    shadow, pad = shadow_for(mask, accent, 34)
    base = backdrop(W, H, accent)
    label = chip(index, accent)
    # A hairline that frames the screen like glass.
    rim = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
    ImageDraw.Draw(rim).rounded_rectangle((0, 0, sw - 1, sh - 1), radius, outline=(255, 255, 255, 26), width=2)
    if kind == 'phone':
        bezel = Image.new('RGBA', (sw + 24, sh + 24), (0, 0, 0, 0))
        ImageDraw.Draw(bezel).rounded_rectangle((0, 0, sw + 23, sh + 23), radius + 12, fill=(17, 16, 13, 255), outline=(255, 255, 255, 30), width=2)
    ox = (W - sw) // 2
    oy = 112 if kind != 'phone' else 110
    if kind != 'phone':
        oy = 112 + max(0, (H - 140 - sh) // 2 - 10)

    rendered = []
    n = len(frames)
    for i, path in enumerate(frames):
        t = i / max(1, n - 1)
        frame = Image.open(path).convert('RGB').crop(box).resize((sw, sh), Image.LANCZOS)
        ui = frame.convert('RGBA')
        ui.alpha_composite(rim)
        ui.putalpha(mask)
        # A slow camera push: a little closer and a little higher.
        push = 1 + 0.03 * ease(t)
        lift = -10 * ease(t)
        pw, ph = int(sw * push), int(sh * push)
        canvas = base.copy()
        shx = ox - pad - (pw - sw) // 2
        shy = int(oy - pad + lift) - (ph - sh) // 2
        canvas.alpha_composite(shadow.resize((shadow.width + pw - sw, shadow.height + ph - sh)), (shx, shy))
        x = ox - (pw - sw) // 2
        y = int(oy + lift) - (ph - sh) // 2
        if kind == 'phone':
            canvas.alpha_composite(bezel.resize((pw + 24, ph + 24)), (x - 12, y - 12))
        canvas.alpha_composite(ui.resize((pw, ph), Image.LANCZOS), (x, y))
        canvas.alpha_composite(label, (40, 40))
        rendered.append(canvas.convert('RGB'))
    # Loop: the last frames dissolve into the first ones.
    blend = min(14, n // 4)
    for k in range(blend):
        a = (k + 1) / (blend + 1)
        rendered[n - blend + k] = Image.blend(rendered[n - blend + k], rendered[k], a)
    tmp = work / name
    tmp.mkdir(parents=True, exist_ok=True)
    for i, im in enumerate(rendered):
        im.save(tmp / f'{i:04d}.png')
    out = out_dir / f'{name}.webp'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS), '-i', str(tmp / '%04d.png'),
                    '-c:v', 'libwebp_anim', '-quality', '78', '-compression_level', '6', '-loop', '0',
                    str(out)], check=True)
    print(f'{name}: {out.stat().st_size // 1024} KB, {n} frames')


def banner(frames_dir, out_dir):
    W, H = 1680, 760
    pink = ACCENT['pink']
    bg = backdrop(W, H, pink)
    glow2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow2).ellipse((W * 0.52, H * 0.2, W * 1.05, H * 1.3), fill=ACCENT['cyan'] + (40,))
    bg.alpha_composite(glow2.filter(ImageFilter.GaussianBlur(160)))
    d = ImageDraw.Draw(bg)
    d.text((110, 250), 'QD&D', font=font('Rubik-SemiBold.ttf', 168), fill=INK, anchor='ls')
    d.text((116, 318), 'Roleplay companion for D&D 5e', font=font('Inter-SemiBold.ttf', 40), fill=MUTED, anchor='ls')
    x = 116
    for text, accent in [('Flutter', 'cyan'), ('RU · EN', 'yellow'), ('Offline', 'green'), ('12 classes · 1–20', 'pink')]:
        c = chip(text, ACCENT[accent])
        bg.alpha_composite(c, (x, 370))
        x += c.width + 12
    d.text((116, 470), 'A living character sheet: every ability is an', font=font('Inter-Medium.ttf', 30), fill=MUTED)
    d.text((116, 512), 'instrument you touch, roll and watch respond.', font=font('Inter-Medium.ttf', 30), fill=MUTED)
    shots = [frames_dir / 'lobby' / '0000.png', frames_dir / 'shots' / 'sheet.png', frames_dir / 'shots' / 'magic.png']
    placed = [(1035, 150, -7, pink), (1250, 96, 0, ACCENT['cyan']), (1462, 150, 7, ACCENT['lavender'])]
    for path, (cx, cy, angle, accent) in reversed(list(zip(shots, placed))):
        if not path.exists():
            continue
        shot = Image.open(path).convert('RGB')
        h = 520
        w = int(shot.width * h / shot.height)
        shot = shot.resize((w, h), Image.LANCZOS)
        ui, mask = rounded(shot, 34)
        bez = Image.new('RGBA', (w + 16, h + 16), (0, 0, 0, 0))
        ImageDraw.Draw(bez).rounded_rectangle((0, 0, w + 15, h + 15), 42, fill=(17, 16, 13, 255), outline=(255, 255, 255, 32), width=2)
        bez.alpha_composite(ui, (8, 8))
        sh, pad = shadow_for(bez.getchannel('A'), accent, 30)
        layer = Image.new('RGBA', (sh.width, sh.height), (0, 0, 0, 0))
        layer.alpha_composite(sh)
        layer.alpha_composite(bez, (pad, pad))
        layer = layer.rotate(-angle, resample=Image.BICUBIC, expand=True)
        bg.alpha_composite(layer, (cx - layer.width // 2, cy - pad // 2))
    out = out_dir / 'banner.png'
    bg.convert('RGB').save(out, optimize=True)
    print(f'banner: {out.stat().st_size // 1024} KB')


def main():
    frames_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[3].split(',')) if len(sys.argv) > 3 else None
    with tempfile.TemporaryDirectory() as tmp:
        for name in CLIPS:
            if only is None or name in only:
                compose_clip(name, frames_dir, out_dir, Path(tmp))
    if only is None or 'banner' in only:
        banner(frames_dir, out_dir)


if __name__ == '__main__':
    main()
