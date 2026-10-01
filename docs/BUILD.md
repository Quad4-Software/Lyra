# Build Lyra

Lyra is built on a Firefox ESR source tarball. That tarball is not in git. Binary name is `lyra`.

## Host

- Linux x86_64
- About 30 GB free disk
- 16 GB RAM (8 GB will swap)

Windows and macOS use the same overlay. `mozconfig.windows` holds Windows extras. CI compiles Linux and Windows. The Windows job runs `scripts/ci-windows-build.sh` inside a MozillaBuild shell on `windows-latest`.

## Steps

### 1. Packages

Debian / Ubuntu:

```
sudo apt install python3 python3-pip python3-venv python3-dev \
  build-essential ccache curl git pkg-config libasound2-dev \
  libdbus-glib-1-dev libgtk-3-dev libpulse-dev libx11-xcb-dev \
  libxt-dev m4 unzip zip nasm clang llvm lld
```

Then:

```
./scripts/fetch-firefox.sh ./firefox-src
cd firefox-src
./mach bootstrap
```

Choose Firefox for Desktop. Do not pick artifact mode.

### 2. Overlay

From the repo root:

```
./scripts/apply-overlay.sh ./firefox-src
./extensions/ublock/fetch.sh
```

`apply-overlay.sh` copies branding, policies, autoconfig, and the Settings pane onto the Firefox tree. It also edits `browser/moz.configure` (vendor, profile, app id).

### 3. Compile

```
cd firefox-src
cat ../mozconfig ../mozconfig.linux > mozconfig
export MOZCONFIG="$PWD/mozconfig"
./mach configure
./mach build
./mach package
```

`mozconfig` sets `--with-app-name=lyra`, `--with-app-basename=Lyra`, `--with-branding=browser/branding/void`, `--enable-bundled-fonts`. Crash reporter and updater are off. `MOZ_TELEMETRY_REPORTING`, `MOZ_DATA_REPORTING`, and `MOZ_SERVICES_HEALTHREPORT` are off.

Firefox 153+ only allows `MOZ_APP_DISPLAYNAME` and `MOZ_MACBUNDLE_ID` in branding `configure.sh`. Vendor, profile, and app id are set by `scripts/apply-overlay.sh`.

If `./mach configure` dies with `Error loading mozconfig` or `assert not in_variable`, the environment has quotes or newlines. Use `env -i` as in `scripts/ci-linux-build.sh`.

### 4. Dist extras

```
../scripts/package-extras.sh ./objdir/dist/bin
```

This copies `policies.json`, `void.cfg`, and the uBlock XPI. It stamps identity on `application.ini`, installs the Settings pane, and makes `void` and `quad4` point at `lyra`.

Firefox caches unpacked chrome in the profile `startupCache` directory. After restamping an existing dist, quit Lyra and delete that directory, or use a new profile.

### 5. Run

```
./objdir/dist/bin/lyra
```

Check:

- About dialog says Lyra
- `about:policies` has telemetry, Pocket, and accounts off
- uBlock Origin is present
- Settings has a Lyra pane

## CI

`validate.yml` runs `scripts/validate.py` and zizmor on push and pull request.

`build.yml` compiles Linux and Windows on `v*` tags and on workflow_dispatch. It uploads `lyra-<VOID_VERSION>-linux-x86_64.tar.xz` and `lyra-<VOID_VERSION>-windows-x86_64.zip`. On tag pushes a release job publishes a GitHub release with both artifacts. GitHub-hosted runners are tight on disk. The jobs delete unused runner software first. A compile takes hours.

The Windows job downloads MozillaBuild 4.2.1 from ftp.mozilla.org and verifies its SHA-256 before installing. It uses the Visual Studio that ships on the runner image.

Actions are pinned to full commit SHAs. `GITHUB_TOKEN` is contents-read except the release job, which needs contents-write to publish. Checkout does not persist credentials. The compile workflow does not use `pull_request_target`.

## Object dir

Default: `firefox-src/objdir`. Override with `mk_add_options MOZ_OBJDIR=...` in `mozconfig.local` (gitignored).

## Clean extract

Run `apply-overlay.sh` on a fresh tarball. Do not run it twice on an already patched tree. `confvars.sh` edits match exact strings.

## Artifacts in git

`.gitignore` drops `firefox-src/`, `.cache/`, `*.tar.xz`, and `*.xpi`. Do not commit Mozilla source or the uBlock XPI.
