#!/usr/bin/env bash
# Copy Void overlay files onto a Firefox source tree and apply patches.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-}"

if [[ -z "$SRC" ]]; then
  echo "usage: $0 /path/to/firefox-source" >&2
  exit 2
fi
if [[ ! -f "$SRC/mach" ]]; then
  echo "not a Firefox source tree: $SRC" >&2
  exit 1
fi

SRC="$(cd "$SRC" && pwd)"

copy_tree() {
  local from="$1"
  local to="$2"
  mkdir -p "$(dirname "$to")"
  rm -rf "$to"
  cp -a "$from" "$to"
}

echo "overlay branding -> $SRC/browser/branding/void"
copy_tree "$ROOT/branding/void/firefox" "$SRC/browser/branding/void"

echo "overlay distribution files"
mkdir -p "$SRC/browser/app/distribution"
cp -f "$ROOT/overlay/browser/app/distribution/distribution.ini" "$SRC/browser/app/distribution/distribution.ini"
cp -f "$ROOT/policies/policies.json" "$SRC/browser/app/distribution/policies.json"

echo "overlay autoconfig"
cp -f "$ROOT/prefs/void.cfg" "$SRC/browser/app/void.cfg"
cp -f "$ROOT/prefs/autoconfig.js" "$SRC/browser/app/profile/void-settings.js"

echo "overlay linux desktop file"
mkdir -p "$SRC/browser/branding/void"
cp -f "$ROOT/overlay/linux/io.quad4.lyra.desktop" "$SRC/browser/branding/void/lyra.desktop"

echo "overlay locales"
mkdir -p "$SRC/browser/locales/en-US/browser"
mkdir -p "$SRC/browser/locales/en-US/browser/preferences"
cp -f "$ROOT/overlay/browser/locales/en-US/browser/aboutDialog.ftl" "$SRC/browser/locales/en-US/browser/aboutDialog.ftl"
cp -f "$ROOT/overlay/browser/locales/en-US/browser/aboutPolicies.ftl" "$SRC/browser/locales/en-US/browser/aboutPolicies.ftl"
cp -f "$ROOT/overlay/browser/locales/en-US/browser/preferences/void.ftl" "$SRC/browser/locales/en-US/browser/preferences/void.ftl"

echo "overlay Lyra sync module"
mkdir -p "$SRC/browser/modules"
cp -f "$ROOT/overlay/browser/modules/LyraSync.sys.mjs" "$SRC/browser/modules/LyraSync.sys.mjs"
cp -f "$ROOT/overlay/browser/modules/LyraOpenSearch.sys.mjs" "$SRC/browser/modules/LyraOpenSearch.sys.mjs"
cp -f "$ROOT/overlay/browser/modules/LyraScriptBlock.sys.mjs" "$SRC/browser/modules/LyraScriptBlock.sys.mjs"
cp -f "$ROOT/overlay/browser/modules/LyraHistory.sys.mjs" "$SRC/browser/modules/LyraHistory.sys.mjs"
cp -f "$ROOT/overlay/browser/locales/en-US/browser/lyra.ftl" "$SRC/browser/locales/en-US/browser/lyra.ftl"

echo "overlay Lyra setup page"
mkdir -p "$SRC/browser/components/lyra"
cp -f "$ROOT/overlay/browser/components/lyra/setup.xhtml" "$SRC/browser/components/lyra/setup.xhtml"
cp -f "$ROOT/overlay/browser/components/lyra/setup.js" "$SRC/browser/components/lyra/setup.js"
cp -f "$ROOT/overlay/browser/components/lyra/setup.css" "$SRC/browser/components/lyra/setup.css"
cp -f "$ROOT/overlay/browser/components/lyra/jar.mn" "$SRC/browser/components/lyra/jar.mn"
cp -f "$ROOT/overlay/browser/components/lyra/moz.build" "$SRC/browser/components/lyra/moz.build"
cp -f "$ROOT/overlay/browser/components/lyra/history.xhtml" "$SRC/browser/components/lyra/history.xhtml"
cp -f "$ROOT/overlay/browser/components/lyra/history.js" "$SRC/browser/components/lyra/history.js"
cp -f "$ROOT/overlay/browser/components/lyra/history.css" "$SRC/browser/components/lyra/history.css"
cp -f "$ROOT/overlay/browser/components/lyra/LyraHistoryChild.sys.mjs" "$SRC/browser/components/lyra/LyraHistoryChild.sys.mjs"
cp -f "$ROOT/overlay/browser/locales/en-US/browser/lyraSetup.ftl" "$SRC/browser/locales/en-US/browser/lyraSetup.ftl"
cp -f "$ROOT/overlay/browser/locales/en-US/browser/lyraHistory.ftl" "$SRC/browser/locales/en-US/browser/lyraHistory.ftl"

