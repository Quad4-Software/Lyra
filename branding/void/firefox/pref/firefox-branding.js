/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Lyra branding-specific prefs. Privacy defaults live in prefs/void.cfg.

pref("startup.homepage_override_url", "");
pref("startup.homepage_welcome_url", "about:lyrasetup");
pref("startup.homepage_welcome_url.additional", "");

pref("app.support.baseURL", "https://quad4.io/");
pref("app.feedback.baseURL", "https://quad4.io/");
pref("app.releaseNotesURL", "https://quad4.io/");
pref("app.releaseNotesURL.aboutDialog", "https://quad4.io/");
pref("app.update.url.manual", "https://quad4.io/");
pref("app.update.url.details", "https://quad4.io/");

// No in-app Mozilla updater until Lyra ships its own update channel.
pref("app.update.interval", 0);
pref("app.update.promptWaitTime", 0);
pref("app.update.checkInstallTime.days", 0);
pref("app.update.badgeWaitTime", 0);

pref("devtools.selfxss.count", 5);

pref("extensions.activeThemeID", "void-dark@quad4.io");
pref("browser.theme.toolbar-theme", 0);
pref("browser.theme.content-theme", 0);
pref("ui.systemUsesDarkTheme", 1);
