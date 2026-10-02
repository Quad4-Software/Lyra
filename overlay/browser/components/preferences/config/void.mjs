/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

import { Preferences } from "chrome://global/content/preferences/Preferences.mjs";
import { SettingGroupManager } from "chrome://browser/content/preferences/config/SettingGroupManager.mjs";

const DNS_SB_URI = "https://doh.dns.sb/dns-query";
const DNS_SB_BOOTSTRAP = "185.222.222.222";

const FPP_BASE = [
  "+CanvasRandomization",
  "+EfficientCanvasRandomization",
  "+FontVisibilityLangPack",
  "+FontVisibilityBaseSystem",
  "+JSMathFdlibm",
  "+ScreenAvailToResolution",
  "+ScreenRect",
  "+ScreenAvailRect",
  "+ScreenOrientation",
  "+WindowScreenXY",
  "+WindowInnerScreenXY",
  "+WindowDevicePixelRatio",
  "+NavigatorHWConcurrencyTiered",
  "+MaxTouchPointsCollapse",
  "+SpeechSynthesis",
  "+UseHardcodedFontSubstitutes",
  "+WebGLVendorSanitize",
  "+WebGLRandomization",
  "+PdfjsSpoof",
  "+MediaCapabilities",
  "+ScreenPixelDepth",
  "+CanvasExtractionFromThirdPartiesIsBlocked",
  "+WebGPULimits",
  "+WebGPUIsFallbackAdapter",
  "+WebGPUSubgroupSizes",
  "+WebCodecs",
  "+MediaError",
  "+VideoElementMozFrames",
  "+VideoElementMozFrameDelay",
  "+VideoElementPlaybackQuality",
  "+MouseEventScreenPoint",
  "+FrameRate",
  "+UseStandinsForNativeColors",
  "+WebVTT",
  "+DiskStorageLimit",
  "+CSSColorInfo",
  "+WindowOuterSize",
];

function voidAddPref(info) {
  if (!Preferences.get(info.id)) {
    Preferences.add(info);
  }
}

function observePref(name, emitChange) {
  Services.prefs.addObserver(name, emitChange);
  return () => Services.prefs.removeObserver(name, emitChange);
}

function currentMode() {
  return Services.prefs.getStringPref("void.fingerprint.mode", "firefox");
}

function currentUaMode() {
  return Services.prefs.getStringPref("void.ua.mode", "firefox");
}

function buildFppOverrides() {
  if (currentMode() === "crowd") {
    const skip = ["-CSSPrefersColorScheme"];
    if (!Services.prefs.getBoolPref("void.timezone.spoof", true)) {
      skip.push("-JSDateTimeUTC");
    }
    return skip.join(",");
  }
  const parts = FPP_BASE.slice();
  if (Services.prefs.getBoolPref("void.typing.protection", true)) {
    parts.push("+KeyboardEvents", "+ReduceTimerPrecision", "+WidgetEvents");
  }
  if (Services.prefs.getBoolPref("void.window.buckets", true)) {
    parts.push("+RoundWindowSize");
  }
  if (Services.prefs.getBoolPref("void.timezone.spoof", true)) {
    parts.push("+JSDateTimeUTC");
  }
  if (Services.prefs.getBoolPref("void.audio.protection", true)) {
    parts.push("+AudioSampleRate", "+AudioContext");
  }
  if (Services.prefs.getBoolPref("void.sensors.block", true)) {
    parts.push(
      "+Gamepad",
      "+MediaDevices",
      "+NetworkConnection",
      "+DeviceSensors",
      "+StreamVideoFacingMode"
    );
  }
  if (Services.prefs.getIntPref("privacy.spoof_english", 0) === 2) {
    parts.push("+JSLocale");
  }
  if (currentUaMode() === "crowd") {
    parts.push(
      "+NavigatorUserAgent",
      "+HttpUserAgent",
      "+NavigatorAppVersion",
      "+NavigatorPlatform",
      "+NavigatorOscpu",
      "+NavigatorBuildID"
    );
  }
  return parts.join(",");
}