echo "overlay bundled CDN libs"
cp -f "$ROOT/extensions/decentraleyes-libs/"*.js "$SRC/browser/extensions/webcompat/shims/"

echo "overlay Void settings pane"
mkdir -p "$SRC/browser/components/preferences/config"
cp -f "$ROOT/overlay/browser/components/preferences/config/void.mjs" "$SRC/browser/components/preferences/config/void.mjs"

echo "overlay Void themes"
for theme in void-dark void-light void-ember void-forest void-ocean void-linen; do
  copy_tree "$ROOT/overlay/browser/themes/addons/$theme" "$SRC/browser/themes/addons/$theme"
done

PYTHONUTF8=1 python3 - "$SRC" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])

confvars = src / "browser" / "confvars.sh"
text = confvars.read_text()
text = text.replace(
    "MOZ_BRANDING_DIRECTORY=browser/branding/unofficial",
    "MOZ_BRANDING_DIRECTORY=browser/branding/void",
)
text = text.replace(
    "MOZ_OFFICIAL_BRANDING_DIRECTORY=browser/branding/official",
    "MOZ_OFFICIAL_BRANDING_DIRECTORY=browser/branding/void",
)
confvars.write_text(text)

dist = src / "browser" / "app" / "distribution" / "moz.build"
dtext = dist.read_text()
needle = """if CONFIG["BUILT_BY_MOZILLA"]:
    FINAL_TARGET_FILES.distribution += [
        "distribution.ini",
    ]
"""
insert = """FINAL_TARGET_FILES.distribution += [
    "distribution.ini",
    "policies.json",
]
"""
if "policies.json" not in dtext:
    if needle in dtext:
        dtext = dtext.replace(needle, insert)
    else:
        dtext += "\n" + insert
    dist.write_text(dtext)

app = src / "browser" / "app" / "moz.build"
atext = app.read_text()
marker = 'FINAL_TARGET_FILES += ["void.cfg"]'
if marker not in atext:
    atext = atext.replace(
        'DIST_SUBDIR = ""\n',
        'DIST_SUBDIR = ""\n\nFINAL_TARGET_FILES += ["void.cfg"]\n'
        'FINAL_TARGET_FILES.defaults.pref += ["profile/void-settings.js"]\n',
        1,
    )
    app.write_text(atext)

# Firefox 153+ treats these as project flags, not branding confvars.
moz = src / "browser" / "moz.configure"
mtext = moz.read_text()
mtext = mtext.replace(
    'imply_option("MOZ_APP_VENDOR", "Mozilla")',
    'imply_option("MOZ_APP_VENDOR", "Quad4")',
)
mtext = mtext.replace(
    'imply_option("MOZ_APP_ID", "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}")',
    'imply_option("MOZ_APP_ID", "{3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}")',
)
mtext = mtext.replace(
    'imply_option("MOZ_APP_ID", "{0af1bb40-ff0a-52c4-ad87-168205bd4170}")',
    'imply_option("MOZ_APP_ID", "{3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}")',
)
mtext = mtext.replace(
    'imply_option("MOZ_SERVICES_HEALTHREPORT", True)',
    'imply_option("MOZ_SERVICES_HEALTHREPORT", False)',
)
mtext = mtext.replace(
    'imply_option("MOZ_NORMANDY", True)',
    'imply_option("MOZ_NORMANDY", False)',
)
if 'imply_option("MOZ_APP_PROFILE"' not in mtext:
    mtext = mtext.replace(
        'imply_option("MOZ_APP_VENDOR", "Quad4")\n',
        'imply_option("MOZ_APP_VENDOR", "Quad4")\n'
        'imply_option("MOZ_APP_PROFILE", "lyra")\n',
    )
else:
    mtext = mtext.replace(
        'imply_option("MOZ_APP_PROFILE", "void")',
        'imply_option("MOZ_APP_PROFILE", "lyra")',
    )
moz.write_text(mtext)

jar = src / "browser" / "themes" / "addons" / "jar.mn"
jtext = jar.read_text()
void_jar = """
  content/builtin-themes/void-dark/preview.svg     (void-dark/preview.svg)
  content/builtin-themes/void-dark/icon.svg        (void-dark/icon.svg)
  content/builtin-themes/void-dark/manifest.json   (void-dark/manifest.json)

  content/builtin-themes/void-light/preview.svg    (void-light/preview.svg)
  content/builtin-themes/void-light/icon.svg       (void-light/icon.svg)
  content/builtin-themes/void-light/manifest.json  (void-light/manifest.json)
"""
if "void-dark/manifest.json" not in jtext:
    jar.write_text(jtext.rstrip() + "\n" + void_jar + "\n")

