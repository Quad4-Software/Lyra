#!/usr/bin/env bash
# Fetch ESR, apply overlay, compile Lyra for Windows, pack a zip.
# Runs inside the MozillaBuild msys2 shell on a windows-latest runner.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../VERSION
source "$ROOT/VERSION"

SRC="${LYRA_SRC:-$ROOT/firefox-src}"
OUT="${LYRA_OUT:-$ROOT/out}"
# 4-way rustc parallelism OOMs a 16 GB hosted runner. Keep one core back.
JOBS="${LYRA_JOBS:-$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))}"

export MOZBUILD_STATE_PATH="${MOZBUILD_STATE_PATH:-${USERPROFILE:-$HOME}/.mozbuild}"
MOZBUILD_STATE_PATH="$(cygpath -m "$MOZBUILD_STATE_PATH")"
export PATH="$(cygpath -u "${USERPROFILE:-$HOME}")/.cargo/bin:${PATH}"
umask 022

# Long compiles on hosted runners get SIGTERM with no hint. Log memory
# and disk every minute so a kill is diagnosable after the fact.
( while :; do
    printf 'monitor %s | ' "$(date -u +%H:%M:%S)"
    powershell.exe -NoProfile -Command \
      "\$o=Get-CimInstance Win32_OperatingSystem; 'mem {0}/{1}MB' -f [int]((\$o.TotalVisibleMemorySize-\$o.FreePhysicalMemory)/1KB), [int](\$o.TotalVisibleMemorySize/1KB)" \
      2>/dev/null | tr -d '\r' | tr '\n' ' '
    df -h "$ROOT" | awk 'NR==2 {printf "disk %s used, %s free\n", $3, $4}'
    sleep 60
  done ) &
trap 'kill %1 2>/dev/null || true' EXIT

# A bare msys2 login shell does not get the MozillaBuild PATH. Its bin
# dir holds bundled tools like nasm.
export PATH="/c/mozilla-build/bin:$PATH"

# Bundled CPython is not on PATH either. Find it under mozilla-build.
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
# Bootstrap on Windows does not fetch a compiler. Use the clang-cl that
# ships in the runner image: VS LLVM tools first, standalone LLVM next.
for d in \
  "/c/Program Files/Microsoft Visual Studio/2022/Enterprise/VC/Tools/Llvm/x64/bin" \
  "/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/Llvm/x64/bin" \
  "/c/Program Files/LLVM/bin"; do
  if [[ -x "$d/clang-cl.exe" ]]; then
    export PATH="$d:$PATH"
    echo "clang-cl from $d"
    break
  fi
done
if ! command -v clang-cl >/dev/null; then
  echo "clang-cl not found on PATH or in the runner image" >&2
  exit 1
fi

if ! command -v nasm >/dev/null; then
  nasm_dir="$ROOT/.cache/nasm"
  mkdir -p "$nasm_dir"
  curl -fL --retry 3 -o "$nasm_dir/nasm.zip" \
    "https://www.nasm.us/pub/nasm/releasebuilds/2.16.03/win64/nasm-2.16.03-win64.zip"
  echo "3ee4782247bcb874378d02f7eab4e294a84d3d15f3f6ee2de2f47a46aa7226e6  $nasm_dir/nasm.zip" | sha256sum -c -
  /c/Windows/System32/tar.exe -C "$nasm_dir" -xf "$nasm_dir/nasm.zip"
  export PATH="$nasm_dir/nasm-2.16.03:$PATH"
fi
if ! command -v nasm >/dev/null; then
  echo "nasm not found" >&2
  exit 1
fi

# Configure needs the Windows App SDK redistributable DLLs. Bootstrap does
# not fetch the toolchain on Windows, so pull the pinned redist zip and
# extract only the DLLs the build copies into dist.
sdk_cache="$ROOT/.cache/winappsdk"
sdk_dir="$sdk_cache/x64"
if [[ ! -f "$sdk_dir/CoreMessagingXP.dll" ]]; then
  rm -rf "$sdk_dir"
  mkdir -p "$sdk_dir"
  redist="$sdk_cache/Microsoft.WindowsAppRuntime.Redist.2.2.zip"
  if [[ ! -f "$redist" ]]; then
    echo "downloading Windows App SDK redist"
    curl -fL --retry 3 -o "$redist" \
      "https://aka.ms/windowsappsdk/2.2/2.2.0/Microsoft.WindowsAppRuntime.Redist.2.2.zip"
  fi
  echo "ab078d5b1d730f093ed4e1a33d0e709d1dbca85fa4a10f546cc6824e3b48057f  $redist" | sha256sum -c -
  /c/Windows/System32/tar.exe -C "$sdk_cache" -xf "$redist" \
    "MSIX/win10-x64/Microsoft.WindowsAppRuntime.2.msix"
  msix="$sdk_cache/MSIX/win10-x64/Microsoft.WindowsAppRuntime.2.msix"
  for dll in \
    CoreMessagingXP.dll marshal.dll Microsoft.InputStateManager.dll \
    Microsoft.Internal.FrameworkUdk.dll Microsoft.UI.Composition.OSSupport.dll \
    Microsoft.UI.Input.dll Microsoft.UI.Windowing.Core.dll \
    Microsoft.UI.Windowing.dll Microsoft.WindowsAppRuntime.dll \
    Microsoft.WindowsAppRuntime.Insights.Resource.dll; do
    /c/Windows/System32/tar.exe -C "$sdk_dir" -xf "$msix" "$dll"
  done
  rm -rf "$sdk_cache/MSIX"
fi
export MOZ_WINDOWS_APP_SDK_DIR="$(cygpath -m "$sdk_dir")"

# Wasm-sandboxed libraries need a wasi sysroot. Bootstrap does not fetch
# it on Windows, so unpack the pinned wasi-sdk sysroot and add the
# wasm32-wasi compat copies upstream ships for older clang.
wasi_cache="$ROOT/.cache/wasi"
wasi_dir="$wasi_cache/wasi-sysroot-34.0"
if [[ ! -f "$wasi_dir/lib/wasm32-wasi/libc.a" ]]; then
  mkdir -p "$wasi_cache"
  tarball="$wasi_cache/wasi-sysroot-34.0.tar.gz"
  if [[ ! -f "$tarball" ]]; then
    echo "downloading wasi sysroot"
    curl -fL --retry 3 -o "$tarball" \
      "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-34/wasi-sysroot-34.0.tar.gz"
  fi
  echo "9d813544eeebe38b7b8f2244ed591de46b6db812c6dd1a257ff9f0d2a905a2be  $tarball" | sha256sum -c -
  /c/Windows/System32/tar.exe -C "$wasi_cache" -xzf "$tarball"
  cp -r "$wasi_dir/lib/wasm32-wasip1" "$wasi_dir/lib/wasm32-wasi"
  cp -r "$wasi_dir/include/wasm32-wasip1" "$wasi_dir/include/wasm32-wasi"
fi
export WASI_SYSROOT="$(cygpath -m "$wasi_dir")"

export MOZCONFIG
cd "$SRC"

./mach --no-interactive bootstrap --application-choice browser --no-system-changes

# Windows bootstrap installs rustup but not cbindgen.
if ! command -v cbindgen >/dev/null; then
  cargo install cbindgen --locked
fi

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
