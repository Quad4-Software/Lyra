#!/usr/bin/env bash
# Fetch ESR, apply overlay, compile Lyra for Windows, pack a zip.
# Runs inside the MozillaBuild msys2 shell on a windows-latest runner.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../VERSION
source "$ROOT/VERSION"

SRC="${LYRA_SRC:-$ROOT/firefox-src}"
OUT="${LYRA_OUT:-$ROOT/out}"
JOBS="${LYRA_JOBS:-$(nproc)}"

export MOZBUILD_STATE_PATH="${MOZBUILD_STATE_PATH:-${USERPROFILE:-$HOME}/.mozbuild}"
MOZBUILD_STATE_PATH="$(cygpath -m "$MOZBUILD_STATE_PATH")"
export PATH="$(cygpath -u "${USERPROFILE:-$HOME}")/.cargo/bin:${PATH}"
umask 022

# A bare msys2 login shell does not get the MozillaBuild PATH. Find its
# bundled CPython if neither python3 nor python resolve.
if ! command -v python3 >/dev/null && ! command -v python >/dev/null; then
  pyexe="$(find /c/mozilla-build -maxdepth 3 \( -name 'python3.exe' -o -name 'python.exe' \) 2>/dev/null | head -1)"
  if [[ -n "$pyexe" ]]; then
    export PATH="$(dirname "$pyexe"):$PATH"
  fi
fi
if ! command -v python3 >/dev/null && command -v python >/dev/null; then
  mkdir -p "$HOME/.local/bin"
  printf '#!/usr/bin/env bash\nexec python "$@"\n' > "$HOME/.local/bin/python3"
  chmod +x "$HOME/.local/bin/python3"
  export PATH="$HOME/.local/bin:$PATH"
fi
if ! command -v python3 >/dev/null; then
  echo "python3 missing from MozillaBuild PATH" >&2
  exit 1
fi

# msys tar forks to spawn xz and can hit dll base collisions on hosted
# runners. bsdtar in System32 is a native binary and does not fork.
if [[ -x "/c/Windows/System32/tar.exe" ]]; then
  export TAR="/c/Windows/System32/tar.exe"
fi

"$ROOT/scripts/fetch-firefox.sh" "$SRC"
"$ROOT/scripts/apply-overlay.sh" "$SRC"
"$ROOT/extensions/ublock/fetch.sh"

cat "$ROOT/mozconfig" "$ROOT/mozconfig.windows" > "$SRC/mozconfig"
{
  echo "mk_add_options MOZ_MAKE_FLAGS=\"-j${JOBS}\""
  echo "mk_add_options AUTOCLOBBER=1"
  if [[ -n "${EXTRA_MOZCONFIG:-}" ]]; then
    printf '%s\n' "$EXTRA_MOZCONFIG"
  fi
} >> "$SRC/mozconfig"

MOZCONFIG="$(cygpath -m "$SRC/mozconfig")"
export MOZCONFIG
cd "$SRC"

./mach --no-interactive bootstrap --application-choice browser --no-system-changes
./mach configure
./mach build

BIN="$SRC/objdir/dist/bin"
if [[ ! -d "$BIN" ]]; then
  echo "dist bin missing: $BIN" >&2
  exit 1
fi

"$ROOT/scripts/package-extras.sh" "$BIN"

if [[ ! -x "$BIN/lyra.exe" ]]; then
  echo "lyra.exe missing after package-extras" >&2
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

mkdir -p "$OUT"
STAGE="$OUT/lyra-${VOID_VERSION}-windows-x86_64"
ZIP="$OUT/lyra-${VOID_VERSION}-windows-x86_64.zip"
rm -rf "$STAGE" "$ZIP"
mkdir -p "$STAGE"
cp -a "$BIN/." "$STAGE/"

if command -v 7z >/dev/null; then
  (cd "$STAGE" && 7z a -tzip -mx=5 "$ZIP" . >/dev/null)
elif [[ -x "/c/Program Files/7-Zip/7z.exe" ]]; then
  (cd "$STAGE" && "/c/Program Files/7-Zip/7z.exe" a -tzip -mx=5 "$ZIP" . >/dev/null)
elif command -v zip >/dev/null; then
  (cd "$STAGE" && zip -qr "$ZIP" .)
else
  powershell.exe -NoProfile -Command \
    "Compress-Archive -Path '$(cygpath -w "$STAGE")\\*' -DestinationPath '$(cygpath -w "$ZIP")' -CompressionLevel Optimal"
fi
rm -rf "$STAGE"

ls -lh "$OUT"
echo "artifact $ZIP"
