#!/usr/bin/env python3
"""Run the app at several screen sizes and look for layout overflow.

Flutter paints a yellow and black striped banner wherever a widget overflows in
a debug build, so counting bright yellow pixels finds those without reading
every screenshot by hand.
"""

import subprocess
import sys
from PIL import Image

PACKAGE = "com.x3kk.burda"
ACTIVITY = f"{PACKAGE}/{PACKAGE}.MainActivity"
OUT = "/home/x3kk3x/Desktop/Burda/recovery/screens/sizes"

# name, width, height, density
SIZES = [
    ("small", 720, 1280, 320),
    ("tall", 1080, 2400, 440),
    ("wide", 1440, 2560, 480),
]

# Bottom bar destinations as fractions of the screen.
NAV = {
    "home": 0.14,
    "years": 0.71,
    "settings": 0.86,
}
NAV_Y = 0.925


def adb(*args, out=None):
    return subprocess.run(["adb", *args], capture_output=out is None, text=True)


def shell(command):
    return adb("shell", *command.split())


def sleep(seconds):
    adb("shell", "sleep", str(seconds))


def screencap(path):
    with open(path, "wb") as handle:
        subprocess.run(["adb", "exec-out", "screencap", "-p"], stdout=handle, check=True)


def overflow_pixels(path):
    """Rows that are mostly bright yellow: the overflow banner spans the width.

    Counting single yellow pixels is not enough, since a couple of the app's
    own icons are yellow.
    """
    image = Image.open(path).convert("RGB")
    pixels = image.load()
    sampled = range(0, image.width, 4)
    rows = 0
    for y in range(image.height):
        yellow = sum(
            1
            for x in sampled
            if pixels[x, y][0] > 220 and pixels[x, y][1] > 200 and pixels[x, y][2] < 80
        )
        if yellow > len(sampled) * 0.3:
            rows += 1
    return rows


def main():
    failures = []

    def capture(name, screen, width):
        path = f"{OUT}/{name}-{screen}.png"
        screencap(path)
        rows = overflow_pixels(path)
        if rows > 2:
            failures.append((name, screen, rows))
        status = "OVERFLOW" if rows > 2 else "ok"
        print(f"{name:6} {screen:12} {status} ({rows} banner rows)", flush=True)

    for name, width, height, density in SIZES:
        print(f"--- {name}: {width}x{height} @ {density}", flush=True)
        shell(f"wm size {width}x{height}")
        shell(f"wm density {density}")
        shell(f"am force-stop {PACKAGE}")
        shell(f"am start -n {ACTIVITY}")
        sleep(7)
        capture(name, "home", width)

        def tap(fx, fy):
            adb("shell", "input", "tap", str(int(width * fx)), str(int(height * fy)))
            sleep(3)

        tap(NAV["years"], NAV_Y)
        capture(name, "years", width)

        # A year listing, opened from the middle of the year list.
        tap(0.5, 0.5)
        capture(name, "year-listing", width)
        shell("input keyevent 4")
        sleep(2)

        tap(NAV["settings"], NAV_Y)
        capture(name, "settings", width)

        # The add dialog, from the dress in the middle of the bar.
        tap(0.5, NAV_Y)
        capture(name, "add-dialog", width)
        shell("input keyevent 4")
        sleep(2)

    shell("wm size reset")
    shell("wm density reset")

    if failures:
        print("\nOverflow found:")
        for name, screen, pixels in failures:
            print(f"  {name} {screen}: {pixels} banner rows")
        return 1
    print("\nNo overflow at any size.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
