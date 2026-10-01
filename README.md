# Lyra

Firefox ESR fork by [Quad4](https://quad4.io). Mozilla telemetry, studies, Pocket, and accounts promo are off. uBlock Origin is force-installed.

Product name: Lyra
Vendor: Quad4
Binary, profile, remoting name, and app id: `lyra`

This git repo is the overlay. It does not contain Firefox source.

Pinned base: Firefox 153.3.0esr.

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

`./scripts/bootstrap-linux.sh` prints the same steps. Details: [docs/BUILD.md](docs/BUILD.md).

GitHub Actions:

- `validate.yml` on push and pull request (layout, policies, zizmor)
- `build-linux.yml` on `v*` tags and workflow_dispatch (full compile, uploads `lyra-*-linux-x86_64.tar.xz`)

Windows CI checks the overlay only. It does not compile Firefox.

## Layout

| Path | Role |
| --- | --- |
| `branding/void/` | Icons and `browser/branding/void` overlay |
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
| `docs/` | Build, branding, privacy, ESR bumps |

## License

Firefox overlay files: MPL-2.0.
Quad4 marks: Quad4.
Space Mono: OFL-1.1.
uBlock Origin: GPL-3.0-only, fetched not vendored.

See [LICENSE](LICENSE) and [NOTICE](NOTICE).
