# Architecture

```
 Vaelos Silicon.app (SwiftUI)                      ~/Library/Application Support/Vaelos Silicon
   │  status.sh / setup.sh / launch.sh / stop.sh       ├─ shader-cache/   DXMT Metal pipeline cache
   ▼                                                    └─ logs/           wine.log, mic-test.wav
 Whisky's Wine 11 (x86_64, Rosetta 2)  ── bottle "Vaelos" (a Wine prefix Whisky can also manage)
   ├─ steam.exe ─ steamwebhelper.exe (Chromium) ─ d3d11.dll = DXVK  → Vulkan → MoltenVK → Metal
   └─ cs2.exe ─────────────────────────────────── d3d11.dll = DXMT  → Metal (direct)
                                                    dxgi.dll  = DXMT
```

## Why two translation layers

- **DXMT** translates D3D11 straight to Metal and is the fast path for CS2 (DX11 only).
- **Steam's UI can't run on DXMT** (`EGL_BAD_ALLOC` creating its login window) and fails on Wine's own
  d3d11 (`Skia shader compilation error`, black window). It draws correctly on **DXVK**.

Routing is per process, with no global overrides:

| Process | Where its d3d11.dll comes from | Override |
|---|---|---|
| `cs2.exe` | DXMT, copied into `game/bin/win64` (the exe's own folder, searched first) | `AppDefaults\cs2.exe\DllOverrides` = native,builtin |
| `steamwebhelper.exe` | DXVK, copied into `system32` | `AppDefaults\steamwebhelper.exe\DllOverrides` = native,builtin |
| everything else | Wine's built-in | default |

`launch.sh` re-applies both on every launch, because a CS2 update or Steam file check can remove the files.

## Launch sequence

1. `use_bottle` finds the bottle named `Vaelos` by its `Metadata.plist` and exports `WINEPREFIX` and
   `WINEMSYNC=1` (every Wine process in a prefix must agree on the sync mode).
2. DXVK for Steam's browser; `CEF_DISABLE_SANDBOX` / `STEAM_DISABLE_CEF_SANDBOX` (Chromium's sandbox can't work
   under Wine).
3. If `cs2.exe` is missing, open `steam://install/730` instead of launching, so the first real launch gets DXMT.
4. DXMT for `cs2.exe`; Wine's Mac driver `RetinaMode` per preset; DXMT shader cache path.
5. `steam.exe -applaunch 730 -novid -console -condebug -fullscreen -w W -h H`.

## Resolution

Wine opens fullscreen games on macOS's **primary** display (`NSScreen.screens[0]`), so that's the one the app
measures. Smooth: `frame` size in points, Retina off. Sharp: points × `backingScaleFactor`, Retina on. Both
equal the display's current mode, so there is no mode switch.

## Mic test

1. `TonePlayer` plays 440 Hz on the built-in speakers (`AUAudioUnit.setDeviceID`), whatever the default output.
2. `mictest.sh` runs `micrec.exe` (tools/micrec.c, cross-compiled with zig) inside the bottle on `WAVE_MAPPER`:
   the default mic, captured through Wine's `waveIn` → `winecoreaudio`, the same path as CS2's voice chat.
3. `MicAnalysis` fits `a·sin + b·cos + c` to every 10 ms window and flags windows with excess leftover noise,
   a single-sample click, or the tone collapsing, all judged against the recording's typical tone size.