cfg = src / "browser" / "themes" / "BuiltInThemeConfig.sys.mjs"
ctext = cfg.read_text()
void_cfg = """
  [
    "void-dark@quad4.io",
    {
      version: "1.0.0",
      path: "resource://builtin-themes/void-dark/",
    },
  ],
  [
    "void-light@quad4.io",
    {
      version: "1.0.0",
      path: "resource://builtin-themes/void-light/",
    },
  ],
"""
if "void-dark@quad4.io" not in ctext:
    needle_map = "export const BuiltInThemeConfig = new Map(["
    if needle_map not in ctext:
        raise SystemExit("BuiltInThemeConfig map not found")
    cfg.write_text(ctext.replace(needle_map, needle_map + void_cfg, 1))

nav = src / "toolkit" / "content" / "widgets" / "moz-page-nav" / "moz-page-nav.css"
ntext = nav.read_text()
old_logo = '''    background: image-set(url("chrome://branding/content/about-logo.png"), url("chrome://branding/content/about-logo@2x.png") 2x) no-repeat center;
    background-size: auto;
    background-size: var(--page-nav-heading-logo-size);'''
new_logo = '''    background: url("chrome://branding/content/about-logo.svg") no-repeat center;
    background-size: var(--page-nav-heading-logo-size);
    -moz-context-properties: fill, fill-opacity;
    fill: currentColor;'''
if old_logo in ntext:
    nav.write_text(ntext.replace(old_logo, new_logo, 1))
elif "about-logo.svg" not in ntext:
    raise SystemExit("moz-page-nav logo rule not found")

about = src / "browser" / "base" / "content" / "aboutDialog.xhtml"
atext = about.read_text()
for old_href, new_href in (
    (
        "https://www.mozilla.org/?utm_source=firefox-browser&#38;utm_medium=firefox-desktop&#38;utm_campaign=about-dialog",
        "https://quad4.io/",
    ),
    (
        "https://foundation.mozilla.org/?form=firefox-about",
        "https://quad4.io/",
    ),
    (
        "https://www.mozilla.org/contribute/?utm_source=firefox-browser&#38;utm_medium=firefox-desktop&#38;utm_campaign=about-dialog",
        "https://quad4.io/",
    ),
    (
        "https://www.mozilla.org/about/legal/terms/firefox/",
        "https://quad4.io/",
    ),
    (
        "https://www.mozilla.org/privacy/firefox/?utm_source=firefox-browser&#38;utm_medium=firefox-desktop&#38;utm_campaign=about-dialog",
        "https://quad4.io/",
    ),
):
    atext = atext.replace(old_href, new_href)
about.write_text(atext)

tb = src / "browser" / "components" / "tabbrowser" / "content" / "tabbrowser.js"
tbtext = tb.read_text()
if '.join(" — ")' in tbtext:
    tb.write_text(tbtext.replace('.join(" — ")', '.join(" - ")', 1))

tokens = src / "toolkit" / "content" / "widgets" / "moz-page-nav" / "moz-page-nav.tokens.css"
tok = tokens.read_text()
tok = tok.replace(
    "--page-nav-heading-logo-size: var(--icon-size-large);",
    "--page-nav-heading-logo-size: 32px;",
    1,
)
tokens.write_text(tok)

bftl = src / "browser" / "locales" / "en-US" / "browser" / "browser.ftl"
btext = bftl.read_text()
bftl.write_text(btext.replace(" — Private Browsing", " - Private Browsing"))

xpi = src / "toolkit" / "mozapps" / "extensions" / "internal" / "XPIInstall.sys.mjs"
xt = xpi.read_text()
old_theme = '''        (!lastSelectedTheme.endsWith("@mozilla.org") &&
          addon.id === lazy.AddonSettings.DEFAULT_THEME_ID &&'''
new_theme = '''        (!lastSelectedTheme.includes("@") &&
          addon.id === lazy.AddonSettings.DEFAULT_THEME_ID &&'''
if old_theme in xt:
    xpi.write_text(xt.replace(old_theme, new_theme, 1))
elif '(!lastSelectedTheme.includes("@")' not in xt:
    raise SystemExit("XPIInstall selected-theme fallback not found")

addon_settings = src / "toolkit" / "mozapps" / "extensions" / "internal" / "AddonSettings.sys.mjs"
ast = addon_settings.read_text()
old_default_theme = """if (AppConstants.MOZ_DEV_EDITION) {
  makeConstant("DEFAULT_THEME_ID", "firefox-compact-dark@mozilla.org");
} else {
  makeConstant("DEFAULT_THEME_ID", "default-theme@mozilla.org");
}"""
new_default_theme = 'makeConstant("DEFAULT_THEME_ID", "void-dark@quad4.io");'
if 'makeConstant("DEFAULT_THEME_ID", "void-dark@quad4.io")' not in ast:
    if old_default_theme not in ast:
        raise SystemExit("AddonSettings DEFAULT_THEME_ID block not found")
    addon_settings.write_text(ast.replace(old_default_theme, new_default_theme, 1))

