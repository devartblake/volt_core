"""Regenerates every launcher icon, splash image and store graphic for Volt Core.

Logo: "B. Core Ring" (disc, ring, core, lightning bolt). It is drawn from its
geometry with Pillow (supersampled), not from the SVG files, so nothing but
Pillow is needed.

Usage (from the project root):
    python -I tool/make_app_icons.py            generate everything, then check it
    python -I tool/make_app_icons.py --check    only validate the existing files

Writes to android/app/src/main/res, ios/Runner/Assets.xcassets, web/ and
docs/branding/store. See docs/tools.md.
"""
import json
import math
import os
import sys
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS_ICONS = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
IOS_LAUNCH = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "LaunchImage.imageset")
WEB = os.path.join(ROOT, "web")
STORE = os.path.join(ROOT, "docs", "branding", "store")

NAVY = "#103078"
DEEP = "#0A1F4D"
GREY_LIGHT = "#C9CED6"
GREY_MID = "#8B93A1"
PALE = "#E4E9F3"
WHITE = "#FFFFFF"

# Geometry in a 512 box.
DISC_R, RING_R, RING_W, CORE_R = 224, 188, 12, 160
BOLT = [(292, 60), (150, 282), (238, 282), (206, 452), (364, 226), (274, 226)]
BOLT_SCALE = 0.62
SS = 4  # supersampling factor

DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}


def bolt_points():
    return [(256 + BOLT_SCALE * (x - 256), 256 + BOLT_SCALE * (y - 256)) for x, y in BOLT]


def logo_layer(canvas, disc_diam, mono=False):
    """Transparent canvas x canvas RGBA with the dark-variant logo centred.

    disc_diam is the outer diameter of the logo disc in output pixels.
    mono=True draws only the ring and bolt in solid white (themed icons).
    """
    big = canvas * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    u = disc_diam * SS / (2 * DISC_R)  # pixels per box unit
    c = big / 2.0

    def circle(r, **kw):
        d.ellipse([c - r * u, c - r * u, c + r * u, c + r * u], **kw)

    def poly():
        return [(c + (x - 256) * u, c + (y - 256) * u) for x, y in bolt_points()]

    if mono:
        circle(RING_R + RING_W / 2, fill=WHITE)
        circle(RING_R - RING_W / 2, fill=(0, 0, 0, 0))
        d.polygon(poly(), fill=WHITE)
        # The core hole between ring and bolt must stay transparent; the
        # inner circle above is cleared, so the bolt is drawn last.
    else:
        circle(DISC_R, fill=PALE)
        circle(RING_R + RING_W / 2, fill=GREY_MID)
        circle(RING_R - RING_W / 2, fill=PALE)
        circle(CORE_R, fill=DEEP)
        d.polygon(poly(), fill=WHITE)
    return img.resize((canvas, canvas), Image.LANCZOS)


