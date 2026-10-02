#!/usr/bin/env bash
# Copy policies and the pinned uBlock XPI into a built Firefox dist tree.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../VERSION
source "$ROOT/VERSION"

DIST="${1:-}"
if [[ -z "$DIST" ]]; then
  echo "usage: $0 /path/to/firefox-dist-bin" >&2
  echo "example: $0 firefox-src/objdir/dist/bin" >&2
  exit 2
fi
if [[ ! -d "$DIST" ]]; then
  echo "dist dir missing: $DIST" >&2
  exit 1
fi

DIST="$(cd "$DIST" && pwd)"
EXT_DIR="$DIST/distribution/extensions"
mkdir -p "$EXT_DIR" "$DIST/distribution" "$DIST/defaults/pref"

cp -f "$ROOT/policies/policies.json" "$DIST/distribution/policies.json"
cp -f "$ROOT/overlay/browser/app/distribution/distribution.ini" "$DIST/distribution/distribution.ini"
cp -f "$ROOT/prefs/void.cfg" "$DIST/void.cfg"
printf 'defaultPref("lyra.version", "%s");\n' "$VOID_VERSION" >> "$DIST/void.cfg"
cp -f "$ROOT/prefs/autoconfig.js" "$DIST/defaults/pref/void-settings.js"
cp -f "$ROOT/prefs/void-overrides.cfg.example" "$DIST/void-overrides.cfg.example"
if [[ -f "$DIST/browser/defaults/preferences/firefox-branding.js" ]]; then
  cp -f "$ROOT/branding/void/firefox/pref/firefox-branding.js" "$DIST/browser/defaults/preferences/firefox-branding.js"
fi

XPI="$ROOT/.cache/ublock/$UBLOCK_XPI_NAME"
if [[ ! -f "$XPI" ]]; then
  "$ROOT/extensions/ublock/fetch.sh"
fi
cp -f "$ROOT/.cache/ublock/$UBLOCK_XPI_NAME" "$EXT_DIR/${UBLOCK_ID}.xpi"

python3 - "$ROOT" "$DIST" "$EXT_DIR" <<'PY'
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
dist = Path(sys.argv[2])
ext_dir = Path(sys.argv[3])
addons = root / "overlay" / "browser" / "themes" / "addons"
chrome_themes = dist / "browser" / "chrome" / "browser" / "content" / "builtin-themes"
for name in ("void-dark", "void-light"):
    src = addons / name
    if chrome_themes.parent.is_dir():
        dest = chrome_themes / name
        dest.mkdir(parents=True, exist_ok=True)
        for path in src.iterdir():
            if path.is_file():
                shutil.copy2(path, dest / path.name)
        print(f"  chrome builtin-themes/{name}")
    xpi = ext_dir / f"{name}@quad4.io.xpi"
    if xpi.is_file():
        xpi.unlink()
        print(f"  removed distro {xpi.name}")

glue = dist / "browser" / "components" / "BrowserComponents.manifest"
if glue.is_file():
    text = glue.read_text()
    lyra_app = "application={3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}"
    old_app = "application={0af1bb40-ff0a-52c4-ad87-168205bd4170}"
    ff_app = "application={ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
    text = text.replace(old_app, lyra_app)
    if lyra_app not in text:
        if ff_app not in text:
            raise SystemExit("dist nsBrowserGlue app-startup entry not found")
        text = text.replace(ff_app, ff_app + " " + lyra_app, 1)
        print("  BrowserComponents.manifest Lyra app id")
    if "LyraSync.init" not in text:
        text = (
            text.rstrip()
            + "\ncategory browser-first-window-ready resource:///modules/LyraSync.sys.mjs LyraSync.init\n"
        )
        print("  BrowserComponents.manifest LyraSync")
    glue.write_text(text)

sync_mod = root / "overlay" / "browser" / "modules" / "LyraSync.sys.mjs"
dist_mod = dist / "browser" / "modules" / "LyraSync.sys.mjs"
if sync_mod.is_file() and dist_mod.parent.is_dir():
    shutil.copy2(sync_mod, dist_mod)
    print("  modules/LyraSync.sys.mjs")

addon_settings = dist / "modules" / "addons" / "AddonSettings.sys.mjs"
if addon_settings.is_file():
    ast = addon_settings.read_text()
    old_default_theme = """if (AppConstants.MOZ_DEV_EDITION) {
  makeConstant("DEFAULT_THEME_ID", "firefox-compact-dark@mozilla.org");
} else {
  makeConstant("DEFAULT_THEME_ID", "default-theme@mozilla.org");
}"""
    new_default_theme = 'makeConstant("DEFAULT_THEME_ID", "void-dark@quad4.io");'
    if 'makeConstant("DEFAULT_THEME_ID", "void-dark@quad4.io")' not in ast:
        if old_default_theme not in ast:
            raise SystemExit("dist AddonSettings DEFAULT_THEME_ID block not found")
        addon_settings.write_text(ast.replace(old_default_theme, new_default_theme, 1))
        print("  AddonSettings DEFAULT_THEME_ID")