xpi_prov = src / "toolkit" / "mozapps" / "extensions" / "internal" / "XPIProvider.sys.mjs"
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
        raise SystemExit("XPIProvider default theme install not found")
    xpi_prov.write_text(xp.replace(old_builtin, new_builtin, 1))

built_in_themes = src / "browser" / "themes" / "BuiltInThemes.sys.mjs"
bit = built_in_themes.read_text()
old_fallback = 'kActiveThemePref,\n      "default-theme@mozilla.org"'
new_fallback = 'kActiveThemePref,\n      "void-dark@quad4.io"'
if old_fallback in bit:
    built_in_themes.write_text(bit.replace(old_fallback, new_fallback, 1))
elif new_fallback not in bit:
    raise SystemExit("BuiltInThemes active theme fallback not found")

glue = src / "browser" / "components" / "BrowserComponents.manifest"
gtext = glue.read_text()
lyra_app = "application={3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}"
ff_app = "application={ec8030f7-c20a-464f-9b0e-13a3a9e97384}"
if lyra_app not in gtext:
    if ff_app not in gtext:
        raise SystemExit("nsBrowserGlue app-startup entry not found")
    gtext = gtext.replace(ff_app, ff_app + " " + lyra_app, 1)
gtext = gtext.replace(
    "application={0af1bb40-ff0a-52c4-ad87-168205bd4170}",
    "application={3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}",
)
if "LyraSync.init" not in gtext:
    gtext = (
        gtext.rstrip()
        + "\ncategory browser-first-window-ready resource:///modules/LyraSync.sys.mjs LyraSync.init\n"
        + "category browser-first-window-ready resource:///modules/LyraOpenSearch.sys.mjs LyraOpenSearch.init\n"
    )
elif "LyraOpenSearch.init" not in gtext:
    gtext = (
        gtext.rstrip()
        + "\ncategory browser-first-window-ready resource:///modules/LyraOpenSearch.sys.mjs LyraOpenSearch.init\n"
    )
if "LyraScriptBlock.init" not in gtext:
    gtext = (
        gtext.rstrip()
        + "\ncategory browser-before-ui-startup resource:///modules/LyraScriptBlock.sys.mjs LyraScriptBlock.init\n"
    )
if "LyraHistory.init" not in gtext:
    gtext = (
        gtext.rstrip()
        + "\ncategory browser-before-ui-startup resource:///modules/LyraHistory.sys.mjs LyraHistory.init\n"
    )
glue.write_text(gtext)

# Unlock the profile database encryption pref so users can opt in.
alljs = src / "modules" / "libpref" / "init" / "all.js"
atext2 = alljs.read_text()
locked = 'pref("security.storage.encryption.sqlite.enabled", false, locked);'
unlocked = 'pref("security.storage.encryption.sqlite.enabled", false);'
if locked in atext2:
    alljs.write_text(atext2.replace(locked, unlocked, 1))
elif unlocked not in atext2:
    raise SystemExit("security.storage.encryption.sqlite.enabled pref not found")

mods = src / "browser" / "modules" / "moz.build"
mbuild = mods.read_text()
for mod_name in ("LyraHistory.sys.mjs", "LyraOpenSearch.sys.mjs", "LyraScriptBlock.sys.mjs", "LyraSync.sys.mjs"):
    if f'"{mod_name}"' in mbuild:
        continue
    lines = mbuild.splitlines(keepends=True)
    new_lines = []
    in_modules = False
    done = False
    for line in lines:
        if not done:
            stripped = line.strip()
            if not in_modules:
                if stripped.startswith("EXTRA_JS_MODULES += ["):
                    in_modules = True
            elif stripped.startswith('"'):
                name = stripped.strip(",").strip('"')
                if name > mod_name:
                    indent = line[: len(line) - len(line.lstrip())]
                    new_lines.append(f'{indent}"{mod_name}",\n')
                    done = True
                    in_modules = False
            elif stripped.startswith("]"):
                raise SystemExit(
                    "browser/modules/moz.build EXTRA_JS_MODULES insertion point not found"
                )
        new_lines.append(line)
    if not done:
        raise SystemExit(
            "EXTRA_JS_MODULES list not found in browser/modules/moz.build"
        )
    mbuild = "".join(new_lines)
mods.write_text(mbuild)

prefs_js = src / "browser" / "components" / "preferences" / "preferences.js"
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
      "voidProtections",
      "voidScripts",
      "voidStorage",
      "voidHistory",
      "voidSync",
      "voidCompat",
    ],
    module: "chrome://browser/content/preferences/config/void.mjs",
  },
