// The one window.
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if model.setup != .ready {
                setupSection
            }
            playSection
            microphoneSection
            Text("Not affiliated with Valve. Counter-Strike is a trademark of Valve Corporation.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(width: 460)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vaelos Silicon").font(.title.bold())
                Text("Counter-Strike 2 on Apple Silicon").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Setup

    private var setupSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                setupInstructions
                if let message = model.setupMessage {
                    HStack(spacing: 8) {
                        if model.setupRunning { ProgressView().controlSize(.small) }
                        Text(message).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("Setup", systemImage: "wrench.and.screwdriver")
        }
    }

    @ViewBuilder
    private var setupInstructions: some View {
        switch model.setup {
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking this Mac…").foregroundStyle(.secondary)
            }
        case .noRosetta, .noWhisky, .noEngine, .noBottle, .noSteam:
            Text(setupExplanation)
            Button("Set up", action: model.runSetup)
                .buttonStyle(.borderedProminent)
                .disabled(model.setupRunning)
        case .ready:
            EmptyView()
        }
    }

    /// What "Set up" will do from here, so a big download never comes as a surprise.
    private var setupExplanation: String {
        switch model.setup {
        case .noRosetta:
            return "Installs Rosetta 2 (macOS asks for your password once), the Whisky Wine engine (about 470 MB), "
                + "a Windows environment, and Steam from Valve. About five minutes."
        case .noWhisky, .noEngine:
            return "Downloads the Whisky Wine engine (about 470 MB), creates a Windows environment, "
                + "and installs Steam from Valve. About five minutes."
        default:
            return "Creates a Windows environment and installs Steam from Valve. About two minutes."
        }
    }

    // MARK: Play

    private var playSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Graphics", selection: $model.preset) {
                    ForEach(Preset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.gameRunning || model.busy)

                Text(model.preset.caption).font(.callout).foregroundStyle(.secondary)
                if let screen = gameScreen() {
                    let size = model.preset.resolution(on: screen)
                    // verbatim: a plain "3024", not a localized "3,024"
                    Text(verbatim: "Fullscreen \(size.width)×\(size.height) on \(screen.localizedName)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if model.gameRunning {
                        Button("Stop", role: .destructive, action: model.stop).controlSize(.large)
                    } else {
                        Button("Play", action: model.play).buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    if model.busy { ProgressView().controlSize(.small) }
                    Text(model.status).foregroundStyle(.secondary).lineLimit(3)
                }
                .disabled(model.busy || model.setup != .ready)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("Play", systemImage: "gamecontroller")
        }
    }

    // MARK: Microphone

    private var microphoneSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                microphoneRow
                microphoneButtons
                microphoneResult
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Label("Microphone", systemImage: "mic")
        }
    }

    @ViewBuilder
    private var microphoneRow: some View {
        if let mic = model.microphone {
            HStack {
                Text(mic.name).fontWeight(.medium)
                Spacer()
                Text(verbatim: "\(mic.isBluetooth ? "Bluetooth · " : "")\(Int(mic.sampleRate / 1000)) kHz")
                    .foregroundStyle(mic.isLowQuality ? .orange : .secondary)
            }
            if mic.isLowQuality {
                Label("Teammates hear this mic as low-quality audio. Use the MacBook mic and keep your earphones for sound.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        } else {
            Text("No microphone found").foregroundStyle(.secondary)
        }
    }

    private var microphoneButtons: some View {
        HStack {
            if model.microphone?.isLowQuality == true, builtInMicrophone() != nil {
                Button("Use MacBook mic", action: { model.useBuiltInMicrophone() })
            }
            Button(model.micTesting ? "Testing…" : "Run mic test", action: { model.runMicTest() })
                .disabled(model.micTesting || model.gameRunning || model.setup != .ready)
            if model.micTesting { ProgressView().controlSize(.small) }
        }
    }

    @ViewBuilder
    private var microphoneResult: some View {
        if model.micTesting {
            Text("Playing a tone from the speakers for about 15 seconds…").font(.callout).foregroundStyle(.secondary)
        }
        if let report = model.micResult {
            Label(report.summary, systemImage: report.isClean ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .font(.callout)
                .foregroundStyle(report.isClean ? .green : .red)
        }
        if let error = model.micError {
            Label(error, systemImage: "xmark.octagon.fill").font(.callout).foregroundStyle(.red)
        }
    }
}
