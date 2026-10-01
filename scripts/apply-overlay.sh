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

echo "overlay Void settings pane"
mkdir -p "$SRC/browser/components/preferences/config"
cp -f "$ROOT/overlay/browser/components/preferences/config/void.mjs" "$SRC/browser/components/preferences/config/void.mjs"

echo "overlay Void themes"
copy_tree "$ROOT/overlay/browser/themes/addons/void-dark" "$SRC/browser/themes/addons/void-dark"
copy_tree "$ROOT/overlay/browser/themes/addons/void-light" "$SRC/browser/themes/addons/void-light"

python3 - "$SRC" <<'PY'
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
    )
glue.write_text(gtext)

mods = src / "browser" / "modules" / "moz.build"
mbuild = mods.read_text()
if '"LyraSync.sys.mjs"' not in mbuild:
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
                if name > "LyraSync.sys.mjs":
                    indent = line[: len(line) - len(line.lstrip())]
                    new_lines.append(f'{indent}"LyraSync.sys.mjs",\n')
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
    mods.write_text("".join(new_lines))

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

print("source tree edits applied")
PY

if [[ -f "$SRC/mozconfig" ]]; then
  echo "keeping existing $SRC/mozconfig"
else
  cat "$ROOT/mozconfig" "$ROOT/mozconfig.linux" > "$SRC/mozconfig"
  echo "wrote $SRC/mozconfig"
fi

echo "overlay complete"
