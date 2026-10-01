#!/usr/bin/env bash
# Fetch ESR, apply overlay, compile Lyra, stamp extras, pack a tarball.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../VERSION
source "$ROOT/VERSION"

SRC="${LYRA_SRC:-$ROOT/firefox-src}"
OUT="${LYRA_OUT:-$ROOT/out}"
JOBS="${LYRA_JOBS:-$(nproc)}"

export PATH="${HOME}/.cargo/bin:${PATH}"
export MOZBUILD_STATE_PATH="${MOZBUILD_STATE_PATH:-$HOME/.mozbuild}"
umask 022

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  python3 python3-pip python3-venv python3-dev \
  build-essential ccache curl git pkg-config \
  libasound2-dev libdbus-glib-1-dev libgtk-3-dev libpulse-dev \
  libx11-xcb-dev libxt-dev libxrandr-dev libxcomposite-dev \
  libxdamage-dev libxfixes-dev libdrm-dev libpango1.0-dev \
  libatk1.0-dev libcairo2-dev libgdk-pixbuf-2.0-dev \
  m4 unzip zip nasm xz-utils \
  clang llvm lld

"$ROOT/scripts/fetch-firefox.sh" "$SRC"
"$ROOT/scripts/apply-overlay.sh" "$SRC"
"$ROOT/extensions/ublock/fetch.sh"

cat "$ROOT/mozconfig" "$ROOT/mozconfig.linux" > "$SRC/mozconfig"
{
  echo "mk_add_options MOZ_MAKE_FLAGS=\"-j${JOBS}\""
  echo "mk_add_options AUTOCLOBBER=1"
  echo "ac_add_options --with-ccache=$(command -v ccache)"
  if [[ -n "${EXTRA_MOZCONFIG:-}" ]]; then
    printf '%s\n' "$EXTRA_MOZCONFIG"
  fi
} >> "$SRC/mozconfig"

export MOZCONFIG="$SRC/mozconfig"
cd "$SRC"

./mach --no-interactive bootstrap --application-choice browser --no-system-changes

run_mach() {
  env -i \
    HOME="$HOME" \
    USER="${USER:-runner}" \
    LOGNAME="${LOGNAME:-${USER:-runner}}" \
    PATH="$PATH" \
    SHELL="${SHELL:-/bin/bash}" \
    TERM="${TERM:-xterm}" \
    LANG="${LANG:-C.UTF-8}" \
    LC_ALL="${LC_ALL:-C.UTF-8}" \
    MOZCONFIG="$MOZCONFIG" \
    MOZBUILD_STATE_PATH="$MOZBUILD_STATE_PATH" \
    CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}" \
    CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}" \
    RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}" \
    ./mach "$@"
}

run_mach configure
run_mach build
run_mach package

BIN="$SRC/objdir/dist/bin"
if [[ ! -d "$BIN" ]]; then
  echo "dist bin missing: $BIN" >&2
  exit 1
fi

"$ROOT/scripts/package-extras.sh" "$BIN"

if [[ ! -x "$BIN/lyra" ]]; then
  echo "lyra binary missing after package-extras" >&2
  exit 1
fi

if ! grep -q '^Name=Lyra$' "$BIN/application.ini" \
  && ! grep -q '^Name=Lyra$' "$BIN/browser/application.ini"; then
  echo "application.ini Name is not Lyra" >&2
  exit 1
fi
if ! grep -q '{3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}' "$BIN/application.ini" \
  && ! grep -q '{3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}' "$BIN/browser/application.ini"; then
  echo "application.ini app id is not Lyra" >&2
  exit 1
fi
if [[ ! -f "$BIN/distribution/extensions/${UBLOCK_ID}.xpi" ]]; then
  echo "uBlock XPI missing from dist" >&2
  exit 1
fi

"$BIN/lyra" --version || true

mkdir -p "$OUT"
STAGE="$OUT/lyra-${VOID_VERSION}-linux-x86_64"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -a "$BIN/." "$STAGE/"
tar -C "$OUT" -cJf "$OUT/lyra-${VOID_VERSION}-linux-x86_64.tar.xz" "$(basename "$STAGE")"
rm -rf "$STAGE"

ls -lh "$OUT"
echo "artifact $OUT/lyra-${VOID_VERSION}-linux-x86_64.tar.xz"
