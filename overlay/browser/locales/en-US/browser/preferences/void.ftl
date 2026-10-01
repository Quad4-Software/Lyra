# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

pane-void-privacy-title = Lyra
    .title = Lyra

void-privacy-header =
    .heading = Lyra
    .description = Fingerprint, DNS, fonts, timezone, leak protections, and optional P2P sync. Every control can be changed. Sites stay usable unless you pick Crowd mode.

void-fingerprint-group =
    .label = Fingerprint crowd
    .description = Firefox mode uses fingerprinting protection and the stock Firefox user agent. Crowd mode turns on Resist Fingerprinting, letterboxing, and a shared user agent.

void-fingerprint-mode =
    .label = Fingerprint mode
    .aria-description = Choose how Lyra hides among other browsers

void-fingerprint-mode-firefox =
    .label = Firefox crowd
    .description = Stock Firefox user agent. Safer for site compatibility.

void-fingerprint-mode-crowd =
    .label = Crowd identical
    .description = Resist Fingerprinting. Matches LibreWolf and Mullvad. Some sites may break.

void-ua-mode =
    .label = User agent
    .aria-description = Choose the user agent string sent to websites

void-ua-mode-firefox =
    .label = Firefox default
    .description = Same platform and version string as Firefox ESR.

void-ua-mode-crowd =
    .label = Spoof crowd UA
    .description = Report the Resist Fingerprinting user agent even when RFP is off.

void-windows-group =
    .label = Window buckets
    .description = Round the inner window so fewer exact sizes leak. Letterboxing adds gray bars.

void-window-buckets =
    .label = Use window size buckets
    .description = Rounds new windows toward 1600x900 and related sizes.

void-letterboxing =
    .label = Letterbox the viewport
    .description = Adds gray bars so the page size matches a small set of buckets.

void-fonts-group =
    .label = Fonts
    .description = Bundled fonts plus font visibility limits reduce the font fingerprint. Web fonts stay on so pages still render.

void-bundled-fonts =
    .label = Load bundled fonts
    .description = Needs a restart. Compile flag --enable-bundled-fonts is on for Linux and Windows.

void-font-visibility =
    .label = Fonts websites can see

void-font-visibility-base =
    .label = Base system fonts only

void-font-visibility-langpack =
    .label = Base fonts and language packs

void-font-visibility-all =
    .label = All installed fonts

void-fonts-restrict =
    .label = Restrict extra fonts from fingerprinting
    .description = Keeps language-pack fonts in Firefox mode. Crowd mode uses the base set.

void-typing-group =
    .label = Typing and keyboard
    .description = Keyboard event spoofing and timer rounding. Lyra does not insert fake key delays, which would break typing.

void-typing-protection =
    .label = Protect typing and keyboard fingerprinting
    .description = Spoofs KeyboardEvent fields and rounds event timestamps.

void-typing-delay =
    .label = Timestamp rounding

void-typing-delay-1ms =
    .label = 1 ms (Firefox default)

void-typing-delay-20ms =
    .label = 20 ms (recommended)

void-typing-delay-100ms =
    .label = 100 ms (stronger, can feel laggy)

void-spoof-group =
    .label = Timezone and leaks
    .description = Spoof timezone to UTC, reduce audio and WebRTC leaks, and keep sensors and geolocation off unless you turn them on.

void-timezone-spoof =
    .label = Spoof timezone to UTC
    .description = Reports Atlantic/Reykjavik. Sites that show local time may be wrong.

void-audio-protection =
    .label = Protect audio fingerprinting
    .description = Spoofs AudioContext sample rate. Can affect some web audio apps.

void-webrtc-protect =
    .label = Hide local IP from WebRTC
    .description = Drops host ICE candidates. Calls still work through STUN when a server is available.

void-sensors-block =
    .label = Block device sensors and gamepads
    .description = Motion, orientation, gamepad, and related device APIs stay off.

void-geo-block =
    .label = Block geolocation
    .description = Location permission is denied unless you turn this off.

void-dns-group =
    .label = DNS over HTTPS
    .description = Default resolver is dns.sb. Fallback to native DNS stays on unless you pick DoH only.

void-doh-mode =
    .label = DNS mode
    .aria-description = Choose how DNS queries are resolved

void-doh-mode-2 =
    .label = DNS over HTTPS, dns.sb first
    .description = Uses https://doh.dns.sb/dns-query and falls back if it fails.

void-doh-mode-3 =
    .label = DNS over HTTPS only
    .description = No native DNS fallback.

void-doh-mode-5 =
    .label = Native DNS
    .description = DoH off. Uses the operating system resolver.

void-doh-advanced =
    .label = Open Firefox DNS over HTTPS settings

void-sync-group =
    .label = P2P sync
    .description = Encrypted device-to-device sync through wss://socket.quad4.io/ws. The relay only sees ciphertext. Type the same pairing code on each device. Passwords are never sent.

void-sync-enabled =
    .label = Enable P2P sync
    .description = Connects to Quad4 websocket relay. Off by default.

void-sync-tabs =
    .label = Sync open tab URLs

void-sync-bookmarks =
    .label = Sync bookmarks into a Lyra toolbar folder

void-sync-apply-tabs =
    .label = Open tabs received from paired devices
    .description = Off by default. Only https URLs, at most 10 per update.

void-sync-secret =
    .label = Pairing code
    .placeholder = LYRA-XXXX-XXXX

void-sync-pair =
    .label = Create a new pairing code

void-compat-group =
    .label = Extra privacy
    .description = Safe defaults that stay out of the way. Each one can be turned off.

void-https-only =
    .label = HTTPS-Only Mode

void-query-stripping =
    .label = Strip tracking query parameters

void-referrer =
    .label = Hide the page URL from other sites
    .description = Cross-site navigations do not send document.referrer. Same-site links still send it.

void-webgl =
    .label = Allow WebGL
    .description = Leave on. Fingerprinting protection sanitizes renderer strings.

void-eme =
    .label = Allow DRM (EME)
    .description = Off by default. Needed only for some streaming sites.

void-ocsp =
    .label = Check OCSP for certificates
    .description = Off by default (CRLite covers revocation without phoning CAs).

void-spoof-english =
    .label = Spoof English locale to websites
    .description = Can break local-language pages. Off by default.

void-restart-note =
    .message = Bundled fonts and some fingerprint targets apply after a restart.
