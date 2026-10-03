<h1>
  <img src="branding/void/assets/lyra-mark.png" alt="" width="48" height="48" align="absmiddle">
  Lyra
</h1>

Firefox ESR fork by [Quad4](https://quad4.io). This git repo is the overlay. It does not contain Firefox source.

Pinned base: Firefox 153.4.0esr.

## Features

| Feature | Detail |
| --- | --- |
| Engine | Firefox 153.4.0esr |
| uBlock Origin | Force-installed 1.75.0, AMO updates on |
| Telemetry | Mozilla telemetry, studies, Pocket, and accounts promo off |
| Search | Brave Search. Google, Bing, Amazon, eBay, and Twitter engines removed |
| DNS | DNS over HTTPS via dns.sb, native fallback on |
| Fingerprint | Firefox crowd by default. Optional Resist Fingerprinting mode |
| Tracking | Strict blocking, Global Privacy Control, HTTPS-Only, query stripping |
| DRM | Encrypted Media Extensions off |
| WebRTC | Local IPs hidden (no host ICE candidates) |
| LAN | Public pages cannot probe private or loopback addresses |
| Sync | Optional encrypted P2P via `wss://socket.quad4.io/ws`, off by default |

Every control in the settings pane can be changed. Crowd mode is the one that will break some sites.

## Build

About 30 GB disk and 16 GB RAM. From this repo:

```
podman build --output type=local,dest=out .
```

Writes `out/lyra-<version>-linux-x86_64.tar.xz`. To keep the toolchain image and open a shell instead:

```
podman build --target build -t lyra-build .
podman run --rm -it lyra-build bash
```

Host without a container:

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

## License

Firefox overlay files: MPL-2.0.
Lyra mark and Quad4 marks: Quad4.
Space Mono: OFL-1.1.
uBlock Origin: GPL-3.0-only, fetched not vendored.

See [LICENSE](LICENSE) and [NOTICE](NOTICE).
