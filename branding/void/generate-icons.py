#!/usr/bin/env python3
# Copyright Quad4. Icon generation for Void Firefox branding.
# Rasterizes Quad4 mark + Space Mono wordmark into Firefox branding files.

"""Generate Firefox branding raster assets from Quad4 source art."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
FIREFOX = ROOT / "firefox"
CONTENT = FIREFOX / "content"
FONT = ROOT / "fonts" / "SpaceMono-Bold.ttf"

CANVAS = "#0A0A0B"
RAISED = "#16161A"
PAPER = "#FAFAFA"

MARK_PATHS = """
    <path d="M 0.10097 -0.97999 L 0.09859 -0.69728 L 0.39556 -0.52385 L 0.09859 -0.35517 L 0.09859 -0.11522 L 0.83983 -0.54286 Z"/>
    <path d="M -0.09859 -0.97762 L -0.83745 -0.54523 L -0.10097 -0.11760 L -0.09622 -0.35517 L -0.39081 -0.52385 L -0.09622 -0.69728 Z"/>
    <path d="M -0.86121 -0.49059 L -0.86121 0.36943 L -0.62363 0.23163 L -0.62126 -0.10810 L -0.32666 0.06533 L -0.11285 -0.05821 Z"/>
    <path d="M 0.86121 -0.49059 L 0.11998 -0.05821 L 0.33142 0.06533 L 0.62363 -0.10572 L 0.62601 0.23163 L 0.86121 0.36705 Z"/>
    <path d="M 0.07008 0.19362 L 0.07008 0.98237 L 0.79231 0.54761 L 0.56424 0.41219 L 0.26252 0.59750 L 0.26014 0.30291 Z"/>
    <path d="M -0.07008 0.19600 L -0.25777 0.30291 L -0.26014 0.59750 L -0.56186 0.41219 L -0.78993 0.54761 L -0.07008 0.97999 Z"/>
"""

LINUX_SIZES = (16, 22, 24, 32, 48, 64, 128, 256)
ICO_SIZES = (16, 32, 48, 64, 128, 256)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def rsvg(svg: Path, png: Path, width: int, height: int | None = None) -> None:
    height = height or width
    png.parent.mkdir(parents=True, exist_ok=True)
    run(
        [
            "rsvg-convert",
            "-w",
            str(width),
            "-h",
            str(height),
            "-o",
            str(png),
            str(svg),
        ]
    )


def convert(*args: str) -> None:
    run(["convert", *args])


def mark_svg(size: int, *, fill: str, background: str | None, pad: float = 0.78) -> str:
    bg = (
        f'<rect width="{size}" height="{size}" fill="{background}"/>'
        if background
        else ""
    )
    scale = size * pad / 2.0
    cx = size / 2.0
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  {bg}
  <g transform="translate({cx} {cx}) scale({scale})" fill="{fill}" fill-rule="nonzero">
    {MARK_PATHS}
  </g>
</svg>
"""


def document_svg(size: int) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 32 32">
  <rect width="32" height="32" fill="none"/>
  <rect x="5" y="3" width="18" height="26" rx="1.5" fill="{PAPER}"/>
  <polygon points="17,3 23,9 17,9" fill="#E6E6E6"/>
  <g transform="translate(14 19) scale(7)" fill="{CANVAS}" fill-rule="nonzero">
    {MARK_PATHS}
  </g>
