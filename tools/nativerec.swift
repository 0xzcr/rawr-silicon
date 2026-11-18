// nativerec: record the default mic with macOS's own audio stack (no Wine), as a baseline.
// Usage: nativerec <seconds> <out.wav>    Records at the mic's own sample rate, mono 16-bit.
import AVFoundation

let seconds = Double(CommandLine.arguments[1])!
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])

let engine = AVAudioEngine()
let input = engine.inputNode
let deviceFormat = input.outputFormat(forBus: 0)

// Write mono 16-bit at the device's rate, so nothing here resamples the audio.
let fileSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatLinearPCM,
    AVSampleRateKey: deviceFormat.sampleRate,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
]
// Optional so it can be released before exit: AVAudioFile only finalises the WAV header when freed.
var file: AVAudioFile? = try AVAudioFile(forWriting: outURL, settings: fileSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
let monoFormat = AVAudioFormat(standardFormatWithSampleRate: deviceFormat.sampleRate, channels: 1)!

input.installTap(onBus: 0, bufferSize: 1024, format: deviceFormat) { buffer, _ in
    // Keep only the first channel.
    let mono = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameLength)!
    mono.frameLength = buffer.frameLength
    memcpy(mono.floatChannelData![0], buffer.floatChannelData![0], Int(buffer.frameLength) * MemoryLayout<Float>.size)
    try? file?.write(from: mono)
}
try engine.start()
Thread.sleep(forTimeInterval: seconds)
engine.stop()
input.removeTap(onBus: 0)
file = nil
print("recorded \(seconds)s at \(Int(deviceFormat.sampleRate)) Hz to \(outURL.path)")