xpi_prov = dist / "modules" / "addons" / "XPIProvider.sys.mjs"
if xpi_prov.is_file():
    xp = xpi_prov.read_text()
    old_builtin = """        this.maybeInstallBuiltinAddon(
          "default-theme@mozilla.org",
          "1.4.2",
          "resource://default-theme/"
        );"""
    new_builtin = """        this.maybeInstallBuiltinAddon(
          "void-dark@quad4.io",
          "1.0.0",
          "resource://builtin-themes/void-dark/"
        );
        this.maybeInstallBuiltinAddon(
          "default-theme@mozilla.org",
          "1.4.2",
          "resource://default-theme/"
        );"""
    if "resource://builtin-themes/void-dark/" not in xp:
        if old_builtin not in xp:
            raise SystemExit("dist XPIProvider default theme install not found")
        xpi_prov.write_text(xp.replace(old_builtin, new_builtin, 1))
        print("  XPIProvider void-dark builtin")

built_in_themes = dist / "browser" / "modules" / "BuiltInThemes.sys.mjs"
if built_in_themes.is_file():
    bit = built_in_themes.read_text()
    old_fallback = 'kActiveThemePref,\n      "default-theme@mozilla.org"'
    new_fallback = 'kActiveThemePref,\n      "void-dark@quad4.io"'
    if old_fallback in bit:
        built_in_themes.write_text(bit.replace(old_fallback, new_fallback, 1))
        print("  BuiltInThemes fallback")

LYRA_APP_ID = "{3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}"
OLD_APP_ID = "{0af1bb40-ff0a-52c4-ad87-168205bd4170}"
FF_APP_ID = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}"

def stamp_application_ini(path: Path) -> None:
    text = path.read_text()
    orig = text
    for old, new in (
        ("Name=Void", "Name=Lyra"),
        ("Name=Quad4", "Name=Lyra"),
        ("RemotingName=void", "RemotingName=lyra"),
        ("RemotingName=firefox", "RemotingName=lyra"),
        ("Profile=void", "Profile=lyra"),
        ("Profile=firefox", "Profile=lyra"),
        (OLD_APP_ID, LYRA_APP_ID),
        (FF_APP_ID, LYRA_APP_ID),
    ):
        text = text.replace(old, new)
    if text != orig:
        path.write_text(text)
        print(f"  {path} identity")

for ini in dist.rglob("application.ini"):
    stamp_application_ini(ini)
void_dir = dist.parent / "void"
if void_dir.is_dir():
    for ini in void_dir.rglob("application.ini"):
        stamp_application_ini(ini)

browser_ini = dist / "browser" / "application.ini"
src_ini = dist / "application.ini"
if src_ini.is_file() and browser_ini.parent.is_dir():
    shutil.copy2(src_ini, browser_ini)
    print("  browser/application.ini (for -app)")

for manifest in dist.rglob("chrome.manifest"):
    text = manifest.read_text()
    orig = text
    text = text.replace(OLD_APP_ID, LYRA_APP_ID)
    if text != orig:
        manifest.write_text(text)
        print(f"  {manifest} app id")
xpi_parent = dist.parent / "xpi-stage"
if xpi_parent.is_dir():
    for manifest in xpi_parent.rglob("chrome.manifest"):
        text = manifest.read_text()
        orig = text
        text = text.replace(OLD_APP_ID, LYRA_APP_ID)
        if text != orig:
            manifest.write_text(text)
            print(f"  {manifest} app id")

ac = dist / "modules" / "AppConstants.sys.mjs"
if ac.is_file():
    text = ac.read_text()
    orig = text
    text = text.replace('MOZ_APP_NAME: "void"', 'MOZ_APP_NAME: "lyra"')
    text = text.replace('MOZ_APP_NAME: "firefox"', 'MOZ_APP_NAME: "lyra"')
    text = text.replace('MOZ_APP_BASENAME: "Void"', 'MOZ_APP_BASENAME: "Lyra"')
    text = text.replace('MOZ_APP_BASENAME: "Quad4"', 'MOZ_APP_BASENAME: "Lyra"')
    text = text.replace('MOZ_APP_BASENAME: "Firefox"', 'MOZ_APP_BASENAME: "Lyra"')
    text = text.replace(
        'MOZ_APP_DISPLAYNAME_DO_NOT_USE: "Void"',
        'MOZ_APP_DISPLAYNAME_DO_NOT_USE: "Lyra"',
    )
    text = text.replace(
        'MOZ_APP_DISPLAYNAME_DO_NOT_USE: "Quad4"',
        'MOZ_APP_DISPLAYNAME_DO_NOT_USE: "Lyra"',
    )
    text = text.replace(
        'MOZ_APP_DISPLAYNAME_DO_NOT_USE: "Firefox"',
        'MOZ_APP_DISPLAYNAME_DO_NOT_USE: "Lyra"',
    )
    if text != orig:
        ac.write_text(text)
        print("  modules/AppConstants.sys.mjs identity")

