# Status

`VOID_VERSION` in `VERSION`. Product name Lyra. Vendor Quad4. Internal id `lyra`.

## In tree

- Firefox ESR overlay layout
- Quad4 branding (Linux PNGs, about-logo, Windows ICO)
- `policies.json`
- `void.cfg` plus `void-overrides.cfg`
- Lyra Settings pane
- Optional P2P tab and bookmark sync (`wss://socket.quad4.io/ws`)
- mozconfig without crash reporter, updater, or telemetry flags
- Overlay and package scripts (`void` and `quad4` symlink to `lyra`)
- uBlock Origin pin, fetch, dist install
- ESR bump notes
- GitHub Actions: overlay validate, zizmor, Linux and Windows compiles on tags and dispatch, release publish on tags

## Not in tree

- Published installers
- Android build (needs a Fenix fork, not in the ESR tarball)
- macOS `.icns` / `Assets.car`
- Windows Authenticode
- In-app update server
- uBlock unpacked inside `omni.ja`
- Locales besides en-US
- Flatpak / Debian / rpm metadata beyond the `.desktop` file
- Automatic rebase onto each new ESR tarball
