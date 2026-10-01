# Privacy defaults

Vendor autoconfig plus Firefox enterprise policies. arkenfox is a checklist. Files:

- `policies/policies.json` (enterprise policy, not locked for the new privacy controls)
- `prefs/void.cfg` (autoconfig `defaultPref` / `pref` / `lockPref`, plus fingerprint mode)
- `prefs/autoconfig.js` (loads `void.cfg`, sandbox off so overrides can run)
- `prefs/void-overrides.cfg.example` (user overlay, LibreWolf-style)
- `mozconfig` (build-time `MOZ_TELEMETRY_REPORTING=0`, no crash reporter, bundled fonts)
- Settings: **Lyra** pane in `about:preferences`

## Sources

- Mozilla policy templates: https://mozilla.github.io/policy-templates/
- LibreWolf settings: https://codeberg.org/librewolf/settings
- arkenfox user.js: https://github.com/arkenfox/user.js
- Firefox RFP targets: `toolkit/components/resistfingerprinting/RFPTargets.inc`
- dns.sb DoH: https://dns.sb/

Lyra does not vendor those files. Pref names and intent are recorded in `prefs/void.cfg`.

## Strip list (implemented as policy and/or pref)

| Extra | How |
| --- | --- |
| Telemetry, Glean usage ping, extra pings | `DisableTelemetry`, locked `toolkit.telemetry.*`, empty server |
| Studies / Shield / Normandy / Nimbus | `DisableFirefoxStudies`, locked Normandy/Nimbus prefs |
| Crash reporter phone-home | `--disable-crashreporter`, empty `breakpad.reportURL` |
| Pocket and new-tab stories | `DisablePocket`, `FirefoxHome.Pocket=false` |
| Sponsored shortcuts / MARS ads | `FirefoxHome.SponsoredTopSites`, unifiedAds prefs |
| Firefox Suggest / trending | `FirefoxSuggest`, urlbar featureGates |
| Firefox accounts / sync promo | `DisableFirefoxAccounts`, `identity.fxaccounts.enabled` default false |
| Default Mozilla bookmarks / topsites | `NoDefaultBookmarks`, empty default.sites |
| VPN / Focus / mobile app banners | locked promo prefs |
| Relay / shopping | locked shopping and relay prefs |
| AI chat / link preview / smart tab groups | locked `browser.ml.*` |
| Captive portal and connectivity checks | disabled |
| Google Safe Browsing live lists | disabled (local lists would still phone Google) |
| Mozilla remote region / UITour / what's new | disabled |
| Default Mozilla search spam | uninstall Google/Bing/Amazon/eBay/Twitter search extensions, default DuckDuckGo |

## Fingerprint modes

`void.fingerprint.mode` is a **default**, not locked. Settings > Lyra switches it live.

| Mode | What it does |
| --- | --- |
| `firefox` (default) | Fingerprinting Protection (FPP) with extra 2026 targets. Stock Firefox UA. Letterboxing off. Better site compatibility. |
| `crowd` | Full Resist Fingerprinting, letterboxing on, tighter fonts, spoofed crowd UA. LibreWolf / Mullvad style. Some sites may break. Crowd mode subtracts `CSSPrefersColorScheme` so Lyra Dark still works. |

Independent toggles (all `defaultPref`):

- Window buckets / letterboxing (`void.window.buckets`, `privacy.resistFingerprinting.letterboxing`)
- UA spoof vs Firefox default (`void.ua.mode`)
- Bundled fonts (`gfx.bundled-fonts.activate`, compile `--enable-bundled-fonts`)
- Font visibility (`layout.css.font-visibility`, `void.fonts.restrict`)
- Typing / keyboard protection (`void.typing.protection` plus timer rounding)
- Timezone spoof to UTC (`void.timezone.spoof`, FPP `JSDateTimeUTC`)
- AudioContext sample-rate spoof (`void.audio.protection`)
- WebRTC host ICE hiding (`void.webrtc.protect`, `media.peerconnection.ice.no_host`)
- Sensors / gamepad block (`void.sensors.block`)
- Geolocation block (`void.geo.block`)
- DoH mode (`network.trr.mode`)

Lyra does **not** insert fake key delays. That would stall input. Typing protection spoofs `KeyboardEvent` fields and rounds timestamps (`privacy.resistFingerprinting.reduceTimerPrecision.microseconds`, default 20 ms).

