// dotfiles/firefox/user.js — Gucixdev
//
// Read by Firefox on every startup and layered on top of prefs.js, so this is the
// declarative, diffable way to carry about:config tweaks between machines. prefs.js
// itself is NOT tracked here on purpose: it is almost entirely runtime/session state
// (telemetry timestamps, session-restore bookkeeping, per-install random ids,
// safebrowsing update clocks) that Firefox regenerates on its own — none of it is a
// deliberate choice worth version-controlling, and most of it churns on every launch.
//
// Add a real tweak as one user_pref() line with a one-line comment saying why. Find a
// pref's current/default value by typing it in about:config first.

// Required for userChrome.css / userContent.css (chrome/ next to this file) to be
// read at all — off by default.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Hardware video decode via VA-API/NVDEC. This machine has `libva-nvidia-driver`
// installed and the flatpak sandbox already grants `dri` device access, but
// Firefox's own gfx allowlist still leaves VA-API off by default on most Nvidia
// setups — force it on so video decode runs on the GPU, not the CPU.
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
