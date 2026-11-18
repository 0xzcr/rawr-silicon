// Where the app finds its bundled scripts and writes its own files.
import Foundation

enum Paths {
    /// Contents/Resources of the app bundle (read-only, covered by the code signature).
    static let resources: URL = Bundle.main.resourceURL ?? URL(fileURLWithPath: ".")

    /// The shell scripts that do the real work (setup, launch, stop, mic recording).
    static let scripts: URL = resources.appendingPathComponent("scripts")

    /// The tiny Windows mic recorder that runs inside Wine (built from tools/micrec.c).
    static let micRecorder: URL = resources.appendingPathComponent("bin/micrec.exe")

    /// ~/Library/Application Support/Vaelos Silicon: logs, shader cache, mic test recordings.
    static let state: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Vaelos Silicon")
}
