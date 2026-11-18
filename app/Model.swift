// App state: setup progress, the game, and the microphone.
import AppKit
import Foundation

/// How far this Mac is from being able to play (the word scripts/status.sh prints).
enum SetupState: String {
    case checking
    case noRosetta = "no-rosetta"
    case noWhisky = "no-whisky"
    case noEngine = "no-engine"
    case noBottle = "no-bottle"
    case noSteam = "no-steam"
    case ready
}

final class Model: ObservableObject {
    @Published var setup: SetupState
    @Published var setupRunning = false
    @Published var setupMessage: String?

    @Published var preset: Preset
    @Published var gameRunning = false
    @Published var busy = false
    @Published var status = "Ready"

    @Published var microphone: Microphone? = currentMicrophone()
    @Published var micTesting = false
    @Published var micResult: MicReport?
    @Published var micError: String?

    private var timer: Timer?
    private let tone = TonePlayer()

    /// `setup` is only passed for snapshots; the real app asks scripts/status.sh.
    init(preset: Preset = .smooth, setup: SetupState? = nil) {
        self.preset = preset
        self.setup = setup ?? .checking
        guard setup == nil else { return }
        refreshSetup()
        // Cheap poll: notices Whisky being installed, the game closing, and headphones (dis)connecting.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        microphone = currentMicrophone()
        if setup != .ready && !setupRunning {
            refreshSetup()
        }
        let running = isGameRunning()
        if running != gameRunning {
            gameRunning = running
            busy = false
            status = running ? "CS2 is running" : "Ready"
        }
    }

    // MARK: Setup

    func refreshSetup() {
        runScript("status.sh", done: { [weak self] output, _ in
            let word = output.trimmingCharacters(in: .whitespacesAndNewlines)
            self?.setup = SetupState(rawValue: word) ?? .checking
        })
    }

    func runSetup() {
        setupRunning = true
        setupMessage = "Starting…"
        runScript("setup.sh", onLine: { [weak self] line in
            // "STEP Installing Steam" -> "Installing Steam"; "ERROR ..." stays visible.
            if line.hasPrefix("STEP ") { self?.setupMessage = String(line.dropFirst(5)) }
            if line.hasPrefix("ERROR ") { self?.setupMessage = String(line.dropFirst(6)) }
        }, done: { [weak self] _, status in
            self?.setupRunning = false
            if status == 0 { self?.setupMessage = nil }
            self?.refreshSetup()
        })
    }

    // MARK: Game

    func play() {
        // Read the display at every launch, so it follows whatever screen is primary right now.
        guard let screen = gameScreen() else {
            status = "No display found"
            return
        }
        let size = preset.resolution(on: screen)
        busy = true
        status = "Starting Steam and CS2…"
        runScript("launch.sh",
                  arguments: ["-fullscreen", "-w", "\(size.width)", "-h", "\(size.height)"],
                  environment: ["RETINA": preset == .sharp ? "1" : "0"],
                  onLine: { [weak self] line in
                      if line.hasPrefix("NOTICE ") {
                          self?.busy = false
                          self?.status = String(line.dropFirst(7))
                      }
                  },
                  done: { [weak self] output, status in
                      // Wine's own output goes to the log file, so a failure here is the script itself.
                      guard let self, status != 0, !self.gameRunning else { return }
                      let lastLine = output.split(separator: "\n").last.map(String.init) ?? "unknown error"
                      self.busy = false
                      self.status = "Couldn't start: \(lastLine.replacingOccurrences(of: "ERROR ", with: ""))"
                  })
    }

    func stop() {
        busy = true
        status = "Closing CS2…"
        runScript("stop.sh", done: { [weak self] _, _ in self?.tick() })
    }

    // MARK: Microphone

    func useBuiltInMicrophone() {
        guard let id = builtInMicrophone() else { return }
        setDefaultMicrophone(id)
        microphone = currentMicrophone()
        micResult = nil
    }

    /// Plays a tone on the MacBook speakers, records the default mic through Wine (as CS2 would), and looks for breaks.
    func runMicTest(done: (() -> Void)? = nil) {
        guard let speakers = builtInSpeakers() else {
            micError = "The mic test needs the Mac's built-in speakers."
            done?()
            return
        }
        micTesting = true
        micResult = nil
        micError = nil

        do {
            try tone.start(on: speakers)
        } catch {
            micTesting = false
            micError = "Couldn't play the test tone: \(error.localizedDescription)"
            done?()
            return
        }

        try? FileManager.default.createDirectory(at: Paths.state, withIntermediateDirectories: true)
        let recording = Paths.state.appendingPathComponent("mic-test.wav")
        let settleSeconds = 3.0      // Bluetooth earbuds glitch while switching into headset mode, natively too
        runScript("mictest.sh", arguments: [Paths.micRecorder.path, "11", recording.path], done: { [weak self] output, status in
            guard let self else { return }
            self.tone.stop()
            self.micTesting = false
            if status == 0, let audio = MicAnalysis.loadWav(recording) {
                self.micResult = MicAnalysis.analyze(samples: audio.samples, rate: audio.rate, skipSeconds: settleSeconds)
            } else {
                let lastLine = output.split(separator: "\n").last.map(String.init) ?? "recording failed"
                self.micError = lastLine.replacingOccurrences(of: "ERROR ", with: "")
            }
            done?()
        })
    }
}
