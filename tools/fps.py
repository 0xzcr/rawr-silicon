"""Measure CS2 frame pacing from the Metal HUD log (launch with HUD=1 scripts/launch.sh).

Each 'metal-HUD:' line holds a counter, two memory numbers, then pairs of
(frame interval ms, GPU time ms) for recent frames.

Usage: python3 fps.py <seconds to sample>
"""
import os
import re
import sys
from datetime import datetime

import numpy as np

HUD_LINE = re.compile(r"metal-HUD: ([\d.,]+)")
LOG = os.environ.get("FPS_LOG", os.path.expanduser("~/Library/Application Support/Vaelos Silicon/logs/wine.log"))
END = os.environ.get("FPS_END")   # "YYYY-MM-DD HH:MM:SS"; default is the newest HUD line


def collect(seconds):
    """Read HUD lines from the last N seconds of CS2's stderr log (the system log copy redacts the numbers)."""
    lines = open(LOG, errors="replace").read().splitlines()
    stamped = [(line[:23], line) for line in lines if "metal-HUD:" in line]
    if not stamped:
        return np.array([]), np.array([])
    newest = datetime.strptime(END, "%Y-%m-%d %H:%M:%S") if END else datetime.strptime(stamped[-1][0], "%Y-%m-%d %H:%M:%S.%f")
    recent = [line for stamp, line in stamped if 0 <= (newest - datetime.strptime(stamp, "%Y-%m-%d %H:%M:%S.%f")).total_seconds() <= seconds]

    intervals, gpu_times = [], []
    for line in recent:
        numbers = [float(x) for x in HUD_LINE.search(line).group(1).split(",") if x]
        pairs = numbers[3:]                       # skip counter + two memory values
        intervals.extend(pairs[0::2])
        gpu_times.extend(pairs[1::2])
    return np.array(intervals), np.array(gpu_times)


def main():
    seconds = int(sys.argv[1]) if len(sys.argv) > 1 else 60
    intervals, gpu = collect(seconds)
    if intervals.size == 0:
        print("no metal-HUD lines found: is CS2 running with HUD=1?")
        return

    fps = 1000.0 / intervals

    print(f"frames sampled     {intervals.size}")
    print(f"avg fps            {1000.0 / intervals.mean():.1f}")
    print(f"1% low fps         {np.percentile(fps, 1):.1f}")
    print(f"0.1% low fps       {np.percentile(fps, 0.1):.1f}")
    print(f"GPU time median    {np.median(gpu):.2f} ms  (p99 {np.percentile(gpu, 99):.2f} ms)")
    print(f"GPU-bound max fps  ~{1000.0 / np.median(gpu):.0f} if uncapped")
    print(f"hitches >25 ms     {(intervals > 25).sum()}   (feels like a skip)")
    print(f"hitches >50 ms     {(intervals > 50).sum()}   (visible freeze)")
    print(f"worst frame        {intervals.max():.1f} ms")


if __name__ == "__main__":
    main()