function applyWebrtc(protect) {
  Services.prefs.setBoolPref("media.peerconnection.ice.default_address_only", true);
  Services.prefs.setBoolPref("media.peerconnection.ice.obfuscate_host_addresses", true);
  Services.prefs.setBoolPref("media.peerconnection.ice.no_host", protect);
}

function applySensors(block) {
  Services.prefs.setBoolPref("device.sensors.enabled", !block);
  Services.prefs.setBoolPref("device.sensors.motion.enabled", !block);
  Services.prefs.setBoolPref("device.sensors.orientation.enabled", !block);
  Services.prefs.setBoolPref("dom.gamepad.enabled", !block);
  Services.prefs.setBoolPref("dom.vr.enabled", !block);
  Services.prefs.setBoolPref("dom.vibrator.enabled", !block);
}

function applyGeo(block) {
  Services.prefs.setBoolPref("geo.enabled", !block);
  Services.prefs.setIntPref("permissions.default.geo", block ? 2 : 0);
}

function applyLan(block) {
  Services.prefs.setBoolPref("network.lna.block_trackers", block);
  Services.prefs.setBoolPref("network.lna.block_insecure_contexts", block);
}

function applySafest(on) {
  for (const p of [
    "javascript.options.ion",
    "javascript.options.baselinejit",
    "javascript.options.wasm",
    "javascript.options.wasm_optimizingjit",
    "javascript.options.wasm_baselinejit",
  ]) {
    Services.prefs.setBoolPref(p, !on);
  }
}

function applyPermBlock(on) {
  for (const p of ["camera", "microphone", "desktop-notification"]) {
    Services.prefs.setIntPref(`permissions.default.${p}`, on ? 2 : 0);
  }
}

function applyClearOnExit() {
  const any =
    Services.prefs.getBoolPref("privacy.clearOnShutdown.cookies", false) ||
    Services.prefs.getBoolPref("privacy.clearOnShutdown.cache", false) ||
    Services.prefs.getBoolPref("privacy.clearOnShutdown.history", false) ||
    Services.prefs.getBoolPref("privacy.clearOnShutdown.formdata", false) ||
    Services.prefs.getBoolPref("privacy.clearOnShutdown.sessions", false);
  Services.prefs.setBoolPref(
    "privacy.sanitize.sanitizeOnShutdown",
    any
  );
}

const UA_STRINGS = {
  "firefox-win":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0",
  "firefox-mac":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:140.0) Gecko/20100101 Firefox/140.0",
  "chrome-win":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36",
  "chrome-mac":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36",
  "edge-win":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0",
  "safari-mac":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15",
};

function applyUa() {
  const mode = currentUaMode();
  if (mode === "firefox" || mode === "crowd") {
    if (Services.prefs.prefHasUserValue("general.useragent.override")) {
      Services.prefs.clearUserPref("general.useragent.override");
    }
    return;
  }
  const ua =
    mode === "custom"
      ? Services.prefs.getStringPref("void.ua.custom", "")
      : UA_STRINGS[mode];
  if (ua) {
    Services.prefs.setStringPref("general.useragent.override", ua);
  }
}

