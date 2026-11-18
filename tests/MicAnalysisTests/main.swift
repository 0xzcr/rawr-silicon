// Self-checks for app/MicAnalysis.swift on synthetic recordings with known defects.
// Run: tests/run.sh   (compiles this file together with app/MicAnalysis.swift)
import Foundation

var failures = 0

func check(_ condition: Bool, _ message: String) {
    print(condition ? "  ok    \(message)" : "  FAIL  \(message)")
    if !condition { failures += 1 }
}

/// `seconds` of a 440 Hz tone at 48 kHz with a little noise, like a real mic.
func tone(seconds: Double, amplitude: Float = 0.3, rate: Int = 48_000) -> [Float] {
    var generator = SystemRandomNumberGenerator()
    let count = Int(seconds * Double(rate))
    var samples = [Float](repeating: 0, count: count)
    for index in 0..<count {
        let noise = Float.random(in: -0.003...0.003, using: &generator)
        samples[index] = amplitude * Float(sin(2 * Double.pi * 440 * Double(index) / Double(rate))) + noise
    }
    return samples
}

/// Writes 16-bit mono PCM, the format micrec.exe produces.
func writeWav(_ samples: [Float], rate: Int, to url: URL) {
    var data = Data()
    func append32(_ value: Int) { withUnsafeBytes(of: UInt32(value).littleEndian) { data.append(contentsOf: $0) } }
    func append16(_ value: Int) { withUnsafeBytes(of: UInt16(value).littleEndian) { data.append(contentsOf: $0) } }
    data.append(contentsOf: Array("RIFF".utf8)); append32(36 + samples.count * 2)
    data.append(contentsOf: Array("WAVEfmt ".utf8)); append32(16)
    append16(1); append16(1); append32(rate); append32(rate * 2); append16(2); append16(16)
    data.append(contentsOf: Array("data".utf8)); append32(samples.count * 2)
    for sample in samples {
        withUnsafeBytes(of: Int16(max(-1, min(1, sample)) * 32767).littleEndian) { data.append(contentsOf: $0) }
    }
    try! data.write(to: url)
}

print("MicAnalysis")

// 1. A clean tone has no breaks.
let clean = MicAnalysis.analyze(samples: tone(seconds: 6), rate: 48_000)
check(clean.isClean, "clean tone reports clean (\(clean.glitchWindows) broken windows)")

// 2. A 40 ms dropout (buffer underrun) is caught, both as broken windows and as exact silence.
var dropout = tone(seconds: 6)
dropout.replaceSubrange(96_000..<97_920, with: [Float](repeating: 0, count: 1_920))
let dropoutReport = MicAnalysis.analyze(samples: dropout, rate: 48_000)
check(dropoutReport.glitchWindows >= 3, "40 ms dropout gives broken windows (\(dropoutReport.glitchWindows))")
check(dropoutReport.longestSilenceMilliseconds >= 39, "40 ms dropout measured as silence (\(Int(dropoutReport.longestSilenceMilliseconds)) ms)")

// 3. Clicks (single-sample spikes, like crackle) are caught.
var clicks = tone(seconds: 6)
for position in stride(from: 50_000, to: 250_000, by: 40_000) {
    clicks[position] = 0.95
}
let clickReport = MicAnalysis.analyze(samples: clicks, rate: 48_000)
check(clickReport.glitchWindows >= 4, "5 clicks give broken windows (\(clickReport.glitchWindows))")

// 4. The settle skip ignores a broken start (Bluetooth switching into headset mode).
var badStart = tone(seconds: 8)
badStart.replaceSubrange(0..<96_000, with: [Float](repeating: 0, count: 96_000))
let skipped = MicAnalysis.analyze(samples: badStart, rate: 48_000, skipSeconds: 3)
check(skipped.isClean, "a broken first 2 s is ignored with a 3 s settle")

// 5. A tone the mic barely heard is reported as quiet, not as clean.
let quiet = MicAnalysis.analyze(samples: tone(seconds: 6, amplitude: 0.002), rate: 48_000)
check(quiet.summary.contains("barely heard"), "a -54 dBFS tone is reported as too quiet")

// 6. WAV round trip at 16 kHz (Bluetooth headset rate).
let url = FileManager.default.temporaryDirectory.appendingPathComponent("vaelos-test.wav")
writeWav(tone(seconds: 2, rate: 16_000), rate: 16_000, to: url)
let loaded = MicAnalysis.loadWav(url)
check(loaded?.rate == 16_000 && loaded?.samples.count == 32_000, "16 kHz WAV loads with the right rate and length")
check(MicAnalysis.loadWav(URL(fileURLWithPath: "/nonexistent.wav")) == nil, "missing file returns nil")

print(failures == 0 ? "all passed" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
