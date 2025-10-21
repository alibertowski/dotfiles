// Whenever updating Arkenfox, CHECK for any errors in the browser console (Ctrl + Shift + J)

// Enabling RFP which does not break any commonly visited site that I go toGMTString
// Letterboxing is just an additive, probably optional
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);

// Upgrade local sites to https by default
user_pref("dom.security.https_only_mode.upgrade_local", true);

// Auto disabling Firefox settings
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
user_pref("signon.rememberSignons", false);

// 5 turns off DoH. Only keep it off if using a VPN with SOCKS (for my usecase). Switch to 3 if not using VPN
user_pref("network.trr.mode", 5);