function applyVoidMode() {
  const mode = currentMode();
  const buckets = Services.prefs.getBoolPref("void.window.buckets", true);
  const restrictFonts = Services.prefs.getBoolPref("void.fonts.restrict", true);
  const typing = Services.prefs.getBoolPref("void.typing.protection", true);
  if (mode === "crowd") {
    Services.prefs.setBoolPref("privacy.resistFingerprinting", true);
    Services.prefs.setBoolPref("privacy.resistFingerprinting.pbmode", true);
    Services.prefs.setBoolPref("privacy.fingerprintingProtection", true);
    Services.prefs.setBoolPref("privacy.fingerprintingProtection.pbmode", true);
    Services.prefs.setStringPref(
      "privacy.fingerprintingProtection.overrides",
      buildFppOverrides()
    );
    Services.prefs.setBoolPref("privacy.resistFingerprinting.letterboxing", true);
    Services.prefs.setStringPref("void.ua.mode", "crowd");
    Services.prefs.setIntPref("layout.css.font-visibility", restrictFonts ? 1 : 3);
  } else {
    Services.prefs.setBoolPref("privacy.resistFingerprinting", false);
    Services.prefs.setBoolPref("privacy.resistFingerprinting.pbmode", false);
    Services.prefs.setBoolPref("privacy.fingerprintingProtection", true);
    Services.prefs.setBoolPref("privacy.fingerprintingProtection.pbmode", true);
    Services.prefs.setStringPref(
      "privacy.fingerprintingProtection.overrides",
      buildFppOverrides()
    );
    Services.prefs.setBoolPref(
      "privacy.resistFingerprinting.letterboxing",
      buckets
    );
    Services.prefs.setIntPref("layout.css.font-visibility", restrictFonts ? 2 : 3);
  }
  if (typing) {
    Services.prefs.setBoolPref("privacy.reduceTimerPrecision", true);
    Services.prefs.setBoolPref(
      "privacy.resistFingerprinting.reduceTimerPrecision.jitter",
      true
    );
  }
  applyWebrtc(Services.prefs.getBoolPref("void.webrtc.protect", true));
  applySensors(Services.prefs.getBoolPref("void.sensors.block", true));
  applyGeo(Services.prefs.getBoolPref("void.geo.block", true));
  applyLan(Services.prefs.getBoolPref("void.lan.block", true));
  applySafest(Services.prefs.getBoolPref("void.safest", false));
  applyPermBlock(Services.prefs.getBoolPref("void.permissions.block", false));
  Services.prefs.setBoolPref(
    "privacy.firstparty.isolate",
    Services.prefs.getBoolPref("void.fpi", false)
  );
  applyUa();
}

function applyDohMode(mode) {
  Services.prefs.setIntPref("network.trr.mode", mode);
  if (mode === 2 || mode === 3) {
    Services.prefs.setStringPref("network.trr.uri", DNS_SB_URI);
    Services.prefs.setStringPref("network.trr.custom_uri", DNS_SB_URI);
    Services.prefs.setStringPref("network.trr.bootstrapAddr", DNS_SB_BOOTSTRAP);
    Services.prefs.setStringPref("void.doh.provider", "dns.sb");
    Services.prefs.setBoolPref("doh-rollout.enabled", false);
  }
}

for (const info of [
  { id: "void.fingerprint.mode", type: "string" },
  { id: "void.ua.mode", type: "string" },
  { id: "void.window.buckets", type: "bool" },
  { id: "void.fonts.restrict", type: "bool" },
  { id: "void.typing.protection", type: "bool" },
  { id: "void.timezone.spoof", type: "bool" },
  { id: "void.audio.protection", type: "bool" },
  { id: "void.webrtc.protect", type: "bool" },
  { id: "void.sensors.block", type: "bool" },
  { id: "void.geo.block", type: "bool" },
  { id: "void.sync.enabled", type: "bool" },
  { id: "void.sync.tabs", type: "bool" },
  { id: "void.sync.bookmarks", type: "bool" },
  { id: "void.sync.applyTabs", type: "bool" },
  { id: "void.sync.secret", type: "string" },
  { id: "void.ua.custom", type: "string" },
  { id: "void.lan.block", type: "bool" },
  { id: "void.js.mode", type: "string" },
  { id: "void.js.blocklist", type: "string" },
  { id: "void.js.allowlist", type: "string" },
  { id: "void.storage.encrypt", type: "bool" },
  { id: "void.history.index.enabled", type: "bool" },
  { id: "void.history.index.maxEntries", type: "int" },
  { id: "void.sync.server", type: "string" },
  { id: "browser.privatebrowsing.autostart", type: "bool" },
  { id: "void.safest", type: "bool" },
  { id: "void.permissions.block", type: "bool" },
  { id: "void.fpi", type: "bool" },
  { id: "void.update.check", type: "bool" },
  { id: "privacy.clearOnShutdown.cookies", type: "bool" },
  { id: "privacy.clearOnShutdown.cache", type: "bool" },
  { id: "privacy.clearOnShutdown.history", type: "bool" },
  { id: "privacy.clearOnShutdown.formdata", type: "bool" },
  { id: "privacy.clearOnShutdown.sessions", type: "bool" },
  { id: "privacy.resistFingerprinting.letterboxing", type: "bool" },
  { id: "gfx.bundled-fonts.activate", type: "int" },
  { id: "layout.css.font-visibility", type: "int" },
  {
    id: "privacy.resistFingerprinting.reduceTimerPrecision.microseconds",
    type: "int",
  },
  { id: "privacy.query_stripping.enabled", type: "bool" },
  { id: "network.http.referer.XOriginPolicy", type: "int" },
  { id: "webgl.disabled", type: "bool" },
  { id: "security.OCSP.enabled", type: "int" },
]) {
  voidAddPref(info);
}

