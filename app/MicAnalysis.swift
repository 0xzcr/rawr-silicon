// Finds static in a recording of a steady test tone.
//
// A clean recording of a sine wave is still a sine wave in every short window. Static (dropouts, clicks,
// buffer glitches, a Bluetooth link breaking up) shows up as windows where a sine fit stops matching.
import Foundation

struct MicReport {
    let seconds: Double
    let levelDBFS: Double
    let glitchWindows: Int
    let longestSilenceMilliseconds: Double

    var isClean: Bool { glitchWindows == 0 && longestSilenceMilliseconds <= 5 }

    /// One sentence for the window.
    var summary: String {
        if levelDBFS < -45 {
            return "The mic barely heard the tone (\(Int(levelDBFS)) dBFS). Turn the volume up, or allow microphone access."
        }
        if isClean {
            return "Clean: no breaks in \(Int(seconds)) seconds of audio."
        }
        return "Static: \(glitchWindows) broken 10 ms moments, longest dropout \(Int(longestSilenceMilliseconds)) ms."
    }
}

enum MicAnalysis {
    static let windowMilliseconds = 10.0
    /// A window is broken if its leftover noise is 4x the typical window's...
    static let glitchFactor = 4.0
    /// ...and at least 15% of the tone, so room noise on a very clean take isn't counted;
    static let glitchFloor = 0.15
    /// or if any single sample is off by half the tone (a click);
    static let clickFloor = 0.5
    /// or if the tone itself drops below half its usual size (a dropout or the level pumping).
    static let dropoutFloor = 0.5

    // MARK: WAV reading

    private static func uint16(_ data: Data, _ offset: Int) -> Int {
        Int(data[offset]) | Int(data[offset + 1]) << 8
    }

    private static func uint32(_ data: Data, _ offset: Int) -> Int {
        uint16(data, offset) | uint16(data, offset + 2) << 16
    }