def preprocess(text, defined):
    out = []
    stack = []
    emitting = True
    for line in text.splitlines(keepends=True):
        stripped = line.lstrip()
        if stripped.startswith("#ifndef "):
            name = stripped.split()[1].strip()
            stack.append(emitting)
            emitting = emitting and name not in defined
            continue
        if stripped.startswith("#ifdef "):
            name = stripped.split()[1].strip()
            stack.append(emitting)
            emitting = emitting and name in defined
            continue
        if stripped.startswith("#else"):
            if not stack:
                raise SystemExit("unmatched #else")
            parent = stack[-1]
            emitting = parent and not emitting
            continue
        if stripped.startswith("#endif"):
            if not stack:
                raise SystemExit("unmatched #endif")
            emitting = stack.pop()
            continue
        if stripped.startswith("#include ") or stripped.startswith("#el"):
            continue
        if stripped.startswith("#") and not stripped.startswith("<?"):
            continue
        if emitting:
            out.append(line)
    if stack:
        raise SystemExit("unclosed preprocessor block")
    return "".join(out)

about = dist / "browser" / "chrome" / "browser" / "content" / "browser" / "aboutDialog.xhtml"
if about.is_file():
    raw = about.read_text()
    if "#ifdef" in raw or "#ifndef" in raw:
        about.write_text(preprocess(raw, set()))
        print("  aboutDialog.xhtml preprocessed for dist")

root_overlay = root / "overlay"
void_mjs_src = root_overlay / "browser" / "components" / "preferences" / "config" / "void.mjs"
prefs_chrome = dist / "browser" / "chrome" / "browser" / "content" / "browser" / "preferences"
if void_mjs_src.is_file() and (prefs_chrome / "config").is_dir():
    shutil.copy2(void_mjs_src, prefs_chrome / "config" / "void.mjs")
    print("  preferences/config/void.mjs")

void_ftl_src = root_overlay / "browser" / "locales" / "en-US" / "browser" / "preferences" / "void.ftl"
for loc in (
    dist / "browser" / "localization" / "en-US" / "browser" / "preferences",
    dist.parent / "xpi-stage" / "locale-en-US" / "browser" / "localization" / "en-US" / "browser" / "preferences",
):
    if void_ftl_src.is_file():
        loc.mkdir(parents=True, exist_ok=True)
        shutil.copy2(void_ftl_src, loc / "void.ftl")
        print(f"  {loc / 'void.ftl'}")

brand_ftl_src = root / "branding" / "void" / "firefox" / "locales" / "en-US" / "brand.ftl"
brand_props_src = root / "branding" / "void" / "firefox" / "locales" / "en-US" / "brand.properties"
for loc in (
    dist / "browser" / "localization" / "en-US" / "branding",
    dist.parent / "xpi-stage" / "locale-en-US" / "browser" / "localization" / "en-US" / "branding",
):
    if brand_ftl_src.is_file():
        loc.mkdir(parents=True, exist_ok=True)
        shutil.copy2(brand_ftl_src, loc / "brand.ftl")
        print(f"  {loc / 'brand.ftl'}")
for loc in (
    dist / "browser" / "chrome" / "en-US" / "locale" / "branding",
    dist.parent / "xpi-stage" / "locale-en-US" / "browser" / "chrome" / "en-US" / "locale" / "branding",
):
    if brand_props_src.is_file() and loc.parent.exists():
        loc.mkdir(parents=True, exist_ok=True)
        shutil.copy2(brand_props_src, loc / "brand.properties")
        print(f"  {loc / 'brand.properties'}")

about_pol_src = root_overlay / "browser" / "locales" / "en-US" / "browser" / "aboutPolicies.ftl"
about_dlg_src = root_overlay / "browser" / "locales" / "en-US" / "browser" / "aboutDialog.ftl"
for loc in (
    dist / "browser" / "localization" / "en-US" / "browser",
    dist.parent / "xpi-stage" / "locale-en-US" / "browser" / "localization" / "en-US" / "browser",
):
    loc.mkdir(parents=True, exist_ok=True)
    if about_pol_src.is_file():
        shutil.copy2(about_pol_src, loc / "aboutPolicies.ftl")
    if about_dlg_src.is_file():
        shutil.copy2(about_dlg_src, loc / "aboutDialog.ftl")