Preferences.addSetting({
  id: "voidFingerprintMode",
  pref: "void.fingerprint.mode",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidUaMode",
  pref: "void.ua.mode",
  deps: ["voidFingerprintMode"],
  disabled: () => currentMode() === "crowd",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidUaCustom",
  pref: "void.ua.custom",
  deps: ["voidUaMode"],
  disabled: () => currentUaMode() !== "custom",
  onUserChange() {
    applyUa();
  },
});

Preferences.addSetting({
  id: "voidLanBlock",
  pref: "void.lan.block",
  onUserChange(checked) {
    applyLan(checked);
  },
});

Preferences.addSetting({
  id: "voidJsMode",
  pref: "void.js.mode",
});

Preferences.addSetting({
  id: "voidJsBlocklist",
  pref: "void.js.blocklist",
  deps: ["voidJsMode"],
  disabled: () =>
    Services.prefs.getStringPref("void.js.mode", "off") !== "denylist",
});

Preferences.addSetting({
  id: "voidJsAllowlist",
  pref: "void.js.allowlist",
  deps: ["voidJsMode"],
  disabled: () =>
    Services.prefs.getStringPref("void.js.mode", "off") !== "allowlist",
});

Preferences.addSetting({
  id: "voidStorageEncrypt",
  get() {
    return Services.prefs.getBoolPref(
      "security.storage.encryption.sqlite.enabled",
      false
    );
  },
  set(checked) {
    Services.prefs.setBoolPref(
      "security.storage.encryption.sqlite.enabled",
      checked
    );
    Services.prefs.setBoolPref("void.storage.encrypt", checked);
  },
  setup(emitChange) {
    return observePref(
      "security.storage.encryption.sqlite.enabled",
      emitChange
    );
  },
});

Preferences.addSetting({
  id: "voidWindowBuckets",
  pref: "void.window.buckets",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidLetterboxing",
  pref: "privacy.resistFingerprinting.letterboxing",
  onUserChange(checked) {
    Services.prefs.setBoolPref("void.window.buckets", checked);
    if (checked) {
      applyVoidMode();
    }
  },
});

Preferences.addSetting({
  id: "voidBundledFonts",
  pref: "gfx.bundled-fonts.activate",
  get(val) {
    return val !== 0;
  },
  set(checked) {
    return checked ? 1 : 0;
  },
});

Preferences.addSetting({
  id: "voidFontsRestrict",
  pref: "void.fonts.restrict",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidFontVisibility",
  pref: "layout.css.font-visibility",
  get(val) {
    return String(val);
  },
  set(val) {
    return Number(val);
  },
});

Preferences.addSetting({
  id: "voidTypingProtection",
  pref: "void.typing.protection",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidTypingDelay",
  pref: "privacy.resistFingerprinting.reduceTimerPrecision.microseconds",
  get(val) {
    if (val >= 100000) {
      return "100000";
    }
    if (val >= 20000) {
      return "20000";
    }
    return "1000";
  },
  set(val) {
    return Number(val);
  },
});

Preferences.addSetting({
  id: "voidDohMode",
  get() {
    const val = Services.prefs.getIntPref("network.trr.mode", 5);
    if (val === 2 || val === 3) {
      return String(val);
    }
    return "5";
  },
  set(val) {
    applyDohMode(Number(val));
  },
  setup(emitChange) {
    return observePref("network.trr.mode", emitChange);
  },
});

