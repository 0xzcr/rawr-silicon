// Plays the mic test's steady tone on one specific output device.
import AVFoundation
import CoreAudio

/// Plays a sine tone on a chosen device (the MacBook speakers), so the mic under test hears it
/// even while headphones are the default output.
final class TonePlayer {
    private let engine = AVAudioEngine()
    private var phase = 0.0

    func start(on device: AudioObjectID, frequency: Double = 440, amplitude: Float = 0.15) throws {
        // Must be set before the engine starts; afterwards the output node reports that device's format.
        try engine.outputNode.auAudioUnit.setDeviceID(device)
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let phaseStep = 2 * Double.pi * frequency / sampleRate
        guard let mono = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }

        // Mono source; the mixer copies it to every speaker channel.
        let source = AVAudioSourceNode(format: mono) { [unowned self] _, _, frameCount, bufferList -> OSStatus in
            let buffer = UnsafeMutableAudioBufferListPointer(bufferList)[0]
            let output = buffer.mData!.assumingMemoryBound(to: Float.self)
            for frame in 0..<Int(frameCount) {
                output[frame] = Float(sin(self.phase)) * amplitude
                self.phase = (self.phase + phaseStep).truncatingRemainder(dividingBy: 2 * Double.pi)
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: mono)
        try engine.start()
    }

    func stop() {
        engine.stop()
    }
}
