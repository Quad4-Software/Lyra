#!/usr/bin/env python3
# Validate Lyra layout, JSON, and privacy policy invariants.

"""CI entry point. Does not compile Firefox."""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
WARNS: list[str] = []


def error(msg: str) -> None:
    ERRORS.append(msg)


def warn(msg: str) -> None:
    WARNS.append(msg)


def require(path: Path) -> None:
    if not path.exists():
        error(f"missing {path.relative_to(ROOT)}")


def load_version() -> dict[str, str]:
    data: dict[str, str] = {}
    path = ROOT / "VERSION"
    require(path)
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key] = value
    for key in (
        "VOID_VERSION",
        "LYRA_APP_ID",
        "FIREFOX_VERSION",
        "FIREFOX_SOURCE_URL",
        "FIREFOX_SOURCE_SHA256",
        "UBLOCK_VERSION",
        "UBLOCK_XPI_SHA256",
        "UBLOCK_ID",
    ):
        if key not in data:
            error(f"VERSION missing {key}")
    if data.get("FIREFOX_VERSION") and not data["FIREFOX_VERSION"].endswith("esr"):
        warn("FIREFOX_VERSION is not an ESR tag")
    if "firefox.com" in data.get("FIREFOX_SOURCE_URL", "") and "releases" not in data.get(
        "FIREFOX_SOURCE_URL", ""
    ):
        warn("unexpected Firefox source URL")
    return data


def check_json(path: Path) -> object | None:
    require(path)
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        error(f"invalid JSON {path.relative_to(ROOT)}: {exc}")
        return None


def check_policies(data: object | None) -> None:
    if not isinstance(data, dict):
        return
    policies = data.get("policies")
    if not isinstance(policies, dict):
        error("policies.json missing policies object")
        return
    for key in (
        "DisableTelemetry",
        "DisableFirefoxStudies",
        "DisablePocket",
        "DisableFirefoxAccounts",
        "NoDefaultBookmarks",
        "DisableAppUpdate",
    ):
        if policies.get(key) is not True:
            error(f"policies.json {key} must be true")
    home = policies.get("FirefoxHome", {})
    if isinstance(home, dict):
        for key in ("SponsoredTopSites", "Pocket", "SponsoredPocket"):
            if home.get(key) is not False:
                error(f"policies.json FirefoxHome.{key} must be false")
    ext = policies.get("ExtensionSettings", {})
    ublock = ext.get("uBlock0@raymondhill.net") if isinstance(ext, dict) else None
    if not isinstance(ublock, dict):
        error("policies.json missing uBlock Origin ExtensionSettings")
    else:
        if ublock.get("installation_mode") != "force_installed":
            error("uBlock Origin must be force_installed")
        if "ublock-origin" not in str(ublock.get("install_url", "")):
            error("uBlock Origin install_url should point at AMO ublock-origin")
    doh = policies.get("DNSOverHTTPS", {})
    if not isinstance(doh, dict):
        error("policies.json missing DNSOverHTTPS")
    else:
        if doh.get("Enabled") is not True:
            error("policies.json DNSOverHTTPS.Enabled must be true")
        if doh.get("Locked") is not False:
            error("policies.json DNSOverHTTPS must not be locked")
        provider = str(doh.get("ProviderURL", ""))
        if "doh.dns.sb" not in provider:
            error("policies.json DNSOverHTTPS.ProviderURL must be dns.sb")
        if doh.get("Fallback") is not True:
            error("policies.json DNSOverHTTPS.Fallback must be true")
    text = json.dumps(data)
    for banned in ("telemetry.mozilla.org", "incoming.telemetry", "pocket.com"):
        if banned in text.lower():
            error(f"policies.json should not phone home to {banned}")