def tile(size, radius_frac=0.0, color=DEEP):
    """Solid colour square, optionally with rounded corners (transparent outside)."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, big - 1, big - 1], radius=radius_frac * big, fill=color)
    return img.resize((size, size), Image.LANCZOS)


def icon_on_tile(size, disc_frac, radius_frac):
    img = tile(size, radius_frac)
    img.alpha_composite(logo_layer(size, round(size * disc_frac)))
    return img


def save(img, path, opaque=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        flat = Image.new("RGB", img.size, DEEP)
        flat.paste(img, mask=img.split()[3])
        flat.save(path)
    else:
        img.save(path)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


# ---------------------------------------------------------------- Android

def make_android():
    for name, scale in DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{name}")
        # Legacy icon (API < 26): 22% rounded deep-navy tile, disc = 78% of tile.
        save(icon_on_tile(round(48 * scale), 0.78, 0.22), os.path.join(folder, "ic_launcher.png"))
        # Adaptive layers: 108dp canvas, logo disc = 66dp (safe zone).
        cv = round(108 * scale)
        disc = round(66 * scale)
        save(logo_layer(cv, disc), os.path.join(folder, "ic_launcher_foreground.png"))
        save(logo_layer(cv, disc, mono=True), os.path.join(folder, "ic_launcher_monochrome.png"))
        # Splash icon: 288dp canvas, logo disc in the central 192dp circle.
        save(logo_layer(round(288 * scale), round(192 * scale)),
             os.path.join(RES, f"drawable-{name}", "splash_icon.png"))

    write(os.path.join(RES, "values", "ic_launcher_background.xml"),
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          f'    <color name="ic_launcher_background">{DEEP}</color>\n</resources>\n')
    write(os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher.xml"),
          '<?xml version="1.0" encoding="utf-8"?>\n'
          '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <background android:drawable="@color/ic_launcher_background"/>\n'
          '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
          '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
          '</adaptive-icon>\n')

    launch = ('<?xml version="1.0" encoding="utf-8"?>\n'
              '<!-- Pre-Android 12 launch screen: deep navy with the centred logo.\n'
              '     Generated by tool/make_app_icons.py (splash_icon bitmaps). -->\n'
              '<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n'
              '    <item android:drawable="@color/ic_launcher_background" />\n'
              '    <item>\n'
              '        <bitmap\n'
              '            android:gravity="center"\n'
              '            android:src="@drawable/splash_icon" />\n'
              '    </item>\n'
              '</layer-list>\n')
    write(os.path.join(RES, "drawable", "launch_background.xml"), launch)
    write(os.path.join(RES, "drawable-v21", "launch_background.xml"), launch)

    def v31(parent):
        return ('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <!-- Android 12+ system splash screen. -->\n'
                f'    <style name="LaunchTheme" parent="{parent}">\n'
                '        <item name="android:windowBackground">@drawable/launch_background</item>\n'
                '        <item name="android:windowSplashScreenBackground">@color/ic_launcher_background</item>\n'
                '        <item name="android:windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>\n'
                '    </style>\n</resources>\n')
    write(os.path.join(RES, "values-v31", "styles.xml"), v31("@android:style/Theme.Light.NoTitleBar"))
    write(os.path.join(RES, "values-night-v31", "styles.xml"), v31("@android:style/Theme.Black.NoTitleBar"))


# -------------------------------------------------------------------- iOS

def make_ios():
    cj = os.path.join(IOS_ICONS, "Contents.json")
    if not os.path.isfile(cj):
        return
    with open(cj, encoding="utf-8") as f:
        data = json.load(f)
    for im in data["images"]:
        fn = im.get("filename")
        if not fn:
            continue
        base = float(im["size"].split("x")[0])
        px = round(base * int(im["scale"].rstrip("x")))
        # Full-bleed square (iOS applies its own corner mask), no alpha.
        save(icon_on_tile(px, 0.72, 0.0), os.path.join(IOS_ICONS, fn), opaque=True)
    # Launch image: logo on transparent, the storyboard background is navy.
    for fn, s in (("LaunchImage.png", 1), ("LaunchImage@2x.png", 2), ("LaunchImage@3x.png", 3)):
        w, h = 168 * s, 185 * s
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        lg = logo_layer(w, round(w * 0.9))
        img.alpha_composite(lg, (0, (h - w) // 2))
        save(img, os.path.join(IOS_LAUNCH, fn))
    sb = os.path.join(ROOT, "ios", "Runner", "Base.lproj", "LaunchScreen.storyboard")
    if os.path.isfile(sb):
        with open(sb, encoding="utf-8") as f:
            text = f.read()
        old = '<color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>'
        new = '<color key="backgroundColor" red="0.0392" green="0.1216" blue="0.3020" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>'
        if old in text:
            write(sb, text.replace(old, new))


# -------------------------------------------------------------------- Web

def make_web():
    if not os.path.isdir(WEB):
        return
    if os.path.isfile(os.path.join(WEB, "favicon.png")):
        save(icon_on_tile(32, 0.84, 0.22), os.path.join(WEB, "favicon.png"))
    for s in (192, 512):
        save(icon_on_tile(s, 0.78, 0.22), os.path.join(WEB, "icons", f"Icon-{s}.png"))
        # Maskable: full bleed, logo inside the 80% safe circle (disc = 66%).
        save(icon_on_tile(s, 0.66, 0.0), os.path.join(WEB, "icons", f"Icon-maskable-{s}.png"), opaque=True)


# ------------------------------------------------------------------ Store

def font(size):
    for p in ("C:/Windows/Fonts/arialbd.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.isfile(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def make_store():
    save(icon_on_tile(512, 0.74, 0.0), os.path.join(STORE, "icon-512.png"), opaque=True)

    w, h = 1024, 500
    img = Image.new("RGBA", (w, h), DEEP)
    disc = 300
    img.alpha_composite(logo_layer(disc + 40, disc), (70, (h - disc - 40) // 2))
    d = ImageDraw.Draw(img)
    d.text((430, 170), "Volt Core", font=font(92), fill=WHITE)
    d.text((434, 290), "Generator inspections, maintenance", font=font(30), fill=GREY_LIGHT)
    d.text((434, 332), "and inventory", font=font(30), fill=GREY_LIGHT)
    img.convert("RGB").save(os.path.join(STORE, "feature-graphic-1024x500.png"))


# ---------------------------------------------------------------- Preview

def mask_for(shape, size):
    big = size * SS
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)
    if shape == "circle":
        d.ellipse([0, 0, big - 1, big - 1], fill=255)
    elif shape == "rounded":
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=0.22 * big, fill=255)
    else:  # squircle (superellipse, n = 4)
        pts = []
        for i in range(720):
            t = 2 * math.pi * i / 720
            c, s = math.cos(t), math.sin(t)
            x = math.copysign(abs(c) ** 0.5, c)
            y = math.copysign(abs(s) ** 0.5, s)
            pts.append(((x + 1) / 2 * (big - 1), (y + 1) / 2 * (big - 1)))
        d.polygon(pts, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def adaptive_preview(shape, size, mono=False):
    cv = 108 * 4
    if mono:
        bg = Image.new("RGBA", (cv, cv), GREY_LIGHT)
        fg = logo_layer(cv, 66 * 4, mono=True)
        # Themed icons tint the layer; show it in navy on a pale tile.
        tinted = Image.new("RGBA", fg.size, NAVY)
        tinted.putalpha(fg.split()[3])
        fg = tinted
    else:
        bg = Image.new("RGBA", (cv, cv), DEEP)
        fg = logo_layer(cv, 66 * 4)
    bg.alpha_composite(fg)
    # Visible window is the central 72dp of the 108dp layers.
    m = (cv - 72 * 4) // 2
    vis = bg.crop((m, m, cv - m, cv - m)).resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(vis, mask=mask_for(shape, size))
    return out


def make_preview():
    size, pad, label_h = 160, 28, 34
    items = [("Legacy", icon_on_tile(size, 0.78, 0.22)),
             ("Adaptive circle", adaptive_preview("circle", size)),
             ("Adaptive squircle", adaptive_preview("squircle", size)),
             ("Adaptive rounded", adaptive_preview("rounded", size)),
             ("Monochrome", adaptive_preview("circle", size, mono=True))]
    w = pad + len(items) * (size + pad)
    sheet = Image.new("RGBA", (w, size + 2 * pad + label_h), "#F2F4F8")
    d = ImageDraw.Draw(sheet)
    f = font(16)
    for i, (label, im) in enumerate(items):
        x = pad + i * (size + pad)
        sheet.alpha_composite(im, (x, pad))
        tw = d.textlength(label, font=f)
        d.text((x + (size - tw) / 2, pad + size + 10), label, font=f, fill="#4B5363")
    os.makedirs(STORE, exist_ok=True)
    sheet.convert("RGB").save(os.path.join(STORE, "icon-preview.png"))


# ------------------------------------------------------------------ Check

def check():
    problems = []

    def png(path, w, h=None, opaque=False):
        h = h or w
        if not os.path.isfile(path):
            problems.append(f"missing {os.path.relpath(path, ROOT)}")
            return
        try:
            with Image.open(path) as im:
                im.load()
                if im.size != (w, h):
                    problems.append(f"{os.path.relpath(path, ROOT)}: {im.size}, expected {(w, h)}")
                if opaque and ("A" in im.getbands()):
                    problems.append(f"{os.path.relpath(path, ROOT)}: has alpha")
        except Exception as e:  # noqa: BLE001
            problems.append(f"{path}: {e}")

    for name, scale in DENSITIES.items():
        m = os.path.join(RES, f"mipmap-{name}")
        png(os.path.join(m, "ic_launcher.png"), round(48 * scale))
        png(os.path.join(m, "ic_launcher_foreground.png"), round(108 * scale))
        png(os.path.join(m, "ic_launcher_monochrome.png"), round(108 * scale))
        png(os.path.join(RES, f"drawable-{name}", "splash_icon.png"), round(288 * scale))

    # XML well-formed and every @resource reference resolves.
    xmls = [os.path.join(RES, p) for p in (
        "mipmap-anydpi-v26/ic_launcher.xml", "values/ic_launcher_background.xml",
        "values-v31/styles.xml", "values-night-v31/styles.xml",
        "drawable/launch_background.xml", "drawable-v21/launch_background.xml",
        "values/styles.xml", "values-night/styles.xml")]
    for p in xmls:
        try:
            root = ET.parse(p).getroot()
        except Exception as e:  # noqa: BLE001
            problems.append(f"{p}: {e}")
            continue
        for el in root.iter():
            for val in list(el.attrib.values()) + [el.text or ""]:
                val = val.strip()
                if not val.startswith("@") or val.startswith("@android:"):
                    continue
                kind, _, rname = val[1:].partition("/")
                found = False
                for dirpath, _, files in os.walk(RES):
                    folder = os.path.basename(dirpath)
                    if folder.split("-")[0] == kind and any(os.path.splitext(f)[0] == rname for f in files):
                        found = True
                        break
                if not found and kind == "color":
                    found = os.path.isfile(os.path.join(RES, "values", "ic_launcher_background.xml")) and \
                        rname == "ic_launcher_background"
                if not found:
                    problems.append(f"{os.path.relpath(p, ROOT)}: unresolved {val}")
    man = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
    with open(man, encoding="utf-8") as f:
        if "@mipmap/ic_launcher" not in f.read():
            problems.append("AndroidManifest.xml does not use @mipmap/ic_launcher")

    cj = os.path.join(IOS_ICONS, "Contents.json")
    if os.path.isfile(cj):
        with open(cj, encoding="utf-8") as f:
            for im in json.load(f)["images"]:
                if im.get("filename"):
                    px = round(float(im["size"].split("x")[0]) * int(im["scale"].rstrip("x")))
                    png(os.path.join(IOS_ICONS, im["filename"]), px, opaque=True)
    if os.path.isdir(WEB):
        if os.path.isfile(os.path.join(WEB, "favicon.png")):
            png(os.path.join(WEB, "favicon.png"), 32)
        for s in (192, 512):
            png(os.path.join(WEB, "icons", f"Icon-{s}.png"), s)
            png(os.path.join(WEB, "icons", f"Icon-maskable-{s}.png"), s, opaque=True)
    png(os.path.join(STORE, "icon-512.png"), 512, opaque=True)
    png(os.path.join(STORE, "feature-graphic-1024x500.png"), 1024, 500)
    if not os.path.isfile(os.path.join(STORE, "icon-preview.png")):
        problems.append("missing icon-preview.png")

    if problems:
        print("PROBLEMS:")
        for p in problems:
            print("  " + p)
        return 1
    print("All icon files present, correct size, XML well-formed, resources resolve.")
    return 0


def main():
    if "--check" not in sys.argv:
        make_android()
        make_ios()
        make_web()
        make_store()
        make_preview()
        print("Generated. Preview: docs/branding/store/icon-preview.png")
    return check()


if __name__ == "__main__":
    sys.exit(main())
