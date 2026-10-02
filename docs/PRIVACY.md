# Lyra privacy and security notes

Design notes for the protections Lyra ships, what is still open, and why.

## Local network intrusion blocking

Lyra enables Firefox's Local Network Access (LNA) enforcement and goes
further than stock:

    network.lna.enabled                  true (upstream default in ESR153)
    network.lna.blocking                 true
    network.lna.block_trackers           true  (Lyra: trackers always denied)
    network.lna.block_insecure_contexts  true  (Lyra: http pages too)
    network.lna.websocket.enabled        true  (Lyra: cover ws:// to LAN)

Enforcement lives in the HTTP transaction layer
(netwerk/protocol/http/nsHttpTransaction.cpp) and rejects public -> private
and public/private -> loopback transitions, with a permission prompt when
allowed. The "block LAN intrusions" toggle in Settings is `void.lan.block`.

Why: Meta (Facebook/Instagram apps, 2024-06-2025) and Yandex (since 2017)
probed localhost ports from web content to link web identities to app
accounts (the "Bridges to Self" / localmess research). Meta used STUN/SDP
munging to a local UDP listener; Yandex ran an HTTP server on known ports.

WebRTC residual: loopback UDP socket binds are refused by
media.peerconnection.ice.loopback=false, which kills Meta's STUN-to-localhost
path at the socket level. Private (non-loopback) STUN targets are a
thinner slice; SDP munging of ice-ufrag/ice-pwd is not separately rejected
the way Chrome 137+ does it.

## Script blocking (NoScript-lite)

`void.js.mode` drives nsIDomainPolicy in LyraScriptBlock.sys.mjs:

- off: no blocking
- denylist: sites in void.js.blocklist cannot run any JS (inline or
  external, including workers)
- allowlist: only sites in void.js.allowlist run JS

Domain policies propagate to content processes via DomainPolicyClone, so
this is the same mechanism Firefox uses internally, not a shim.

## CDN resource substitution (Decentraleyes-lite)

Entries in the webcompat system addon's AVAILABLE_SHIMS redirect requests
for pinned CDN library versions (jQuery 3.7.1/3.6.0/3.5.1/2.2.4/1.12.4,
Underscore 1.13.6) on ajax.googleapis.com, code.jquery.com,
cdnjs.cloudflare.com and cdn.jsdelivr.net to bundled byte-identical copies
in browser/extensions/webcompat/shims/lyra-*. The CDN never sees the
request, and since the bytes are identical, subresource integrity still
passes. Unmatched versions fall through to the network normally.

Extending coverage means vendoring more versioned files and adding match
entries. There is no remote update channel for file payloads, so the set
grows with releases only.

## Tracking parameter stripping (ClearURLs-lite)

`privacy.query_stripping.enabled` is on for normal and private windows plus
strip-on-share, with an extended space-separated list in
`privacy.query_stripping.strip_list` (click IDs, utm variants, platform
campaign params). Firefox merges the pref list with the remote settings
query-stripping collection.

Not implemented vs full ClearURLs: per-site exception rules, redirector
skipping, hyperlink auditing beyond browser.send_pings=false, and ETag
cache tracking defense. The param list covers the common cases.

## Profile storage encryption

`security.storage.encryption.sqlite.enabled` is unlocked in our build and
opt-in via Settings. When enabled, Firefox encrypts every SQLite database
under the profile (cookies.sqlite, places.sqlite, etc.) through the
ObfuscatingVFS layer with per-database keys in lockstore. This is the same
protection level as Chrome on Linux (OS-encrypted at rest, decryptable by
same-user processes). It is stronger than stock Firefox, which stores
cookies plaintext and is trivially readable by infostealer tooling.

Roadmap: wrap the lockstore KEK in the OS keyring (SecretService/libsecret
via the existing nsIOSKeyStore LibSecret backend) so the DEKs are not
self-contained inside the profile. Chrome's App-Bound Encryption on
Windows is the same idea via a privileged broker. The "high security"
variant could wrap the KEK under the primary password instead.

## Landlock

Not implemented yet. Research summary: Firefox's Linux sandbox is
seccomp-bpf + a filesystem broker (security/sandbox/linux/broker/). Landlock
(kernel 5.13+) could be applied in the child after clone, translating the
existing broker Policy into path_beneath rules. Nothing in upstream or
Chromium ships it; the value is inode-bound FS access that survives exec
and cannot be raced by realpath tricks. It cannot replace the broker
(sockets, exec, dynamic paths), so the realistic shape is a layered deny.
Tractable follow-up, not a config-only change.

## uBlock Origin defaults

uBO ships force-installed and admin-configured through the Firefox
3rdparty policy. The managed settings enable the stock lists plus
block-lan (uBO's LAN intrusion list, same theme as the LNA section),
ublock-annoyances and fanboy-cookiemonster, with hyperlink auditing and
prefetching disabled inside the extension. The policy overrides user
choices on launch; point the policy at your own JSON if you want a
different baseline.

## Vanadium portability notes

Vanadium's headline features are GrapheneOS-specific (hardened_malloc,
exec-based spawning, kernel-level isolation) and do not port to desktop
Firefox. The concepts that did port, and their Lyra status:

- Always-incognito browsing: browser.privatebrowsing.autostart, opt-in
  toggle in Settings.
- Localhost/LAN protection: the LNA section plus uBO's block-lan list.
- HTTPS-only including private windows: https_only_mode_pbm.
- HTTP basic auth in subresources blocked:
  network.auth.subresource-http-auth-allow=1.
- TLS 1.3 early data off (replay hardening): security.tls.enable_0rtt_data.
- Web Push off: dom.push.enabled=false.
- Battery API, beacon, sensors, gamepad, DNS prefetch, speculative
  connections: all off, matching or stricter than Vanadium defaults.

## History search

about:lyrahistory is a dedicated search page over Places plus an optional
local text index (LyraHistory module, content actor captures up to 8 KB of
normalized page text per top-level http(s) page into
profile/lyra-history-index.json). Opt-in via void.history.index.enabled;
never indexes private windows; wiped with clear-history. This replaces
running an external indexer like hister.

## Search and surfaces

- Default engines: Brave Search (default), Wiby, SearXNG (searx.be,
  priv.au). Perplexity and Wikipedia entries removed from the shipped
  config.
- Pages that advertise OpenSearch get a one-time install doorhanger and a
  tab context menu "Set as Default Search Engine" entry.
- Safe Browsing remote lookups are disabled already in void.cfg.