## Timezone and 2026 leak surfaces

Default FPP extras beyond Firefox Baseline:

- Timezone: `JSDateTimeUTC` (Atlantic/Reykjavik)
- Audio: `AudioSampleRate`, `AudioContext`
- WebRTC: no host candidates, default-address-only, mDNS host obfuscation
- Sensors: `DeviceSensors`, `Gamepad`, `MediaDevices`, `NetworkConnection`
- Canvas / WebGL / WebGPU / WebCodecs / PDF.js spoof already on
- Video element stats, mouse screen points, frame rate, CSS color-gamut, `window.outer` size
- Bounce tracking protection mode 1 (purge, not dry-run)
- Mozilla remote FPP overrides off so the local target list wins
- Speech synthesis / recognition, push, web notifications, WebBluetooth off
- `:visited` link styling off

Do not enable FPP `CSSPrefersColorScheme`. That spoofs light theme and fights Lyra Dark.

## DNS over HTTPS

Default is **TRR first** (`network.trr.mode` 2) with **dns.sb**:

- URI: `https://doh.dns.sb/dns-query`
- Bootstrap: `185.222.222.222`
- Native DNS fallback stays on
- Mozilla DoH rollout is off so the provider does not jump to Cloudflare or NextDNS

Policy `DNSOverHTTPS` is enabled and **not locked**. Settings > Lyra can switch to DoH-only or native DNS.

## P2P sync

Optional, off by default. `overlay/browser/modules/LyraSync.sys.mjs` opens `wss://socket.quad4.io/ws` ([Quad4-Software/websocket-server](https://github.com/Quad4-Software/websocket-server)).

The public server is a blind binary relay (`/ws`, 512 KB max). It has echo, broadcast, and log modes. P2P needs **broadcast** so paired devices see each other's frames. The server does not parse payloads and does not log client IPs.

Lyra encrypts every frame with AES-GCM. The key is HKDF-SHA-256 of a pairing code you type on each device (`LYRA-XXXX-XXXX`). The relay only sees ciphertext plus an 8-byte group tag. Passwords, history, and cookies are never sent. Tabs and bookmarks are optional. Incoming tabs do not auto-open unless you turn that on.

Private windows are skipped. The Firefox Accounts sync engine stays off.

## Startup, disk, and memory

Disk cache stays on (512 MB) so repeat loads do not sit in RAM. Cache still clears on shutdown. Content process count default is 4. Session store writes every 60s. Thumbnail capture, Firefox View, sidebar revamp, translations, and profile backup are off. Restore-on-demand is on. Accessibility is force-disabled by default (`accessibility.force_disabled` 1) and can be turned back on in `about:config`.

## What we keep for security

Remote Settings stay on so CRLite and tracking-protection lists still update. CRLite enforce mode (`security.pki.crlite_mode` 2) is on. OCSP is off by default (no CA phone-home) and can be turned on in the Lyra pane. WebGL stays on. EME stays off. HTTPS-Only Mode is on. Query stripping is on. Post-quantum TLS (`security.tls.enable_kyber`) stays on at the Firefox 153 default.

## Landlock

[Landlock](https://landlock.io/) is a stackable Linux LSM. Firefox already sandboxes content with `nsSandboxBroker`, seccomp-bpf, and user namespaces. Wrapping the Lyra process with Landlock would fight that broker: profile I/O, GPU, downloads, fonts, and content-process file access all go through paths Landlock would have to allow anyway.

Firefox 153 has no Landlock hooks. Lyra does **not** wrap the browser with Landlock. Do not add an outer `landlock` exec around `lyra`.

## What we do not add

Lyra does not set a telemetry endpoint. `toolkit.telemetry.server` is `data:,`. CI fails if `telemetry.mozilla.org` appears in prefs or policies.

## User overrides

Most behavior is `defaultPref` so Settings and `about:config` stick. `lockPref` is reserved for telemetry, studies, and nag surfaces.

`general.config.sandbox_enabled` is false so `void.cfg` can apply fingerprint modes and load a user file, same idea as LibreWolf `librewolf.overrides.cfg`. Copy `prefs/void-overrides.cfg.example` to one of:

- `$VOID_OVERRIDES`
- `$LYRA_OVERRIDES`
- `~/.lyra/void-overrides.cfg`
- `~/.void/void-overrides.cfg`
- `void-overrides.cfg` next to the binary