"""
if "voidPrivacy:" not in ptext:
    needle_panes = "const CONFIG_PANES = Object.freeze({\n"
    if needle_panes not in ptext:
        raise SystemExit("CONFIG_PANES not found")
    ptext = ptext.replace(needle_panes, needle_panes + void_pane, 1)
elif '"voidSync"' not in ptext:
    ptext = ptext.replace(
        '"voidDns",\n      "voidCompat",',
        '"voidDns",\n      "voidSync",\n      "voidCompat",',
        1,
    )
if '"voidProtections"' not in ptext:
    ptext = ptext.replace(
        '"voidDns",\n',
        '"voidDns",\n      "voidProtections",\n'
        '      "voidScripts",\n      "voidStorage",\n'
        '      "voidHistory",\n',
        1,
    )
ptext = ptext.replace(
    'module: "chrome://browser/content/preferences/config/SettingGroupManager.mjs"',
    'module: "chrome://browser/content/preferences/config/void.mjs"',
)
start = ptext.find("\ntry {\n  ChromeUtils.importESModule(\n    \"chrome://browser/content/preferences/config/void.mjs\"")
if start != -1:
    end = ptext.find('document.addEventListener("DOMContentLoaded", init_all, { once: true });', start)
    if end != -1:
        ptext = ptext[:start] + "\n" + ptext[end:]
prefs_js.write_text(ptext)

sgm = src / "browser" / "components" / "preferences" / "config" / "SettingGroupManager.mjs"
stext = sgm.read_text()
if "voidFingerprint" in stext:
    stock_end = """  registerGroups(groupConfigs) {
    for (let id in groupConfigs) {
      this.registerGroup(id, groupConfigs[id]);
    }
  },
};
"""
    idx = stext.find(stock_end)
    if idx == -1:
        raise SystemExit("SettingGroupManager.mjs stock ending not found")
    restored = stext[: idx + len(stock_end)]
    restored = restored.replace(
        'import { Preferences } from "chrome://global/content/preferences/Preferences.mjs";\n\n',
        "",
        1,
    )
    sgm.write_text(restored)

prefs_jar = src / "browser" / "components" / "preferences" / "jar.mn"
jprefs = prefs_jar.read_text()
if "config/void.mjs" not in jprefs:
    lines = jprefs.splitlines(keepends=True)
    out = []
    inserted = False
    for line in lines:
        out.append(line)
        if (not inserted) and "content/browser/preferences/config/privacy.mjs" in line:
            out.append(
                "   content/browser/preferences/config/void.mjs                          (config/void.mjs)\n"
            )
            inserted = True
    if not inserted:
        raise SystemExit("preferences jar.mn privacy.mjs entry not found")
    prefs_jar.write_text("".join(out))

pxhtml = src / "browser" / "components" / "preferences" / "preferences.xhtml"
xtext = pxhtml.read_text()
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
        raise SystemExit("privacy nav button not found")
    xtext = xtext.replace(nav_anchor, nav_anchor + nav, 1)
if 'href="browser/preferences/void.ftl"' not in xtext:
    ftl_anchor = '<link rel="localization" href="browser/preferences/preferences.ftl"/>'
    if ftl_anchor not in xtext:
        raise SystemExit("preferences.ftl localization link not found")
    xtext = xtext.replace(
        ftl_anchor,
        ftl_anchor + '\n  <link rel="localization" href="browser/preferences/void.ftl"/>',
        1,
    )
pxhtml.write_text(xtext)

# Lyra themes: register jars and BuiltInThemeConfig entries.
new_themes = ["void-ember", "void-forest", "void-ocean", "void-linen"]
jar = src / "browser" / "themes" / "addons" / "jar.mn"
jtext = jar.read_text()
extra_jar = ""
for theme in new_themes:
    extra_jar += (
        f"\n  content/builtin-themes/{theme}/preview.svg    ({theme}/preview.svg)"
        f"\n  content/builtin-themes/{theme}/icon.svg       ({theme}/icon.svg)"
        f"\n  content/builtin-themes/{theme}/manifest.json  ({theme}/manifest.json)\n"
    )
if "void-ember/manifest.json" not in jtext:
    jar.write_text(jtext.rstrip() + "\n" + extra_jar + "\n")

cfg = src / "browser" / "themes" / "BuiltInThemeConfig.sys.mjs"
ctext = cfg.read_text()
extra_cfg = ""
for theme in new_themes:
    extra_cfg += (
        f'\n  [\n    "{theme}@quad4.io",'
        f'\n    {{\n      version: "1.0.0",'
        f'\n      path: "resource://builtin-themes/{theme}/",'
        f'\n    }},\n  ],\n'
    )
if "void-ember@quad4.io" not in ctext:
    needle_map = "export const BuiltInThemeConfig = new Map(["
    if needle_map not in ctext:
        raise SystemExit("BuiltInThemeConfig map not found")
    cfg.write_text(ctext.replace(needle_map, needle_map + extra_cfg, 1))

# Toolbar: put the Save Page button in the navbar defaults.
cui = src / "browser" / "components" / "customizableui" / "CustomizableUI.sys.mjs"
cuitext = cui.read_text()
needle = '"downloads-button",\n'
inserted = needle + '      "save-page-button",\n'
if inserted not in cuitext:
    if needle not in cuitext:
        raise SystemExit("navbar downloads-button placement not found")
    cuitext = cuitext.replace(needle, inserted, 1)
    cui.write_text(cuitext)

# The screenshot widget places itself after the urlbar when the Nimbus
# variable is true. Lyra always wants it, so make the check unconditional.
ssu = src / "browser" / "components" / "screenshots" / "ScreenshotsUtils.sys.mjs"
sstext = ssu.read_text()
needle = 'lazy.NimbusFeatures.screenshots.getVariable("buttonOnToolbarByDefault")'
if needle in sstext:
    ssu.write_text(sstext.replace(needle, "true", 1))

# Emit an observer notification whenever the selected tab offers engines,
# so LyraOpenSearch can prompt on load and on tab switch.
osm = src / "browser" / "components" / "search" / "OpenSearchManager.sys.mjs"
otext = osm.read_text()
if "lyra-opensearch-offered" not in otext:
    needle = '    let searchBar = win.document.getElementById("searchbar");\n'
    if needle not in otext:
        raise SystemExit("updateOpenSearchBadge hook point not found")
    otext = otext.replace(
        needle,
        '    if (engines && engines.length) {\n'
        '      Services.obs.notifyObservers(win, "lyra-opensearch-offered");\n'
        '    }\n\n' + needle,
        1,
    )
    osm.write_text(otext)

# Tab context menu: add "Set as Default Search Engine" when the tab page
# offers an installable OpenSearch engine.
inc = src / "browser" / "base" / "content" / "main-popupset.inc.xhtml"
itext = inc.read_text()
if "context_lyraSetSearchDefault" not in itext:
    needle = '    <menu id="context_moveTabOptions"'
    if needle not in itext:
        raise SystemExit("tab context menu insert point not found")
    itext = itext.replace(
        needle,
        '    <menuitem id="context_lyraSetSearchDefault"\n'
        '              data-lazy-l10n-id="lyra-tab-context-set-search-default"\n'
        '              hidden="true"/>\n' + needle,
        1,
    )
    inc.write_text(itext)

mps = src / "browser" / "base" / "content" / "main-popupset.js"
mptext = mps.read_text()
if "context_lyraSetSearchDefault" not in mptext:
    needle = "        // == tabContextMenu ==\n"
    if needle not in mptext:
        raise SystemExit("tabContextMenu command section not found")
    mptext = mptext.replace(
        needle,
        needle + '        case "context_lyraSetSearchDefault":\n'
        '          TabContextMenu.LyraOpenSearch.setDefaultFromTab(\n'
        '            TabContextMenu.contextTab\n'
        '          );\n          break;\n',
        1,
    )
    mps.write_text(mptext)

tb3 = src / "browser" / "components" / "tabbrowser" / "content" / "tabbrowser.js"
tbtext = tb3.read_text()
if "LyraOpenSearch" not in tbtext:
    needle = "ChromeUtils.defineESModuleGetters(TabContextMenu, {"
    if needle not in tbtext:
        raise SystemExit("TabContextMenu lazy getters not found")
    tbtext = tbtext.replace(
        needle,
        needle + '\n  LyraOpenSearch: "resource:///modules/LyraOpenSearch.sys.mjs",',
        1,
    )
    needle = "    this.multiselected = this.contextTab.multiselected;\n"
    if needle not in tbtext:
        raise SystemExit("updateContextMenu multiselected line not found")
    tbtext = tbtext.replace(
        needle,
        needle
        + '    document.getElementById("context_lyraSetSearchDefault").hidden =\n'
        '      this.multiselected ||\n'
        '      !this.LyraOpenSearch.getOfferedEngine(this.contextTab);\n',
        1,
    )
    tb3.write_text(tbtext)

tcmftl = src / "browser" / "locales" / "en-US" / "browser" / "tabContextMenu.ftl"
ftext = tcmftl.read_text()
if "lyra-tab-context-set-search-default" not in ftext:
    tcmftl.write_text(
        ftext.rstrip()
        + """

