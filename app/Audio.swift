// Reading and changing the Mac's audio devices through CoreAudio.
import CoreAudio

/// What we need to know about a microphone to predict voice-chat quality.
struct Microphone {
    let id: AudioObjectID
    let name: String
    let isBluetooth: Bool
    let sampleRate: Double

    /// Bluetooth headset mode and anything under 48 kHz sound bad to teammates.
    var isLowQuality: Bool { isBluetooth || sampleRate < 48_000 }
}

/// Builds the address CoreAudio wants for a property.
private func address(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

/// Reads one fixed-size property (a number, an ID, or a CFString reference), or returns `fallback`.
func readProperty<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, fallback: T) -> T {
    var propertyAddress = address(selector)
    var value = fallback
    var size = UInt32(MemoryLayout<T>.size)
    // CoreAudio writes raw bytes into the value's memory.
    let status = withUnsafeMutableBytes(of: &value) { bytes in
        AudioObjectGetPropertyData(object, &propertyAddress, 0, nil, &size, bytes.baseAddress!)
    }
    return status == noErr ? value : fallback
}

/// The device's connection type (built-in, USB, Bluetooth, ...).
func transportType(_ id: AudioObjectID) -> UInt32 {
    readProperty(id, kAudioDevicePropertyTransportType, fallback: UInt32(0))
}

/// Builds a Microphone description for one device ID.
func describeMicrophone(_ id: AudioObjectID) -> Microphone {
    let name: Unmanaged<CFString>? = readProperty(id, kAudioObjectPropertyName, fallback: nil)
    let rate: Float64 = readProperty(id, kAudioDevicePropertyNominalSampleRate, fallback: 0)
    let transport = transportType(id)
    let bluetooth = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    return Microphone(id: id,
                      name: (name?.takeRetainedValue() as String?) ?? "Unknown mic",
                      isBluetooth: bluetooth,
                      sampleRate: rate)
}

/// The mic macOS (and so CS2 under Wine) records from right now.
func currentMicrophone() -> Microphone? {
    let id: AudioObjectID = readProperty(AudioObjectID(kAudioObjectSystemObject),
                                         kAudioHardwarePropertyDefaultInputDevice, fallback: 0)
    return id == 0 ? nil : describeMicrophone(id)
}

/// Every audio device ID on the system.
func allAudioDevices() -> [AudioObjectID] {
    var propertyAddress = address(kAudioHardwarePropertyDevices)
    let system = AudioObjectID(kAudioObjectSystemObject)
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(system, &propertyAddress, 0, nil, &size)
    var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
    AudioObjectGetPropertyData(system, &propertyAddress, 0, nil, &size, &ids)
    return ids
}

/// True if the device has at least one stream in `scope` (input = can record, output = can play).
func hasStreams(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
    var propertyAddress = address(kAudioDevicePropertyStreams, scope: scope)
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(id, &propertyAddress, 0, nil, &size)
    return size > 0
}

/// The Mac's own microphone, if it has one.
func builtInMicrophone() -> AudioObjectID? {
    allAudioDevices().first { id in
        transportType(id) == kAudioDeviceTransportTypeBuiltIn && hasStreams(id, scope: kAudioObjectPropertyScopeInput)
    }
}

/// The Mac's own speakers: the mic test plays its tone here, even while headphones are the default output.
func builtInSpeakers() -> AudioObjectID? {
    allAudioDevices().first { id in
        transportType(id) == kAudioDeviceTransportTypeBuiltIn && hasStreams(id, scope: kAudioObjectPropertyScopeOutput)
    }
}

/// Makes `id` the system's default input (same as picking it in System Settings > Sound > Input).
func setDefaultMicrophone(_ id: AudioObjectID) {
    var propertyAddress = address(kAudioHardwarePropertyDefaultInputDevice)
    var newID = id
    AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil,
                               UInt32(MemoryLayout<AudioObjectID>.size), &newID)
}
