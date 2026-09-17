#!/usr/bin/env python3
"""Apply each theme in the original Burda APK and sample its three colors.

Drives the app on a booted emulator: taps a theme swatch in Settings, goes to
Home, screenshots, and reads the deep colour (bottom nav), the light colour
(stats card) and the dark colour (body text) out of the pixels.
"""

import collections
import subprocess
import sys
from PIL import Image

SCREENS = "/home/x3kk3x/Desktop/Burda/recovery/screens"

# Original-image coordinates (1080x2340).
SWATCHES = {
    "pink": (330, 1271),
    "green": (703, 1271),
    "purple": (330, 1391),
    "blue": (703, 1391),
    "red": (330, 1512),
    "orange": (703, 1512),
    "mellon": (330, 1633),
    "maroon": (703, 1633),
}
NAV_HOME = (150, 2237)
NAV_SETTINGS = (925, 2237)
THEME_ARROW = (960, 1115)
PINK_SWATCH_PROBE = (330, 1271)

NAV_SAMPLE = (250, 2240)
CARD_SAMPLE = (120, 830)
CARD_REGION = (60, 700, 1020, 1140)  # left, top, right, bottom


def adb(*args):
    return subprocess.run(
        ["adb", *args], capture_output=True, text=True, check=True
    ).stdout


def tap(point):
    adb("shell", "input", "tap", str(point[0]), str(point[1]))


def sleep(seconds):
    adb("shell", "sleep", str(seconds))


def screencap(path):
    with open(path, "wb") as handle:
        subprocess.run(["adb", "exec-out", "screencap", "-p"], stdout=handle, check=True)


def hexof(rgb):
    return "#{:02X}{:02X}{:02X}".format(*rgb[:3])


def luminance(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def sample(path):
    """deep = nav bar, light = card fill, dark = darkest frequent text pixel."""
    image = Image.open(path).convert("RGB")
    deep = image.getpixel(NAV_SAMPLE)
    light = image.getpixel(CARD_SAMPLE)

    counts = collections.Counter(image.crop(CARD_REGION).getdata())
    # Text pixels are the darkest colour that still covers a real glyph area.
    frequent = [rgb for rgb, count in counts.items() if count > 200]
    dark = min(frequent, key=luminance) if frequent else (0, 0, 0)
    return deep, light, dark


def theme_list_open():
    """True when the Theme section is expanded (a swatch is under the probe)."""
    screencap(f"{SCREENS}/tmp-probe.png")
    pixel = Image.open(f"{SCREENS}/tmp-probe.png").convert("RGB").getpixel(PINK_SWATCH_PROBE)
    return luminance(pixel) < 235  # white page background if collapsed


def main():
    results = {}
    for name, swatch in SWATCHES.items():
        if not theme_list_open():
            tap(THEME_ARROW)
            sleep(1)
            if not theme_list_open():
                print(f"could not open the theme list before {name}", file=sys.stderr)
                return 1

        tap(swatch)
        sleep(1)
        tap(NAV_HOME)
        sleep(2)
        path = f"{SCREENS}/theme-{name}.png"
        screencap(path)
        deep, light, dark = sample(path)
        results[name] = (deep, light, dark)
        print(
            f"{name:7} deep {hexof(deep)}  light {hexof(light)}  dark {hexof(dark)}",
            flush=True,
        )

        tap(NAV_SETTINGS)
        sleep(2)

    print("\n// recovered palettes")
    for name, (deep, light, dark) in results.items():
        print(
            f"'{name}': Palette(deep: Color(0xFF{hexof(deep)[1:]}), "
            f"dark: Color(0xFF{hexof(dark)[1:]}), "
            f"light: Color(0xFF{hexof(light)[1:]})),"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
