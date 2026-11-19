# Changelog

## 0.2.1

- Stop no longer leaves Steam stuck in the Dock: it ends Steam's browser helper when it outlives Wine's server,
  without touching other Wine setups.
- Stop takes seconds instead of up to a minute, and no longer starts Steam when it isn't running.

## 0.2.0

- Set up is fully automatic on a fresh Mac: installs Rosetta 2, Whisky and its Wine engine, then the bottle and Steam.
- Pinned downloads with SHA-256 checks; Whisky is installed only if Apple's signature names its developer.
- Download progress in the app; stalled downloads fail with a message instead of hanging.

## 0.1.0

First release.

- One-window setup: checks for Whisky, creates the `Vaelos` bottle, installs Steam from Valve's CDN.
- Per-process graphics routing: DXMT for `cs2.exe`, DXVK for Steam's Chromium UI (fixes the black Steam window).
- Persistent DXMT shader cache: freezes over 50 ms drop from 16 to 1 per minute after the first match.
- Smooth and Sharp presets in true fullscreen, sized to the primary display at every launch.
- Microphone panel: Bluetooth headset warning, one-click switch to the built-in mic, tone-fit mic test through Wine.
- Hardened-runtime build, read-only DMG, SHA-256 checksums.
