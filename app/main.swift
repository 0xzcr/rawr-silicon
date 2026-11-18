// Vaelos Silicon: Counter-Strike 2 on Apple Silicon.
// The app is a thin front end: the real work lives in Contents/Resources/scripts.
//
// Developer flags:
//   --snapshot out.png [dark] [sharp] [setup=no-rosetta|no-whisky|no-engine|no-bottle|no-steam|ready]
//   --mic-test      run the mic test headlessly and print the result
//   --analyze file.wav [skip_seconds]   analyse a saved tone recording
import AppKit
import SwiftUI

struct VaelosApp: App {
    @StateObject private var model = Model()

    var body: some Scene {
        Window("Vaelos Silicon", id: "main") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

/// The value of a `name=value` argument, if given.
func argumentValue(_ name: String) -> String? {
    let prefix = name + "="
    return CommandLine.arguments.first { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count)) }
}

let arguments = CommandLine.arguments

if let flag = arguments.firstIndex(of: "--snapshot"), flag + 1 < arguments.count {
    _ = NSApplication.shared
    let setup = SetupState(rawValue: argumentValue("setup") ?? "ready") ?? .ready
    writeSnapshot(to: arguments[flag + 1],
                  dark: arguments.contains("dark"),
                  preset: arguments.contains("sharp") ? .sharp : .smooth,
                  setup: setup)
} else if let flag = arguments.firstIndex(of: "--analyze"), flag + 1 < arguments.count {
    let skip = flag + 2 < arguments.count ? Double(arguments[flag + 2]) ?? 0.5 : 0.5
    if let audio = MicAnalysis.loadWav(URL(fileURLWithPath: arguments[flag + 1])) {
        let report = MicAnalysis.analyze(samples: audio.samples, rate: audio.rate, skipSeconds: skip)
        print("\(arguments[flag + 1]): broken \(report.glitchWindows), silence \(Int(report.longestSilenceMilliseconds)) ms, level \(Int(report.levelDBFS)) dBFS")
    } else {
        print("can't read \(arguments[flag + 1])")
    }
} else if arguments.contains("--mic-test") {
    let model = Model(setup: .ready)
    model.runMicTest {
        if let report = model.micResult {
            print("glitch windows \(report.glitchWindows), longest silence \(Int(report.longestSilenceMilliseconds)) ms, level \(Int(report.levelDBFS)) dBFS")
            print(report.summary)
        } else {
            print("error: \(model.micError ?? "unknown")")
        }
        exit(0)
    }
    RunLoop.main.run()
} else {
    VaelosApp.main()
}