Preferences.addSetting({
  id: "voidDohAdvanced",
  onUserClick(e) {
    e.preventDefault();
    window.gotoPref("paneDnsOverHttps");
  },
});

Preferences.addSetting({
  id: "voidHttpsOnly",
  get() {
    return Services.prefs.getBoolPref("dom.security.https_only_mode", true);
  },
  set(checked) {
    Services.prefs.setBoolPref("dom.security.https_only_mode", checked);
  },
  setup(emitChange) {
    return observePref("dom.security.https_only_mode", emitChange);
  },
});

Preferences.addSetting({
  id: "voidQueryStripping",
  pref: "privacy.query_stripping.enabled",
  onUserChange(checked) {
    Services.prefs.setBoolPref(
      "privacy.query_stripping.enabled.pbmode",
      checked
    );
  },
});

Preferences.addSetting({
  id: "voidReferrer",
  pref: "network.http.referer.XOriginPolicy",
  get(val) {
    return val === 2;
  },
  set(checked) {
    return checked ? 2 : 0;
  },
});

Preferences.addSetting({
  id: "voidWebgl",
  pref: "webgl.disabled",
  get(val) {
    return !val;
  },
  set(checked) {
    return !checked;
  },
});

Preferences.addSetting({
  id: "voidEme",
  get() {
    return Services.prefs.getBoolPref("media.eme.enabled", false);
  },
  set(checked) {
    Services.prefs.setBoolPref("media.eme.enabled", checked);
  },
  setup(emitChange) {
    return observePref("media.eme.enabled", emitChange);
  },
});

Preferences.addSetting({
  id: "voidOcsp",
  pref: "security.OCSP.enabled",
  get(val) {
    return val !== 0;
  },
  set(checked) {
    return checked ? 1 : 0;
  },
});

Preferences.addSetting({
  id: "voidSpoofEnglish",
  get() {
    return Services.prefs.getIntPref("privacy.spoof_english", 0) === 2;
  },
  set(checked) {
    Services.prefs.setIntPref("privacy.spoof_english", checked ? 2 : 0);
    applyVoidMode();
  },
  setup(emitChange) {
    return observePref("privacy.spoof_english", emitChange);
  },
});

Preferences.addSetting({
  id: "voidTimezone",
  pref: "void.timezone.spoof",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidAudio",
  pref: "void.audio.protection",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidWebrtc",
  pref: "void.webrtc.protect",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidSensors",
  pref: "void.sensors.block",
  onUserChange() {
    applyVoidMode();
  },
});

Preferences.addSetting({
  id: "voidGeo",
  pref: "void.geo.block",
  onUserChange() {
    applyVoidMode();
  },
});

function lyraSync() {
  try {
    return ChromeUtils.importESModule(
      "resource:///modules/LyraSync.sys.mjs"
    ).LyraSync;
  } catch (e) {
    return null;
  }
}

Preferences.addSetting({
  id: "voidSyncEnabled",
  pref: "void.sync.enabled",
  onUserChange(checked) {
    const sync = lyraSync();
    if (!sync) {
      return;
    }
    if (checked) {
      sync.ensureSecret();
      sync.connect();
    } else {
      sync.disconnect();
    }
  },
});

Preferences.addSetting({
  id: "voidSyncTabs",
  pref: "void.sync.tabs",
});

Preferences.addSetting({
  id: "voidSyncBookmarks",
  pref: "void.sync.bookmarks",
});

Preferences.addSetting({
  id: "voidSyncServer",
  pref: "void.sync.server",
});

Preferences.addSetting({
  id: "voidSyncApplyTabs",
  pref: "void.sync.applyTabs",
});

Preferences.addSetting({
  id: "voidSyncSecret",
  pref: "void.sync.secret",
  onUserChange() {
    const sync = lyraSync();
    if (sync && Services.prefs.getBoolPref("void.sync.enabled", false)) {
      sync.connect();
    }
  },
});