</svg>
"""


def render_wordmark(path: Path, text: str, fill: str, width: int, height: int, pointsize: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    run(
        [
            "convert",
            "-background",
            "none",
            "-fill",
            fill,
            "-font",
            str(FONT),
            "-pointsize",
            str(pointsize),
            "-kerning",
            "12",
            f"label:{text}",
            "-gravity",
            "center",
            "-extent",
            f"{width}x{height}",
            str(path),
        ]
    )


def ico_from_pngs(pngs: list[Path], dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    convert(*[str(p) for p in pngs], str(dest))


def main() -> int:
    if not shutil.which("rsvg-convert") or not shutil.which("convert"):
        print("need rsvg-convert and ImageMagick convert", file=sys.stderr)
        return 1
    if not FONT.is_file():
        print(f"missing font {FONT}", file=sys.stderr)
        return 1

    tmp = ROOT / ".gen-tmp"
    if tmp.exists():
        shutil.rmtree(tmp)
    tmp.mkdir()

    try:
        transparent = tmp / "mark-transparent.svg"
        on_canvas = tmp / "mark-canvas.svg"
        on_raised = tmp / "mark-raised.svg"
        on_paper = tmp / "mark-paper.svg"
        document = tmp / "document.svg"
        write(transparent, mark_svg(1024, fill=PAPER, background=None))
        write(on_canvas, mark_svg(1024, fill=PAPER, background=CANVAS))
        write(on_raised, mark_svg(1024, fill=PAPER, background=RAISED))
        write(on_paper, mark_svg(1024, fill=CANVAS, background=PAPER))
        write(document, document_svg(1024))

        for size in LINUX_SIZES:
            rsvg(transparent, FIREFOX / f"default{size}.png", size)

        rsvg(transparent, CONTENT / "about-logo.png", 256)
        rsvg(transparent, CONTENT / "about-logo@2x.png", 512)
        rsvg(transparent, CONTENT / "about.png", 128)
        rsvg(on_raised, CONTENT / "about-logo-private.png", 256)
        rsvg(on_raised, CONTENT / "about-logo-private@2x.png", 512)

        rsvg(on_canvas, FIREFOX / "VisualElements_70.png", 70)
        rsvg(on_canvas, FIREFOX / "VisualElements_150.png", 150)
        rsvg(on_raised, FIREFOX / "PrivateBrowsing_70.png", 70)
        rsvg(on_raised, FIREFOX / "PrivateBrowsing_150.png", 150)

        rsvg(on_canvas, FIREFOX / "background.png", 650, 500)

        ico_pngs = [FIREFOX / f"default{size}.png" for size in ICO_SIZES]
        ico_from_pngs(ico_pngs, FIREFOX / "firefox.ico")
        ico_from_pngs(
            [FIREFOX / "default16.png", FIREFOX / "default32.png", FIREFOX / "default64.png"],
            FIREFOX / "firefox64.ico",
        )

        doc_pngs = []
        for size in ICO_SIZES:
            png = tmp / f"document{size}.png"
            rsvg(document, png, size)
            doc_pngs.append(png)
        ico_from_pngs(doc_pngs, FIREFOX / "document.ico")
        ico_from_pngs(doc_pngs, FIREFOX / "document_pdf.ico")
        ico_from_pngs(
            [FIREFOX / "default16.png", FIREFOX / "default32.png"],
            FIREFOX / "newtab.ico",
        )
        shutil.copy2(FIREFOX / "newtab.ico", FIREFOX / "newwindow.ico")

        pb_svg = tmp / "pb.svg"
        write(pb_svg, mark_svg(1024, fill=PAPER, background=RAISED, pad=0.7))
        pb_pngs = []
        for size in ICO_SIZES:
            png = tmp / f"pb{size}.png"
            rsvg(pb_svg, png, size)
            pb_pngs.append(png)
        ico_from_pngs(pb_pngs, FIREFOX / "pbmode.ico")

        convert(
            "-size",
            "150x57",
            f"xc:{CANVAS}",
            str(tmp / "header.png"),
        )
        rsvg(transparent, tmp / "header-mark.png", 40)
        convert(
            str(tmp / "header.png"),
            str(tmp / "header-mark.png"),
            "-gravity",
            "west",
            "-geometry",
            "+12+0",
            "-composite",
            "BMP3:" + str(FIREFOX / "wizHeader.bmp"),
        )
        shutil.copy2(FIREFOX / "wizHeader.bmp", FIREFOX / "wizHeaderRTL.bmp")
        convert(
            str(FIREFOX / "background.png"),
            "-resize",
            "164x314!",
            "BMP3:" + str(FIREFOX / "wizWatermark.bmp"),
        )

        wm_light = tmp / "void-wordmark-light.png"
        wm_dark = tmp / "void-wordmark-dark.png"
        render_wordmark(wm_light, "VOID", PAPER, 560, 80, 56)
        render_wordmark(wm_dark, "VOID", CANVAS, 560, 80, 56)
        shutil.copy2(wm_light, CONTENT / "about-wordmark.png")
        shutil.copy2(wm_dark, CONTENT / "about-wordmark-on-light.png")

        lockup = tmp / "void-lockup.svg"
        write(
            lockup,
            f"""<svg xmlns="http://www.w3.org/2000/svg" width="640" height="168" viewBox="0 0 640 168">
  <rect width="640" height="168" fill="{CANVAS}"/>
  <g transform="translate(84 84) scale(58)" fill="{PAPER}" fill-rule="nonzero">
    {MARK_PATHS}
  </g>
</svg>
""",
        )
        rsvg(lockup, tmp / "void-lockup-mark.png", 640, 168)
        convert(
            str(tmp / "void-lockup-mark.png"),
            str(wm_light),
            "-gravity",
            "west",
            "-geometry",
            "+168+0",
            "-composite",
            str(ASSETS / "void-lockup-on-dark.png"),
        )

        print("generated Firefox branding rasters under", FIREFOX)
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
