# Extensions

## uBlock Origin

Lyra ships uBlock Origin (`uBlock0@raymondhill.net`) in normal and private windows.

- Pin: `extensions/ublock/pin.json` and `VERSION`
- Fetch: `extensions/ublock/fetch.sh` (GitHub-signed XPI, sha256 checked)
- Dist: `scripts/package-extras.sh` copies to `distribution/extensions/uBlock0@raymondhill.net.xpi`
- Policy: `ExtensionSettings` force-install from AMO latest, updates left on

The XPI is not in git. GPL-3.0-only. See `extensions/ublock/README.md`.

## Other Mozilla extras

Policy uninstalls the default Google, Bing, Amazon, eBay, and Twitter search add-ons. Webcompat reporter endpoints are cleared. `about:addons` recommendations are off.

## Not bundled

HTTPS Everywhere is not bundled (HTTPS-Only Mode is on). NoScript is not bundled. Multi-Account Containers is not preinstalled. Container UI prefs are on if the user installs that add-on.