Preferences.addSetting({
  id: "voidSyncPair",
  onUserClick(e) {
    e.preventDefault();
    const sync = lyraSync();
    if (!sync) {
      return;
    }
    Services.prefs.setStringPref("void.sync.secret", "");
    sync.ensureSecret();
    Services.prefs.setBoolPref("void.sync.enabled", true);
    sync.connect();
  },
});

Preferences.addSetting({ id: "voidRestartNote" });

Preferences.addSetting({
  id: "voidHistoryIndex",
  pref: "void.history.index.enabled",
});

Preferences.addSetting({
  id: "voidHistoryOpen",
  onUserClick(e) {
    e.preventDefault();
    Services.wm
      .getMostRecentBrowserWindow()
      ?.openTrustedLinkIn("about:lyrahistory", "tab");
  },
});

Preferences.addSetting({
  id: "voidAlwaysPrivate",
  pref: "browser.privatebrowsing.autostart",
});

Preferences.addSetting({
  id: "voidSafest",
  pref: "void.safest",
  onUserChange(checked) {
    applySafest(checked);
  },
});

Preferences.addSetting({
  id: "voidPermissionsBlock",
  pref: "void.permissions.block",
  onUserChange(checked) {
    applyPermBlock(checked);
  },
});

Preferences.addSetting({
  id: "voidFpi",
  pref: "void.fpi",
  onUserChange(checked) {
    Services.prefs.setBoolPref("privacy.firstparty.isolate", checked);
  },
});

for (const [id, pref] of [
  ["voidClearCookies", "privacy.clearOnShutdown.cookies"],
  ["voidClearCache", "privacy.clearOnShutdown.cache"],
  ["voidClearHistory", "privacy.clearOnShutdown.history"],
  ["voidClearFormdata", "privacy.clearOnShutdown.formdata"],
  ["voidClearSessions", "privacy.clearOnShutdown.sessions"],
]) {
  Preferences.addSetting({
    id,
    pref,
    onUserChange() {
      applyClearOnExit();
    },
  });
}

Preferences.addSetting({
  id: "voidUpdateCheck",
  pref: "void.update.check",
});