prefs_js = prefs_chrome / "preferences.js"
if prefs_js.is_file():
    ptext = prefs_js.read_text()
    void_pane = """  voidPrivacy: {
    l10nId: "void-privacy-header",
    iconSrc: "chrome://branding/content/about-logo.svg",
    groupIds: [
      "voidFingerprint",
      "voidWindows",
      "voidFonts",
      "voidTyping",
      "voidSpoof",
      "voidDns",
      "voidSync",
      "voidCompat",
    ],
    module: "chrome://browser/content/preferences/config/void.mjs",
  },
"""
    if "voidPrivacy:" not in ptext:
        needle_panes = "const CONFIG_PANES = Object.freeze({\n"
        if needle_panes not in ptext:
            raise SystemExit("dist CONFIG_PANES not found")
        ptext = ptext.replace(needle_panes, needle_panes + void_pane, 1)
        print("  preferences.js Void pane")
    elif '"voidSync"' not in ptext:
        ptext = ptext.replace(
            '"voidDns",\n      "voidCompat",',
            '"voidDns",\n      "voidSync",\n      "voidCompat",',
            1,
        )
        print("  preferences.js voidSync group")
    prefs_js.write_text(ptext)
    ptext = prefs_js.read_text()
    ptext = ptext.replace(
        'module: "chrome://browser/content/preferences/config/SettingGroupManager.mjs"',
        'module: "chrome://browser/content/preferences/config/void.mjs"',
    )
    start = ptext.find('\ntry {\n  ChromeUtils.importESModule(\n    "chrome://browser/content/preferences/config/void.mjs"')
    if start != -1:
        end = ptext.find('document.addEventListener("DOMContentLoaded", init_all, { once: true });', start)
        if end != -1:
            ptext = ptext[:start] + "\n" + ptext[end:]
    prefs_js.write_text(ptext)

sgm = prefs_chrome / "config" / "SettingGroupManager.mjs"
if sgm.is_file() and "voidFingerprint" in sgm.read_text():
    stext = sgm.read_text()
    stock_end = """  registerGroups(groupConfigs) {
    for (let id in groupConfigs) {
      this.registerGroup(id, groupConfigs[id]);
    }
  },
};
"""
    idx = stext.find(stock_end)
    if idx == -1:
        raise SystemExit("dist SettingGroupManager.mjs stock ending not found")
    restored = stext[: idx + len(stock_end)]
    restored = restored.replace(
        'import { Preferences } from "chrome://global/content/preferences/Preferences.mjs";\n\n',
        "",
        1,
    )
    sgm.write_text(restored)
    print("  SettingGroupManager.mjs restored")

pxhtml = prefs_chrome / "preferences.xhtml"
if pxhtml.is_file():
    xtext = pxhtml.read_text()
    changed = False
    if "category-void-privacy" not in xtext:
        nav = """      <html:moz-page-nav-button id="category-void-privacy"
        view="paneVoidPrivacy"
        iconsrc="chrome://branding/content/about-logo.svg"
        data-l10n-id="pane-void-privacy-title">
      </html:moz-page-nav-button>
"""
        nav_anchor = """      <html:moz-page-nav-button id="category-privacy"
        view="panePrivacy"
        iconsrc="chrome://browser/skin/preferences/category-privacy-security.svg"
        data-l10n-id="pane-privacy-title3">
      </html:moz-page-nav-button>
"""
        if nav_anchor not in xtext:
            raise SystemExit("dist privacy nav button not found")
        xtext = xtext.replace(nav_anchor, nav_anchor + nav, 1)
        changed = True
    if 'href="browser/preferences/void.ftl"' not in xtext:
        ftl_anchor = '<link rel="localization" href="browser/preferences/preferences.ftl"/>'
        if ftl_anchor not in xtext:
            raise SystemExit("dist preferences.ftl localization link not found")
        xtext = xtext.replace(
            ftl_anchor,
            ftl_anchor + '\n  <link rel="localization" href="browser/preferences/void.ftl"/>',
            1,
        )
        changed = True
    if changed:
        pxhtml.write_text(xtext)
        print("  preferences.xhtml Void pane")
PY

if [[ -L "$DIST/lyra" ]]; then
  rm -f "$DIST/lyra"
fi
if [[ -x "$DIST/void" && ! -L "$DIST/void" ]]; then
  mv "$DIST/void" "$DIST/lyra"
fi
if [[ -x "$DIST/lyra" ]]; then
  ln -sfn lyra "$DIST/void"
  ln -sfn lyra "$DIST/quad4"
  echo "  void -> lyra"
  echo "  quad4 -> lyra"
fi

echo "packaged extras into $DIST"
echo "  distribution/policies.json"
echo "  distribution/extensions/${UBLOCK_ID}.xpi"
echo "  void.cfg"
echo "If a running Lyra still shows an old Settings page, quit it and delete that profile's startupCache directory."
