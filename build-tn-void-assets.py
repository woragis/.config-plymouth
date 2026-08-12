#!/usr/bin/env python3
"""Build TN Void Plymouth assets (two-step spinner compatible)."""
from __future__ import annotations

import math
import shutil
import subprocess
from pathlib import Path

THEME = Path.home() / ".config/plymouth/tn-void"
SPIN = Path("/usr/share/plymouth/themes/spinner")


def run(cmd: list[str]) -> None:
    subprocess.check_call(cmd)


def main() -> None:
    THEME.mkdir(parents=True, exist_ok=True)
    # Keep theme definition files across rebuilds
    keep = {"tn-void.plymouth", "tn-void.script"}
    for p in THEME.iterdir():
        if p.name not in keep:
            if p.is_dir():
                shutil.rmtree(p)
            else:
                p.unlink()

    for name in ("bullet.png", "entry.png", "lock.png", "capslock.png", "keyboard.png", "keymap-render.png"):
        src = SPIN / name
        if src.exists():
            shutil.copy2(src, THEME / name)

    run(
        [
            "magick",
            "-size",
            "400x80",
            "xc:none",
            "-fill",
            "#7dcfff",
            "-font",
            "DejaVu-Sans-Bold",
            "-pointsize",
            "28",
            "-gravity",
            "center",
            "-annotate",
            "+0+0",
            "orion",
            str(THEME / "watermark.png"),
        ]
    )

    gear = THEME / "_gear.png"
    run(
        [
            "magick",
            "-size",
            "256x256",
            "xc:none",
            "-fill",
            "#24283b",
            "-stroke",
            "#7dcfff",
            "-strokewidth",
            "3",
            "-draw",
            "circle 128,128 128,72",
            "-fill",
            "#0f111a",
            "-draw",
            "circle 128,128 128,32",
            "-fill",
            "#82aaff",
            "-draw",
            "circle 128,128 128,14",
            "(",
            "-size",
            "256x256",
            "xc:none",
            "-fill",
            "#565f89",
            "-stroke",
            "#bb9af7",
            "-strokewidth",
            "2",
            "-draw",
            "roundrectangle 112,4 144,52 4,4",
            ")",
            "-clone",
            "1",
            "-rotate",
            "30",
            "-clone",
            "1",
            "-rotate",
            "60",
            "-clone",
            "1",
            "-rotate",
            "90",
            "-clone",
            "1",
            "-rotate",
            "120",
            "-clone",
            "1",
            "-rotate",
            "150",
            "-clone",
            "1",
            "-rotate",
            "180",
            "-clone",
            "1",
            "-rotate",
            "210",
            "-clone",
            "1",
            "-rotate",
            "240",
            "-clone",
            "1",
            "-rotate",
            "270",
            "-clone",
            "1",
            "-rotate",
            "300",
            "-clone",
            "1",
            "-rotate",
            "330",
            "-delete",
            "1",
            "-background",
            "none",
            "-flatten",
            str(gear),
        ]
    )

    for i in range(1, 37):
        deg = (i - 1) * 10
        out = THEME / f"animation-{i:04d}.png"
        run(
            [
                "magick",
                str(gear),
                "-background",
                "none",
                "-distort",
                "SRT",
                str(deg),
                "-gravity",
                "center",
                "-background",
                "none",
                "-extent",
                "256x256",
                str(out),
            ]
        )

    for i in range(1, 31):
        r = 20 + (i * 4) % 100
        a = 0.35 + 0.65 * (i / 30)
        y = 64 - r
        y2 = 64 - r // 2
        out = THEME / f"throbber-{i:04d}.png"
        run(
            [
                "magick",
                "-size",
                "128x128",
                "xc:none",
                "-stroke",
                f"rgba(125,207,255,{a:.2f})",
                "-strokewidth",
                "3",
                "-fill",
                "none",
                "-draw",
                f"circle 64,64 64,{y}",
                "-stroke",
                "rgba(187,154,247,0.45)",
                "-strokewidth",
                "2",
                "-draw",
                f"circle 64,64 64,{y2}",
                "-fill",
                "#7dcfff",
                "-draw",
                "circle 64,64 64,6",
                str(out),
            ]
        )

    gear.unlink(missing_ok=True)
    anim = len(list(THEME.glob("animation-*.png")))
    throb = len(list(THEME.glob("throbber-*.png")))
    print(f"ok animation={anim} throbber={throb}")


if __name__ == "__main__":
    main()
