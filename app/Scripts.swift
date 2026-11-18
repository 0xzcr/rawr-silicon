// Running the bundled shell scripts, and checking whether the game is up.
import Foundation

/// Runs `scripts/<name>` with bash in the background.
/// `onLine` gets each output line as it arrives; `done` gets the full output and exit status. Both run on the main thread.
/// Arguments go straight to bash as an array, never through a shell string, so nothing in them can inject commands.
func runScript(_ name: String,
               arguments: [String] = [],
               environment: [String: String] = [:],
               onLine: ((String) -> Void)? = nil,
               done: @escaping (_ output: String, _ status: Int32) -> Void = { _, _ in }) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [Paths.scripts.appendingPathComponent(name).path] + arguments
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    // Output arrives in chunks; collect them on the main thread and hand out whole lines.
    var output = ""
    var pendingLine = ""
    func receive(_ data: Data) {
        let text = String(decoding: data, as: UTF8.self)
        output += text
        pendingLine += text
        let lines = pendingLine.components(separatedBy: "\n")
        pendingLine = lines.last ?? ""
        lines.dropLast().forEach { onLine?($0) }
    }

    pipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if !data.isEmpty { DispatchQueue.main.async { receive(data) } }
    }
    process.terminationHandler = { finished in
        pipe.fileHandleForReading.readabilityHandler = nil
        let rest = pipe.fileHandleForReading.readDataToEndOfFile()
        DispatchQueue.main.async {
            receive(rest)
            if !pendingLine.isEmpty { onLine?(pendingLine) }
            done(output, finished.terminationStatus)
        }
    }

    do {
        try process.run()
    } catch {
        done("could not start \(name): \(error.localizedDescription)", -1)
    }
}

/// True while a cs2.exe runs under Wine.
/// shortcut: matches cs2.exe in any Wine prefix (e.g. another CS2 wrapper); check the prefix if that matters.
func isGameRunning() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-f", "win64.cs2\\.exe"]
    process.standardOutput = FileHandle.nullDevice
    do {
        try process.run()
    } catch {
        return false
    }
    process.waitUntilExit()
    return process.terminationStatus == 0
}