def check_void_cfg() -> None:
    path = ROOT / "prefs" / "void.cfg"
    require(path)
    if not path.exists():
        return
    raw = path.read_text()
    if not raw.startswith("\n"):
        error("prefs/void.cfg first line must be empty")
    for needle in (
        'lockPref("toolkit.telemetry.enabled", false)',
        'lockPref("datareporting.policy.dataSubmissionEnabled", false)',
        'lockPref("app.normandy.enabled", false)',
        'lockPref("browser.vpn_promo.enabled", false)',
        'lockPref("browser.shopping.experience2023.enabled", false)',
        'defaultPref("privacy.fingerprintingProtection", true)',
        'defaultPref("void.fingerprint.mode", "firefox")',
        'defaultPref("network.trr.mode", 2)',
        'defaultPref("network.trr.uri", "https://doh.dns.sb/dns-query")',
        'defaultPref("gfx.bundled-fonts.activate", 1)',
        'defaultPref("privacy.resistFingerprinting.letterboxing", false)',
        'defaultPref("void.typing.protection", true)',
        'defaultPref("void.timezone.spoof", true)',
        'defaultPref("void.audio.protection", true)',
        'defaultPref("void.webrtc.protect", true)',
        'defaultPref("void.sensors.block", true)',
        'defaultPref("void.geo.block", true)',
        'defaultPref("void.sync.enabled", false)',
        'defaultPref("void.sync.server", "wss://socket.quad4.io/ws")',
        'defaultPref("geo.enabled", false)',
        'defaultPref("media.peerconnection.ice.no_host", true)',
        'defaultPref("network.http.referer.XOriginPolicy", 2)',
        'defaultPref("identity.fxaccounts.enabled", false)',
        'defaultPref("extensions.activeThemeID", "void-dark@quad4.io")',
        'defaultPref("ui.systemUsesDarkTheme", 1)',
    ):
        if needle not in raw:
            error(f"prefs/void.cfg missing {needle}")
    if "telemetry.mozilla.org" in raw:
        error("void.cfg must not set a Mozilla telemetry server URL")
    if "landlock" in raw.lower():
        error("void.cfg must not wrap the browser with Landlock")
    if "+JSDateTimeUTC" not in raw:
        error("void.cfg FPP overrides must include JSDateTimeUTC timezone spoof")
    if 'lockPref("void.cfg.version"' not in raw:
        error("void.cfg missing version lockPref")


def check_branding() -> None:
    brand = ROOT / "branding" / "void" / "firefox"
    require(brand / "configure.sh")
    require(brand / "locales" / "en-US" / "brand.ftl")
    require(brand / "locales" / "en-US" / "brand.properties")
    require(brand / "pref" / "firefox-branding.js")
    require(brand / "content" / "about-logo.svg")
    require(brand / "content" / "about-wordmark.svg")
    logo = (brand / "content" / "about-logo.svg").read_text() if (brand / "content" / "about-logo.svg").exists() else ""
    if '<rect' in logo and 'fill="#0A0A0B"' in logo:
        error("about-logo.svg must be a transparent mark, not a canvas square")
    if "context-fill" not in logo:
        error("about-logo.svg must use context-fill so policies/settings follow page color")
    for theme in ("void-dark", "void-light"):
        tdir = ROOT / "overlay" / "browser" / "themes" / "addons" / theme
        require(tdir / "manifest.json")
        require(tdir / "icon.svg")
        require(tdir / "preview.svg")
        data = json.loads((tdir / "manifest.json").read_text()) if (tdir / "manifest.json").exists() else {}
        gecko_id = ((data.get("browser_specific_settings") or {}).get("gecko") or {}).get("id")
        if gecko_id != f"{theme}@quad4.io":
            error(f"{theme} manifest id must be {theme}@quad4.io")
    ftl_overlay = ROOT / "overlay" / "browser" / "locales" / "en-US" / "browser"
    require(ftl_overlay / "aboutDialog.ftl")
    require(ftl_overlay / "aboutPolicies.ftl")
    for ftl in (ftl_overlay / "aboutDialog.ftl", ftl_overlay / "aboutPolicies.ftl"):
        raw = ftl.read_text() if ftl.exists() else ""
        if "\u2014" in raw or "\u2013" in raw:
            error(f"{ftl.relative_to(ROOT)} contains an em dash or en dash")
        if "global community" in raw.lower() or "want to help" in raw.lower():
            error(f"{ftl.relative_to(ROOT)} still has Mozilla marketing copy")
    void_ftl = ROOT / "overlay" / "browser" / "locales" / "en-US" / "browser" / "preferences" / "void.ftl"
    require(void_ftl)
    if void_ftl.exists():
        raw = void_ftl.read_text()
        if "\u2014" in raw or "\u2013" in raw:
            error("void.ftl contains an em dash or en dash")
        if "void-fingerprint-mode-firefox" not in raw:
            error("void.ftl missing Firefox crowd mode strings")
        if "void-timezone-spoof" not in raw:
            error("void.ftl missing timezone spoof strings")
        if "void-sync-enabled" not in raw:
            error("void.ftl missing P2P sync strings")
        if "Void Browser" in raw:
            error("void.ftl must not use the taken product name Void Browser")
    require(ROOT / "overlay" / "browser" / "components" / "preferences" / "config" / "void.mjs")
    ftl = (brand / "locales" / "en-US" / "brand.ftl").read_text() if (brand / "locales" / "en-US" / "brand.ftl").exists() else ""
    for line in ftl.splitlines():
        if line.startswith("-brand-") and "Firefox" in line.split("=", 1)[-1]:
            error("brand.ftl must not use Firefox as the product name")
    if "-brand-full-name = Lyra" not in ftl:
        error("brand.ftl must name the product Lyra")
    if "-vendor-short-name = Quad4" not in ftl:
        error("brand.ftl must name the vendor Quad4")
    if "Void Browser" in ftl:
        error("brand.ftl must not use the taken product name Void Browser")
    cfg = (brand / "configure.sh").read_text() if (brand / "configure.sh").exists() else ""
    if "MOZ_APP_DISPLAYNAME=Lyra" not in cfg:
        error("configure.sh MOZ_APP_DISPLAYNAME must be Lyra")
    if "MOZ_MACBUNDLE_ID=io.quad4.lyra" not in cfg:
        error("configure.sh MOZ_MACBUNDLE_ID must be io.quad4.lyra")
    mozconfig = (ROOT / "mozconfig").read_text()
    if "--with-app-name=lyra" not in mozconfig:
        error("mozconfig must set --with-app-name=lyra")
    if "MOZ_APP_REMOTINGNAME=lyra" not in mozconfig:
        error("mozconfig must set MOZ_APP_REMOTINGNAME=lyra")
    if "--with-app-basename=Lyra" not in mozconfig:
        error("mozconfig must set --with-app-basename=Lyra")
    if "--enable-bundled-fonts" not in mozconfig:
        error("mozconfig must enable bundled fonts")
    win_moz = (ROOT / "mozconfig.windows").read_text() if (ROOT / "mozconfig.windows").exists() else ""
    if "--enable-bundled-fonts" not in win_moz:
        error("mozconfig.windows must enable bundled fonts")
    if "cairo-windows" not in win_moz:
        error("mozconfig.windows must set cairo-windows")
    for size in (16, 22, 24, 32, 48, 64, 128, 256):
        require(brand / f"default{size}.png")
    require(brand / "firefox.ico")
    require(brand / "content" / "about-logo.png")
    assets = ROOT / "branding" / "void" / "assets"
    require(assets / "quad4-mark.svg")
    require(assets / "quad4-lockup-on-dark.svg")
    require(assets / "favicon.svg")


