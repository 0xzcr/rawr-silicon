# Changelog

## 0.1.0

First release.

- One-window setup: checks for Whisky, creates the `Vaelos` bottle, installs Steam from Valve's CDN.
- Per-process graphics routing: DXMT for `cs2.exe`, DXVK for Steam's Chromium UI (fixes the black Steam window).
- Persistent DXMT shader cache: freezes over 50 ms drop from 16 to 1 per minute after the first match.
- Smooth and Sharp presets in true fullscreen, sized to the primary display at every launch.
- Microphone panel: Bluetooth headset warning, one-click switch to the built-in mic, tone-fit mic test through Wine.
- Hardened-runtime build, read-only DMG, SHA-256 checksums.
