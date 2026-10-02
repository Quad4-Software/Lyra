/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Optional update notifier. One GET to the GitHub releases API after
 * startup idle; shows a doorhanger once per new version. App auto-update
 * stays off, this only tells the user a build exists.
 */

const RELEASES_API =
  "https://api.github.com/repos/Quad4-Software/Lyra/releases/latest";
const RELEASES_PAGE = "https://github.com/Quad4-Software/Lyra/releases";
const CHECK_DELAY_MS = 20000;

export const LyraUpdateCheck = {
  init() {
    if (!Services.prefs.getBoolPref("void.update.check", true)) {
      return;
    }
    let timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
    timer.initWithCallback(
      () => this._check(),
      CHECK_DELAY_MS,
      Ci.nsITimer.TYPE_ONE_SHOT
    );
  },

  async _check() {
    let current = Services.prefs.getStringPref("lyra.version", "");
    if (!current) {
      return;
    }
    let latest;
    try {
      let res = await fetch(RELEASES_API, {
        headers: { Accept: "application/vnd.github+json" },
        credentials: "omit",
      });
      if (!res.ok) {
        return;
      }
      latest = (await res.json()).tag_name || "";
    } catch {
      return;
    }
    let version = latest.replace(/^v/, "");
    if (!version || version == current) {
      return;
    }
    if (Services.prefs.getStringPref("lyra.update.seen", "") == version) {
      return;
    }
    this._notify(version);
  },

  async _notify(version) {
    let l10n = new Localization(["browser/lyra.ftl"], true);
    let message = await l10n.formatValue("lyra-update-available", {
      version,
    });
    let download = await l10n.formatValue("lyra-update-download");
    let dismiss = await l10n.formatValue("lyra-update-dismiss");
    for (let win of Services.wm.getEnumerator("navigator:browser")) {
      let notify = win.PopupNotifications;
      if (!notify) {
        continue;
      }
      notify.show(
        win.gBrowser.selectedBrowser,
        "lyra-update",
        message,
        "urlbar",
        {
          label: download,
          accessKey: "D",
          callback: () => {
            Services.prefs.setStringPref("lyra.update.seen", version);
            win.openTrustedLinkIn(`${RELEASES_PAGE}/tag/v${version}`, "tab");
          },
        },
        [
          {
            label: dismiss,
            accessKey: "m",
            callback: () => {
              Services.prefs.setStringPref("lyra.update.seen", version);
            },
          },
        ],
        { hideClose: false }
      );
    }
  },
};
