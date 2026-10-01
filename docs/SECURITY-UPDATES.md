# Security updates

Lyra tracks Firefox ESR, not mozilla-release and not mozilla-central.

## ESR

LibreWolf follows rapid release. Mullvad Browser follows ESR (via Tor Browser). Lyra uses ESR so Mozilla point releases do not force a feature rebase.

Privacy prefs live outside the C++ tree. Most point releases are: bump `VERSION`, rebuild.

Feature uptake is slower. That is the trade.

## Current pin

See `VERSION`.

- Train: Firefox ESR
- Pin: `153.3.0esr`
- Tarball and `.asc` URLs in `VERSION`
- SHA-256: `FIREFOX_SOURCE_SHA256`

`scripts/fetch-firefox.sh` downloads into `.cache/firefox/`, checks the hash, and extracts.

## Point release

When Mozilla ships `153.x.yesr`:

1. Update `FIREFOX_VERSION`, `FIREFOX_SOURCE_URL`, and `FIREFOX_SOURCE_SHA256` in `VERSION`
2. Extract with `scripts/fetch-firefox.sh`
3. Run `scripts/apply-overlay.sh` and fix rejected edits
4. Rebuild and smoke-test `about:policies`, uBlock, branding
5. If Mozilla moved branding paths or `moz.build` shape, update `patches/` and the overlay script
6. Bump `VOID_VERSION`, for example `153.3.1-1`

New ESR major after 153:

1. Diff the overlay against `browser/branding/unofficial`
2. Re-test autoconfig and `policies.json` keys
3. Drop removed policy keys, add keys for new nags
4. Re-pin uBlock Origin if signing or MV3 requires it

## What we do not do

- Hand-backport Mozilla CVEs. Rebuild on the ESR tarball that already has them.
- Run Mozilla's in-app updater. `DisableAppUpdate` stays on until Lyra has its own channel.

`validate.yml` does not download Firefox source. `build-linux.yml` does, and checks `FIREFOX_SOURCE_SHA256`.

## GPG

Mozilla signs source tarballs. For a release build, also verify `$tarball.asc` with the [Mozilla release key](https://ftp.mozilla.org/pub/firefox/releases/). CI checks SHA-256. It does not import GPG keys.

## Rapid release

To take a fix that only landed on mozilla-release, set `FIREFOX_CHANNEL` to `release` and point `FIREFOX_SOURCE_URL` at that tarball. Expect more overlay churn. Note it in the release notes.
