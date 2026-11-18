# Results

All runs: MacBook Pro M2 Max, macOS 27.3, Whisky 3.10.2 (Wine 11.19, DXMT 0.80, DXVK 1.10.3), CS2 build 26748068.

## Method

`tools/bench.sh` loads Dust2 offline with 10 bots and joins spectators, so the camera follows live play.
With `HUD=1`, Metal's performance HUD logs frame intervals and GPU times to `logs/wine.log`; `tools/fps.py`
reads a 60 s window starting 10 s after the bots join. Hitch thresholds are fixed (25 ms / 50 ms) so runs with
different refresh behaviour stay comparable. Benchmarks run with `-insecure` (VAC off) so automation never
touches matchmaking.

## Graphics

| Run | Resolution | Avg fps | 1% low | 0.1% low | GPU median | Skips >25 ms | Freezes >50 ms | Worst |
|---|---|---|---|---|---|---|---|---|
| 1. Cold shader cache | 1512×982 | 114 | 60 | 12 | 7.4 ms | 35 | 16 | 192 ms |
| 2. Warm cache from disk | 1512×982 | **132** | 60 | **30** | 6.6 ms | **14** | **1** | **75 ms** |
| 4. Native Retina | 3024×1964 | 88 | 51 | 30 | 10.3 ms | 16 | 1 | 56 ms |
| 5. MetalFX on a native frame | 3024×1964 | 74 | 52 | 7 | 16.4 ms | 24 | 17 | 475 ms |
| 6. MetalFX, half-res → native | 1512×982 → 3024×1964 | 125 | 60 | 21 | 7.2 ms | 27 | 7 | 108 ms |
| 7. Run 6 again, warm | 1512×982 → 3024×1964 | 125 | 60 | 21 | 6.9 ms | 26 | 7 | 83 ms |

Takeaways:

- **The persistent DXMT shader cache is the biggest single win**: freezes 16 → 1 per minute.
- **Native Retina is GPU-bound** at ~10 ms per frame (~4× the pixels).
- **MetalFX spatial upscaling isn't worth it here**: run 7 shows its 7 freezes/min are not cache misses.
- The 1% low pinned at exactly 60 is vsync quantisation: a frame that misses the 8.3 ms (120 Hz) deadline is
  shown for two refreshes. Exclusive fullscreen emits no Metal HUD data, so it isn't measured here.

## Voice chat static

Test: a steady 440 Hz tone from the MacBook speakers, recorded by the default mic. A clean take is a sine wave
in every 10 ms window; the analyser (`app/MicAnalysis.swift`) flags windows with excess noise, single-sample
clicks, or the tone dropping below half its usual size. The first 3 s are skipped: Bluetooth earbuds glitch
while switching into headset mode, natively too.

| Mic | Path | Broken windows (3 runs) |
|---|---|---|
| MacBook Pro mic, 48 kHz | Wine (`waveIn`, what CS2 uses) | 0 |
| OnePlus Nord Buds 3, Bluetooth 16 kHz | macOS natively | 295 · 24 · 323 |
| OnePlus Nord Buds 3, Bluetooth 16 kHz | Wine | 131 · 14 · 145 |

The Bluetooth mic breaks up just as badly without Wine; its level also swings by up to 26 dB between runs
(the earbuds' noise suppression). **The static teammates hear is the Bluetooth headset mic, not Wine.** Fix:
built-in mic for input, earbuds for output, which the app does in one click.