    /// Reads a 16-bit PCM WAV and returns its first channel as floats in [-1, 1], plus the sample rate.
    static func loadWav(_ url: URL) -> (samples: [Float], rate: Int)? {
        guard let data = try? Data(contentsOf: url), data.count > 44,
              String(decoding: data[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: data[8..<12], as: UTF8.self) == "WAVE" else { return nil }

        var channels = 1
        var rate = 0
        var offset = 12
        // Walk the chunks: "fmt " says how to read the audio, "data" holds it.
        while offset + 8 <= data.count {
            let chunkID = String(decoding: data[offset..<offset + 4], as: UTF8.self)
            let chunkSize = uint32(data, offset + 4)
            let body = offset + 8
            if chunkID == "fmt " {
                channels = max(1, uint16(data, body + 2))
                rate = uint32(data, body + 4)
            }
            if chunkID == "data", rate > 0 {
                let available = min(chunkSize, data.count - body)
                return (firstChannel(data, start: body, bytes: available, channels: channels), rate)
            }
            offset = body + chunkSize + (chunkSize % 2)   // chunks are padded to an even size
        }
        return nil
    }

    /// Decodes little-endian Int16 frames, keeping only channel 0.
    private static func firstChannel(_ data: Data, start: Int, bytes: Int, channels: Int) -> [Float] {
        let frameBytes = 2 * channels
        let frames = bytes / frameBytes
        var samples = [Float](repeating: 0, count: frames)
        for frame in 0..<frames {
            let raw = Int16(truncatingIfNeeded: uint16(data, start + frame * frameBytes))
            samples[frame] = Float(raw) / 32768
        }
        return samples
    }

    // MARK: Sine fit

    /// Determinant of a 3x3 matrix.
    private static func determinant(_ a: [[Double]]) -> Double {
        a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1])
            - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
            + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
    }

    /// `m` with column `column` swapped for `v`.
    private static func replacingColumn(_ m: [[Double]], _ column: Int, with v: [Double]) -> [[Double]] {
        var copy = m
        for row in 0..<3 {
            copy[row][column] = v[row]
        }
        return copy
    }

    /// Solves the 3x3 system m * x = v with Cramer's rule (m is symmetric and well-conditioned here).
    private static func solve3(_ m: [[Double]], _ v: [Double]) -> [Double] {
        let whole = determinant(m)
        guard abs(whole) > 1e-12 else { return [0, 0, 0] }
        let a = determinant(replacingColumn(m, 0, with: v)) / whole
        let b = determinant(replacingColumn(m, 1, with: v)) / whole
        let c = determinant(replacingColumn(m, 2, with: v)) / whole
        return [a, b, c]
    }

    /// How one window compares with a pure tone.
    struct WindowFit {
        let leftoverRMS: Double     // what's left after removing the fitted tone
        let leftoverPeak: Double    // the single worst sample of that leftover
        let toneSize: Double        // amplitude of the fitted tone
    }

    /// Fits a*sin + b*cos + c at the tone frequency to one window.
    static func windowFit(_ window: ArraySlice<Float>, rate: Int, toneHz: Double) -> WindowFit {
        let omega = 2 * Double.pi * toneHz / Double(rate)
        var sums = (ss: 0.0, sc: 0.0, s: 0.0, cc: 0.0, c: 0.0, sy: 0.0, cy: 0.0, y: 0.0)

        // Pass 1: the sums for the least-squares normal equations.
        for (index, sample) in window.enumerated() {
            let sine = sin(omega * Double(index))
            let cosine = cos(omega * Double(index))
            let y = Double(sample)
            sums.ss += sine * sine
            sums.sc += sine * cosine
            sums.s += sine
            sums.cc += cosine * cosine
            sums.c += cosine
            sums.sy += sine * y
            sums.cy += cosine * y
            sums.y += y
        }
        let n = Double(window.count)
        let fit = solve3([[sums.ss, sums.sc, sums.s], [sums.sc, sums.cc, sums.c], [sums.s, sums.c, n]],
                         [sums.sy, sums.cy, sums.y])

        // Pass 2: what's left after removing the fitted tone.
        var squaredSum = 0.0
        var peak = 0.0
        for (index, sample) in window.enumerated() {
            let model = fit[0] * sin(omega * Double(index)) + fit[1] * cos(omega * Double(index)) + fit[2]
            let difference = abs(Double(sample) - model)
            squaredSum += difference * difference
            peak = max(peak, difference)
        }
        return WindowFit(leftoverRMS: sqrt(squaredSum / n), leftoverPeak: peak, toneSize: hypot(fit[0], fit[1]))
    }

    /// The middle value (median) of a list.
    private static func median(_ values: [Double]) -> Double {
        values.sorted()[values.count / 2]
    }

    // MARK: Report

    /// Longest run of exact digital silence: a sign of the audio buffer running dry.
    private static func longestZeroRun(_ samples: ArraySlice<Float>) -> Int {
        var longest = 0
        var current = 0
        for sample in samples {
            current = sample == 0 ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }

    /// Analyses a tone recording, ignoring the first `skipSeconds` (Bluetooth earbuds glitch ~3 s while switching
    /// into headset mode, natively too) and the last half second.
    static func analyze(samples: [Float], rate: Int, toneHz: Double = 440, skipSeconds: Double = 0.5) -> MicReport {
        let start = min(samples.count, Int(Double(rate) * skipSeconds))
        let end = max(start, samples.count - rate / 2)
        let usable = samples[start..<end]

        let windowSize = Int(Double(rate) * windowMilliseconds / 1000)
        let windowCount = usable.count / windowSize
        guard windowCount > 0 else { return MicReport(seconds: 0, levelDBFS: -120, glitchWindows: 0, longestSilenceMilliseconds: 0) }

        // Fit every window, in order.
        let fits: [WindowFit] = (0..<windowCount).map { index in
            let windowStart = usable.startIndex + index * windowSize
            return windowFit(usable[windowStart..<windowStart + windowSize], rate: rate, toneHz: toneHz)
        }

        // Judge each window against the whole recording's typical tone, not its own:
        // a fully silent window fits "a tone of size zero" perfectly and would otherwise look clean.
        let typicalTone = median(fits.map(\.toneSize)) + 1e-9
        let typicalLeftover = median(fits.map(\.leftoverRMS))
        let noiseLimit = max(typicalLeftover * glitchFactor, glitchFloor * typicalTone)
        let broken = fits.filter { fit in
            fit.leftoverRMS > noiseLimit
                || fit.leftoverPeak > clickFloor * typicalTone
                || fit.toneSize < dropoutFloor * typicalTone
        }.count

        let peak = usable.map { abs($0) }.max() ?? 0
        return MicReport(seconds: Double(usable.count) / Double(rate),
                         levelDBFS: 20 * log10(Double(peak) + 1e-9),
                         glitchWindows: broken,
                         longestSilenceMilliseconds: Double(longestZeroRun(usable)) * 1000 / Double(rate))
    }
}
