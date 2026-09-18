#!/usr/bin/env python3
"""Resize the bundled covers to what a phone can actually show.

The covers came out of the original APK at up to 1773px wide, while the app
never draws one wider than about 830px. This resizes anything wider than
MAX_WIDTH and re-encodes as progressive JPEG, which roughly halves the size
of the app with no visible difference on a phone.

The originals stay in git history and in the APK under recovery/apk.

Pass --dry-run to see the numbers without touching anything.
"""

import json
import os
import sys
from PIL import Image

COVERS = "/home/x3kk3x/Desktop/Burda/assets/covers"
MANIFEST = "/home/x3kk3x/Desktop/Burda/assets/magazines.json"
MAX_WIDTH = 900
QUALITY = 82


def main(dry_run: bool) -> int:
    renames: dict[str, str] = {}
    before = after = 0

    for name in sorted(os.listdir(COVERS)):
        path = os.path.join(COVERS, name)
        before += os.path.getsize(path)

        with Image.open(path) as image:
            image = image.convert("RGB")
            if image.width > MAX_WIDTH:
                height = round(image.height * MAX_WIDTH / image.width)
                image = image.resize((MAX_WIDTH, height), Image.LANCZOS)

            # One cover shipped as a PNG. Everything becomes a JPEG so the
            # set is consistent, and the manifest is updated to match.
            target_name = f"{os.path.splitext(name)[0]}.jpg"
            target = os.path.join(COVERS, target_name)
            if target_name != name:
                renames[name] = target_name

            if not dry_run:
                image.save(
                    target, "JPEG", quality=QUALITY, optimize=True, progressive=True
                )
                if target_name != name:
                    os.remove(path)

        after += os.path.getsize(target) if not dry_run else 0

    if renames and not dry_run:
        with open(MANIFEST) as handle:
            entries = json.load(handle)
        for entry in entries:
            name = entry["image"].split("/")[-1]
            if name in renames:
                entry["image"] = f"covers/{renames[name]}"
        with open(MANIFEST, "w") as handle:
            json.dump(entries, handle, indent=2)
            handle.write("\n")
        print(f"manifest updated for: {', '.join(renames)}")

    print(f"before {before / 1e6:.1f} MB")
    if not dry_run:
        print(f"after  {after / 1e6:.1f} MB  ({(before - after) / 1e6:.1f} MB saved)")
    return 0


if __name__ == "__main__":
    sys.exit(main("--dry-run" in sys.argv))
