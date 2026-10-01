# Branding

Public product name is **Lyra**. Vendor is **Quad4**. Internal id is `lyra` (`MOZ_APP_NAME`).

The Void Browser name is already used by [glebschkv/voidbrowser](https://github.com/glebschkv/voidbrowser) (Rust/Tauri privacy browser) and [wyrexdev/void](https://github.com/wyrexdev/void) (experimental engine). Quad4 is the vendor brand. Display strings, desktop Name, and `MOZ_APP_DISPLAYNAME` are Lyra. Binary, profile directory, remoting name, and app id are `lyra`.

Artwork comes from https://quad4.io/branding.

## Colors

| Token | Hex |
| --- | --- |
| Void canvas | `#0A0A0B` |
| Void raised | `#16161A` |
| Paper | `#fafafa` |

Wordmark assets still use Space Mono uppercase **VOID** / **QUAD4** lockups. Chrome product strings come from `brand.ftl` (`-brand-*-name = Lyra`).

## Layout

```
branding/void/
  assets/           original Quad4 mark, lockups, favicon, OG
  fonts/            Space Mono Bold (OFL) used to rasterize VOID
  firefox/          copied to browser/branding/void
  generate-icons.py regenerate PNG/ICO from SVG
```

`scripts/apply-overlay.sh` copies `branding/void/firefox` onto the Firefox tree.

On Firefox 153 ESR, `configure.sh` may only set `MOZ_APP_DISPLAYNAME` and `MOZ_MACBUNDLE_ID`. Setting `MOZ_APP_VENDOR` there fails configure with `can not be set by confvars`. Overlay edits `browser/moz.configure` instead (`MOZ_APP_VENDOR=Quad4`, `MOZ_APP_PROFILE=lyra`, Lyra app id).

## Generated now

- Linux GTK icons `default16.png` through `default256.png` (transparent mark)
- `about-logo.svg` transparent Quad4 mark (`context-fill` for policies/settings)
- Private-browsing logos on raised `#16161A`
- `firefox.ico`, `firefox64.ico`, `document.ico`, `pbmode.ico`
- Windows VisualElements 70/150
- Installer BMP placeholders
- VOID wordmark PNG (Space Mono Bold, tracking)

## Remaining icon work

These are **not** produced by `generate-icons.py` yet. They block polished macOS / Windows installer builds, not the Linux GTK binary.

| File | Platform | Notes |
| --- | --- | --- |
| `firefox.icns` | macOS | Multi-resolution iconset. Use `iconutil` on macOS. |
| `document.icns` | macOS | Document type icon. |
| `disk.icns` | macOS | DMG volume icon. |
| `Assets.car` | macOS | Compiled asset catalog. Needs Xcode. |
| `dsstore` | macOS | DMG window layout. |
| High-quality `document.ico` | Windows | Current file is a simple page + mark. |
| Signed stub installer assets | Windows | Needs Quad4 cert + NSIS pass. |
| Wordmark SVG paths | all | `about-wordmark.svg` still uses live text. Convert to outlines so about:dialog does not depend on Space Mono being installed. |
| `void-lockup-on-dark.png` spacing | all | Composite can be tightened to match quad4.io/branding. |

Do not drop Mozilla official artwork into this directory. Do not set `-brand-product-name` to Firefox.

## Regenerating

```
python3 branding/void/generate-icons.py
```

Needs `rsvg-convert` and ImageMagick `convert`.