def check_layout() -> None:
    for rel in (
        "README.md",
        "LICENSE",
        "NOTICE",
        "mozconfig",
        "mozconfig.linux",
        "mozconfig.windows",
        "policies/policies.json",
        "prefs/autoconfig.js",
        "prefs/void-overrides.cfg.example",
        "overlay/browser/components/preferences/config/void.mjs",
        "overlay/browser/locales/en-US/browser/preferences/void.ftl",
        "overlay/browser/modules/LyraSync.sys.mjs",
        "overlay/linux/io.quad4.lyra.desktop",
        "patches/series",
        "patches/0001-set-void-branding-directory.patch",
        "scripts/fetch-firefox.sh",
        "scripts/apply-overlay.sh",
        "scripts/package-extras.sh",
        "scripts/bootstrap-linux.sh",
        "extensions/ublock/pin.json",
        "extensions/ublock/fetch.sh",
        "docs/BUILD.md",
        "docs/SECURITY-UPDATES.md",
        "docs/BRANDING.md",
        "docs/PRIVACY.md",
        "docs/EXTENSIONS.md",
        "docs/STATUS.md",
        ".github/workflows/validate.yml",
        ".github/workflows/build.yml",
        ".github/dependabot.yml",
    ):
        require(ROOT / rel)
    autoconfig = (ROOT / "prefs" / "autoconfig.js").read_text()
    if 'pref("general.config.filename", "void.cfg")' not in autoconfig:
        error("autoconfig.js must point at void.cfg")
    if 'pref("general.config.sandbox_enabled", false)' not in autoconfig:
        error("autoconfig.js must disable the autoconfig sandbox so overrides can load")
    overlay = (ROOT / "scripts" / "apply-overlay.sh").read_text()
    if 'makeConstant("DEFAULT_THEME_ID", "void-dark@quad4.io")' not in overlay:
        error("apply-overlay.sh must set DEFAULT_THEME_ID to void-dark")
    if "resource://builtin-themes/void-dark/" not in overlay:
        error("apply-overlay.sh must install void-dark as a builtin theme at startup")
    if "application={3a3a4f99-f5ed-5ace-b1c2-6ca778f01a59}" not in overlay:
        error("apply-overlay.sh must register the Lyra app id with nsBrowserGlue")
    if 'imply_option("MOZ_APP_PROFILE", "lyra")' not in overlay:
        error("apply-overlay.sh must set MOZ_APP_PROFILE to lyra")
    if "about-logo.svg" not in overlay:
        error("apply-overlay.sh must point moz-page-nav at about-logo.svg")
    if 'lastSelectedTheme.includes("@")' not in overlay:
        error("apply-overlay.sh must keep @quad4.io themes from resetting to the default theme")
    if "voidSpoof" not in overlay:
        error("apply-overlay.sh must register the timezone and leak settings group")
    if "LyraSync.init" not in overlay:
        error("apply-overlay.sh must start LyraSync on first window")
    if 'module: "chrome://browser/content/preferences/config/void.mjs"' not in overlay:
        error("apply-overlay.sh must load Quad4 settings from void.mjs")
    if "Void settings failed to register" in overlay:
        error("apply-overlay.sh must not concatenate Quad4 settings into SettingGroupManager.mjs")
    extras = (ROOT / "scripts" / "package-extras.sh").read_text()
    if "aboutDialog.xhtml preprocessed for dist" not in extras:
        error("package-extras.sh must preprocess aboutDialog.xhtml for unpacked dist chrome")
    if "preferences/config/void.mjs" not in extras:
        error("package-extras.sh must install the Quad4 settings pane into dist")
    if "LyraSync.sys.mjs" not in extras:
        error("package-extras.sh must install LyraSync into dist")
    if "resource://builtin-themes/void-dark/" not in extras:
        error("package-extras.sh must install void-dark as a builtin theme at startup")
    if "ln -sfn lyra" not in extras:
        error("package-extras.sh must make void and quad4 symlinks to the lyra binary")
    if "brand.ftl" not in extras:
        error("package-extras.sh must stamp Quad4 brand.ftl into dist")
    if "Void settings failed to register" in extras:
        error("package-extras.sh must not concatenate Quad4 settings into SettingGroupManager.mjs")
    desktop = (ROOT / "overlay" / "linux" / "io.quad4.lyra.desktop").read_text()
    if "Exec=lyra" not in desktop:
        error("desktop file must launch the lyra binary")
    if "StartupWMClass=lyra" not in desktop:
        error("desktop file must use WM class lyra")
    workflow = (ROOT / ".github" / "workflows" / "validate.yml").read_text()
    if "windows-latest" not in workflow:
        error("validate.yml must run on windows-latest")
    if "persist-credentials: false" not in workflow:
        error("validate.yml checkout must set persist-credentials false")
    build_wf = (ROOT / ".github" / "workflows" / "build.yml").read_text()
    if "pull_request_target" in build_wf or "pull_request_target" in workflow:
        error("workflows must not use pull_request_target")
    if "persist-credentials: false" not in build_wf:
        error("build.yml checkout must set persist-credentials false")
    if "actions/checkout@" not in build_wf or "actions/upload-artifact@" not in build_wf:
        error("build.yml must pin checkout and upload-artifact")
    if "scripts/ci-linux-build.sh" not in build_wf:
        error("build.yml must run scripts/ci-linux-build.sh")
    if "scripts/ci-windows-build.sh" not in build_wf:
        error("build.yml must run scripts/ci-windows-build.sh")
    if "windows-latest" not in build_wf:
        error("build.yml must include a windows-latest job")
    if "landlock-void" in extras or "landlock-void" in overlay:
        error("overlay scripts must not wrap Void with Landlock")


def check_pin(version: dict[str, str]) -> None:
    pin = check_json(ROOT / "extensions" / "ublock" / "pin.json")
    if not isinstance(pin, dict):
        return
    if pin.get("version") != version.get("UBLOCK_VERSION"):
        error("ublock pin.json version does not match VERSION")
    sha = (pin.get("xpi") or {}).get("sha256") if isinstance(pin.get("xpi"), dict) else None
    if sha != version.get("UBLOCK_XPI_SHA256"):
        error("ublock pin.json sha256 does not match VERSION")
    if pin.get("addon_id") != version.get("UBLOCK_ID"):
        error("ublock pin.json addon_id does not match VERSION")


def main() -> int:
    version = load_version()
    check_layout()
    check_policies(check_json(ROOT / "policies" / "policies.json"))
    check_void_cfg()
    check_branding()
    check_pin(version)
    for msg in WARNS:
        print(f"warn: {msg}")
    if ERRORS:
        for msg in ERRORS:
            print(f"error: {msg}", file=sys.stderr)
        print(f"FAIL {len(ERRORS)} error(s)", file=sys.stderr)
        return 1
    print("OK Lyra validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