try {
  SettingGroupManager.registerGroups({
    voidFingerprint: {
      l10nId: "void-fingerprint-group",
      headingLevel: 2,
      items: [
        {
          id: "voidFingerprintMode",
          l10nId: "void-fingerprint-mode",
          control: "moz-radio-group",
          options: [
            {
              value: "firefox",
              l10nId: "void-fingerprint-mode-firefox",
              controlAttrs: { id: "voidFingerprintFirefox" },
            },
            {
              value: "crowd",
              l10nId: "void-fingerprint-mode-crowd",
              controlAttrs: { id: "voidFingerprintCrowd" },
            },
          ],
        },
        {
          id: "voidUaMode",
          l10nId: "void-ua-mode",
          control: "moz-radio-group",
          options: [
            {
              value: "firefox",
              l10nId: "void-ua-mode-firefox",
              controlAttrs: { id: "voidUaFirefox" },
            },
            {
              value: "crowd",
              l10nId: "void-ua-mode-crowd",
              controlAttrs: { id: "voidUaCrowd" },
            },
            {
              value: "firefox-win",
              l10nId: "void-ua-mode-firefox-win",
            },
            {
              value: "firefox-mac",
              l10nId: "void-ua-mode-firefox-mac",
            },
            {
              value: "chrome-win",
              l10nId: "void-ua-mode-chrome-win",
            },
            {
              value: "edge-win",
              l10nId: "void-ua-mode-edge-win",
            },
            {
              value: "safari-mac",
              l10nId: "void-ua-mode-safari-mac",
            },
            {
              value: "custom",
              l10nId: "void-ua-mode-custom",
            },
          ],
        },
        {
          id: "voidUaCustom",
          l10nId: "void-ua-custom",
          control: "moz-input-text",
        },
      ],
    },
    voidWindows: {
      l10nId: "void-windows-group",
      headingLevel: 2,
      items: [
        {
          id: "voidWindowBuckets",
          l10nId: "void-window-buckets",
          control: "moz-checkbox",
        },
        {
          id: "voidLetterboxing",
          l10nId: "void-letterboxing",
          control: "moz-checkbox",
        },
      ],
    },
    voidFonts: {
      l10nId: "void-fonts-group",
      headingLevel: 2,
      items: [
        {
          id: "voidBundledFonts",
          l10nId: "void-bundled-fonts",
          control: "moz-checkbox",
        },
        {
          id: "voidFontsRestrict",
          l10nId: "void-fonts-restrict",
          control: "moz-checkbox",
        },
        {
          id: "voidFontVisibility",
          l10nId: "void-font-visibility",
          control: "moz-select",
          options: [
            {
              value: "1",
              l10nId: "void-font-visibility-base",
            },
            {
              value: "2",
              l10nId: "void-font-visibility-langpack",
            },
            {
              value: "3",
              l10nId: "void-font-visibility-all",
            },
          ],
        },
      ],
    },
    voidTyping: {
      l10nId: "void-typing-group",
      headingLevel: 2,
      items: [
        {
          id: "voidTypingProtection",
          l10nId: "void-typing-protection",
          control: "moz-checkbox",
        },
        {
          id: "voidTypingDelay",
          l10nId: "void-typing-delay",
          control: "moz-select",
          options: [
            {
              value: "1000",
              l10nId: "void-typing-delay-1ms",
            },
            {
              value: "20000",
              l10nId: "void-typing-delay-20ms",
            },
            {
              value: "100000",
              l10nId: "void-typing-delay-100ms",
            },
          ],
        },
      ],
    },
    voidSpoof: {
      l10nId: "void-spoof-group",
      headingLevel: 2,
      items: [
        {
          id: "voidTimezone",
          l10nId: "void-timezone-spoof",
          control: "moz-checkbox",
        },
        {
          id: "voidAudio",
          l10nId: "void-audio-protection",
          control: "moz-checkbox",
        },
        {
          id: "voidWebrtc",
          l10nId: "void-webrtc-protect",
          control: "moz-checkbox",
        },
        {
          id: "voidSensors",
          l10nId: "void-sensors-block",
          control: "moz-checkbox",
        },
        {
          id: "voidGeo",
          l10nId: "void-geo-block",
          control: "moz-checkbox",
        },
      ],
    },
    voidDns: {
      l10nId: "void-dns-group",
      headingLevel: 2,
      items: [
        {
          id: "voidDohMode",
          l10nId: "void-doh-mode",
          control: "moz-radio-group",
          options: [
            {
              value: "2",
              l10nId: "void-doh-mode-2",
              controlAttrs: { id: "voidDohFirst" },
            },
            {
              value: "3",
              l10nId: "void-doh-mode-3",
              controlAttrs: { id: "voidDohOnly" },
            },
            {
              value: "5",
              l10nId: "void-doh-mode-5",
              controlAttrs: { id: "voidDohOff" },
            },
          ],
        },
        {
          id: "voidDohAdvanced",
          l10nId: "void-doh-advanced",
          control: "moz-box-button",
        },
      ],
    },
    voidProtections: {
      l10nId: "void-protections-group",
      headingLevel: 2,
      items: [
        {
          id: "voidLanBlock",
          l10nId: "void-lan-block",
          control: "moz-checkbox",
        },
        {
          id: "voidPermissionsBlock",
          l10nId: "void-permissions-block",
          control: "moz-checkbox",
        },
        {
          id: "voidFpi",
          l10nId: "void-fpi",
          control: "moz-checkbox",
        },
      ],
    },
    voidScripts: {
      l10nId: "void-scripts-group",
      headingLevel: 2,
      items: [
        {
          id: "voidJsMode",
          l10nId: "void-js-mode",
          control: "moz-radio-group",
          options: [
            {
              value: "off",
              l10nId: "void-js-mode-off",
            },
            {
              value: "denylist",
              l10nId: "void-js-mode-denylist",
            },
            {
              value: "allowlist",
              l10nId: "void-js-mode-allowlist",
            },
          ],
        },
        {
          id: "voidJsBlocklist",
          l10nId: "void-js-blocklist",
          control: "moz-input-text",
        },
        {
          id: "voidJsAllowlist",
          l10nId: "void-js-allowlist",
          control: "moz-input-text",
        },
        {
          id: "voidSafest",
          l10nId: "void-safest",
          control: "moz-checkbox",
        },
      ],
    },
    voidStorage: {
      l10nId: "void-storage-group",
      headingLevel: 2,
      items: [
        {
          id: "voidStorageEncrypt",
          l10nId: "void-storage-encrypt",
          control: "moz-checkbox",
        },
        {
          id: "voidAlwaysPrivate",
          l10nId: "void-always-private",
          control: "moz-checkbox",
        },
      ],
    },
    voidHistory: {
      l10nId: "void-history-group",
      headingLevel: 2,
      items: [
        {
          id: "voidHistoryIndex",
          l10nId: "void-history-index",
          control: "moz-checkbox",
        },
        {
          id: "voidHistoryOpen",
          l10nId: "void-history-open",
          control: "moz-box-button",
        },
      ],
    },
    voidWipe: {
      l10nId: "void-wipe-group",
      headingLevel: 2,
      items: [
        {
          id: "voidClearCookies",
          l10nId: "void-clear-cookies",
          control: "moz-checkbox",
        },
        {
          id: "voidClearCache",
          l10nId: "void-clear-cache",
          control: "moz-checkbox",
        },
        {
          id: "voidClearHistory",
          l10nId: "void-clear-history",
          control: "moz-checkbox",
        },
        {
          id: "voidClearFormdata",
          l10nId: "void-clear-formdata",
          control: "moz-checkbox",
        },
        {
          id: "voidClearSessions",
          l10nId: "void-clear-sessions",
          control: "moz-checkbox",
        },
        {
          id: "voidUpdateCheck",
          l10nId: "void-update-check",
          control: "moz-checkbox",
        },
      ],
    },
    voidSync: {
      l10nId: "void-sync-group",
      headingLevel: 2,
      items: [
        {
          id: "voidSyncEnabled",
          l10nId: "void-sync-enabled",
          control: "moz-checkbox",
        },
        {
          id: "voidSyncTabs",
          l10nId: "void-sync-tabs",
          control: "moz-checkbox",
        },
        {
          id: "voidSyncBookmarks",
          l10nId: "void-sync-bookmarks",
          control: "moz-checkbox",
        },
        {
          id: "voidSyncServer",
          l10nId: "void-sync-server",
          control: "moz-input-text",
        },
        {
          id: "voidSyncApplyTabs",
          l10nId: "void-sync-apply-tabs",
          control: "moz-checkbox",
        },
        {
          id: "voidSyncSecret",
          l10nId: "void-sync-secret",
          control: "moz-input-text",
        },
        {
          id: "voidSyncPair",
          l10nId: "void-sync-pair",
          control: "moz-box-button",
        },
      ],
    },
    voidCompat: {
      l10nId: "void-compat-group",
      headingLevel: 2,
      items: [
        {
          id: "voidHttpsOnly",
          l10nId: "void-https-only",
          control: "moz-checkbox",
        },
        {
          id: "voidQueryStripping",
          l10nId: "void-query-stripping",
          control: "moz-checkbox",
        },
        {
          id: "voidReferrer",
          l10nId: "void-referrer",
          control: "moz-checkbox",
        },
        {
          id: "voidWebgl",
          l10nId: "void-webgl",
          control: "moz-checkbox",
        },
        {
          id: "voidEme",
          l10nId: "void-eme",
          control: "moz-checkbox",
        },
        {
          id: "voidOcsp",
          l10nId: "void-ocsp",
          control: "moz-checkbox",
        },
        {
          id: "voidSpoofEnglish",
          l10nId: "void-spoof-english",
          control: "moz-checkbox",
        },
        {
          id: "voidRestartNote",
          l10nId: "void-restart-note",
          control: "moz-message-bar",
          controlAttrs: {
            role: "status",
          },
        },
      ],
    },
  });
} catch (e) {
  if (!String(e).includes("already registered")) {
    throw e;
  }
}

applyVoidMode();