# Shown in the tab context menu when the page offers an OpenSearch engine
# that is not installed yet.
lyra-tab-context-set-search-default =
    .label = Set as Default Search Engine
"""
    )

# about:lyrasetup first-run page and about:lyrahistory search page.
redir = src / "browser" / "components" / "about" / "AboutRedirector.cpp"
rtext = redir.read_text()
for page, target in (
    ("lyrasetup", "lyra/setup.xhtml"),
    ("lyrahistory", "lyra/history.xhtml"),
):
    if f'"{page}"' in rtext:
        continue
    needle = '    {"welcomeback",'
    if needle not in rtext:
        raise SystemExit("AboutRedirector insertion point not found")
    rtext = rtext.replace(
        needle,
        f'    {{"{page}", "chrome://browser/content/{target}",\n'
        "     nsIAboutModule::ALLOW_SCRIPT | nsIAboutModule::IS_SECURE_CHROME_UI},\n"
        + needle,
        1,
    )
redir.write_text(rtext)

aconf = src / "browser" / "components" / "about" / "components.conf"
actext = aconf.read_text()
for page in ("'lyrahistory'", "'lyrasetup'"):
    if page not in actext:
        needle = "    'logins',\n"
        if needle not in actext:
            raise SystemExit("about components.conf insertion point not found")
        actext = actext.replace(needle, needle + "    " + page + ",\n", 1)
aconf.write_text(actext)

# Page files packaged via a jar.mn in the lyra component dir. DIRS must
# stay sorted; "lyra" lands between "ipprotection" and "messagepreview".
components_mozbuild = src / "browser" / "components" / "moz.build"
cmtext = components_mozbuild.read_text()
if '"lyra"' not in cmtext:
    needle = '    "messagepreview",\n'
    if needle not in cmtext:
        raise SystemExit("browser/components/moz.build DIRS anchor not found")
    cmtext = cmtext.replace(needle, '    "lyra",\n' + needle, 1)
    components_mozbuild.write_text(cmtext)

# Decentraleyes-style local substitutions for common CDN libraries.
import re
shimsjs = src / "browser" / "extensions" / "webcompat" / "data" / "shims.js"
stext = shimsjs.read_text()
stext = re.sub(r"  \{\n    id: \"LyraCdn[\s\S]*?  \},\n", "", stext)
if True:
    entries = ""
    for v in ("3.7.1", "3.6.0", "3.5.1", "3.4.1", "2.2.4", "1.12.4", "1.11.3"):
        entries += (
            "  {\n"
            '    id: "LyraCdnJquery-' + v + '",\n'
            '    platform: "all",\n'
            '    name: "jQuery ' + v + ' (local)",\n'
            '    file: "lyra-jquery-' + v + '.min.js",\n'
            "    matches: [\n"
            '      "*://ajax.googleapis.com/ajax/libs/jquery/' + v + '/jquery.min.js*",\n'
            '      "*://code.jquery.com/jquery-' + v + '.min.js*",\n'
            '      "*://cdnjs.cloudflare.com/ajax/libs/jquery/' + v + '/jquery.min.js*",\n'
            '      "*://cdn.jsdelivr.net/npm/jquery@' + v + '/dist/jquery.min.js*",\n'
            "    ],\n"
            "  },\n"
        )
    entries += (
        "  {\n"
        '    id: "LyraCdnUnderscore",\n'
        '    platform: "all",\n'
        '    name: "Underscore.js 1.13.6 (local)",\n'
        '    file: "lyra-underscore-1.13.6-min.js",\n'
        "    matches: [\n"
        '      "*://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.13.6/underscore-min.js*",\n'
        '      "*://cdn.jsdelivr.net/npm/underscore@1.13.6/underscore-min.js*",\n'
        "    ],\n"
        "  },\n"
        "  {\n"
        '    id: "LyraCdnBackbone",\n'
        '    platform: "all",\n'
        '    name: "Backbone.js 1.4.1 (local)",\n'
        '    file: "lyra-backbone-1.4.1.min.js",\n'
        "    matches: [\n"
        '      "*://cdnjs.cloudflare.com/ajax/libs/backbone.js/1.4.1/backbone-min.js*",\n'
        '      "*://cdn.jsdelivr.net/npm/backbone@1.4.1/backbone-min.js*",\n'
        '      "*://unpkg.com/backbone@1.4.1/backbone-min.js*",\n'
        "    ],\n"
        "  },\n"
    )
    needle = "];\n\nif (typeof module"
    if needle not in stext:
        raise SystemExit("shims.js AVAILABLE_SHIMS end not found")
    shimsjs.write_text(stext.replace(needle, entries + needle, 1))

manifest = src / "browser" / "extensions" / "webcompat" / "manifest.json"
mtext = manifest.read_text()
mtext = re.sub(r'\n\s+"shims/lyra-[^"]+",?', "", mtext)
mtext = re.sub(r",(\s*\])", r"\1", mtext)
if True:
    lines = [
        '"shims/lyra-backbone-1.4.1.min.js"',
        '"shims/lyra-jquery-1.11.3.min.js"',
        '"shims/lyra-jquery-1.12.4.min.js"',
        '"shims/lyra-jquery-2.2.4.min.js"',
        '"shims/lyra-jquery-3.4.1.min.js"',
        '"shims/lyra-jquery-3.5.1.min.js"',
        '"shims/lyra-jquery-3.6.0.min.js"',
        '"shims/lyra-jquery-3.7.1.min.js"',
        '"shims/lyra-underscore-1.13.6-min.js"',
    ]
    anchor = '    "shims/zendesk-asana-support.js"'
    if anchor not in mtext:
        raise SystemExit("webcompat manifest shims anchor not found")
    mtext = mtext.replace(
        anchor, anchor + ",\n    " + ",\n    ".join(lines), 1
    )
    manifest.write_text(mtext)

# Search engine lineup: drop Perplexity and all Wikipedia variants, add
# Wiby, Brave Search and two SearXNG instances.
scfg = src / "services" / "settings" / "dumps" / "main" / "search-config-v2.json"
scfg_data = json.loads(scfg.read_text())
records = scfg_data["data"]
keep = [
    r
    for r in records
    if not (
        r.get("recordType") == "engine"
        and str(r.get("identifier", "")).startswith(("perplexity", "wikipedia"))
    )
]
if not any(r.get("identifier") == "brave" for r in keep):
    def lyra_engine(identifier, name, base_url, uuid):
        return {
            "base": {
                "name": name,
                "classification": "general",
                "urls": {
                    "search": {
                        "base": base_url,
                        "searchTermParamName": "q",
                    }
                },
            },
            "id": uuid,
            "identifier": identifier,
            "last_modified": 1759300000000,
            "recordType": "engine",
            "schema": 1772067581442,
            "variants": [
                {
                    "environment": {
                        "allRegionsAndLocales": True,
                        "applications": ["firefox"],
                    }
                }
            ],
        }

    keep += [
        lyra_engine(
            "wiby",
            "Wiby",
            "https://wiby.me/",
            "5a8b2c77-fb9d-4b88-945b-1a4baf62d55a",
        ),
        lyra_engine(
            "brave",
            "Brave Search",
            "https://search.brave.com/search",
            "c67d8e43-e8d9-4326-89d8-9ddc93b989a0",
        ),
        lyra_engine(
            "searx-be",
            "SearXNG (searx.be)",
            "https://searx.be/search",
            "56c85d79-f585-46bf-b51b-1204a66921e6",
        ),
        lyra_engine(
            "searx-privau",
            "SearXNG (priv.au)",
            "https://priv.au/search",
            "de8818fe-a115-4294-998d-f80df4540684",
        ),
    ]
    for r in keep:
        if r.get("recordType") == "defaultEngines":
            r["globalDefault"] = "brave"
    scfg_data["data"] = keep
    scfg.write_text(json.dumps(scfg_data, indent=1) + "\n")

# Remote settings can re-add dropped engines after sync, so the selector
# filters them out at runtime as well.
ses = src / "toolkit" / "components" / "search" / "SearchEngineSelector.sys.mjs"
setext = ses.read_text()
LYRA_ENGINE_FILTER = """    refinedSearchConfig.engines = refinedSearchConfig.engines.filter(
      e => !/^(perplexity|wikipedia)/.test(e.identifier)
    );
