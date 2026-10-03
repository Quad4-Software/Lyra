# Lyra

Firefox ESR fork by [Quad4](https://quad4.io). Mozilla telemetry, studies, Pocket, and accounts promo are off. uBlock Origin is force-installed.

Product name: Lyra
Vendor: Quad4
Binary, profile, remoting name, and app id: `lyra`

This git repo is the overlay. It does not contain Firefox source.

Pinned base: Firefox 153.4.0esr.

## Build

Linux host with about 30 GB disk and 16 GB RAM:

```
./scripts/fetch-firefox.sh ./firefox-src
./scripts/apply-overlay.sh ./firefox-src
./extensions/ublock/fetch.sh
cd firefox-src
cat ../mozconfig ../mozconfig.linux > mozconfig
export MOZCONFIG="$PWD/mozconfig"
./mach bootstrap
./mach configure
./mach build
./mach package
../scripts/package-extras.sh ./objdir/dist/bin
./objdir/dist/bin/lyra
```

`./scripts/bootstrap-linux.sh` prints the same steps.

GitHub Actions:

- `validate.yml` on push and pull request (layout, policies, zizmor)
- `build.yml` on `v*` tags and workflow_dispatch (Linux and Windows compiles, GitHub release on tags)

## Layout

| Path | Role |
| --- | --- |
| `branding/void/` | Lyra bird mark, Quad4 vendor marks, `browser/branding/void` overlay |
| `policies/policies.json` | Enterprise policies |
| `prefs/void.cfg` | Autoconfig prefs |
| `prefs/void-overrides.cfg.example` | User overlay |
| `overlay/` | Settings pane, locales, P2P sync, desktop file |
| `extensions/ublock/` | uBlock Origin pin and fetch |
| `mozconfig` | Build flags |
| `mozconfig.linux` | Linux extras |
| `mozconfig.windows` | Windows extras |
| `patches/` | Documented source edits |
| `scripts/` | Fetch, overlay, package, CI, validate |

Product icons come from `branding/void/assets/lyra-mark.png`. `branding/void/generate-icons.py` writes the Firefox rasters, wordmarks, and SVG wrappers. Overlay directory names stay `void` (prefs, themes, branding path).

## License

Firefox overlay files: MPL-2.0.
Lyra mark and Quad4 marks: Quad4.
Space Mono: OFL-1.1.
uBlock Origin: GPL-3.0-only, fetched not vendored.

See [LICENSE](LICENSE) and [NOTICE](NOTICE).