"""
if "perplexity|wikipedia" not in setext:
    needle = """    refinedSearchConfig.engines = refinedSearchConfig.engines.filter(
      e => !e.optional
    );
"""
    if needle not in setext:
        raise SystemExit("SearchEngineSelector filter point not found")
    setext = setext.replace(needle, needle + LYRA_ENGINE_FILTER, 1)

needle2 = """    for (let config of this.#configuration) {
      if (config.recordType !== "engine") {
        continue;
      }
      let searchHost"""
if "lyraRemovedEngine" not in setext:
    if needle2 not in setext:
        raise SystemExit("SearchEngineSelector contextual host loop not found")
    setext = setext.replace(
        needle2,
        """    for (let config of this.#configuration) {
      if (config.recordType !== "engine") {
        continue;
      }
      const lyraRemovedEngine = /^(perplexity|wikipedia)/.test(
        config.identifier
      );
      if (lyraRemovedEngine) {
        continue;
      }
      let searchHost""",
        1,
    )
ses.write_text(setext)

print("source tree edits applied")
PY

if [[ -f "$SRC/mozconfig" ]]; then
  echo "keeping existing $SRC/mozconfig"
else
  cat "$ROOT/mozconfig" "$ROOT/mozconfig.linux" > "$SRC/mozconfig"
  echo "wrote $SRC/mozconfig"
fi

echo "overlay complete"
