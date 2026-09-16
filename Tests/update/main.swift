// Updater checks, including a real download + swap into a throwaway folder.
// swiftc Sources/Updater.swift Tests/update/main.swift -o /tmp/u && /tmp/u
import Foundation
import AppKit

assert(isNewer("1.1.0", than: "1.0.1"))
assert(isNewer("1.0.2", than: "1.0.10") == false)
assert(isNewer("2.0", than: "1.9.9"))
assert(isNewer("1.0.1", than: "1.0.1") == false)
assert(isNewer("1.0", than: "1.0.0") == false)
assert(isNewer("1.0.1", than: "1.0") )

let json = """
{"tag_name":"v1.2.3","body":"# Notes\\n\\nFixes images.\\n","assets":[
 {"name":"notes.txt","browser_download_url":"https://x/notes.txt"},
 {"name":"WebCloner.dmg","browser_download_url":"https://x/WebCloner.dmg"}]}
""".data(using: .utf8)!
let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
let rel = try! d.decode(Release.self, from: json)
assert(rel.version == "1.2.3", rel.version)
assert(rel.dmg?.lastPathComponent == "WebCloner.dmg", "\(rel.dmg as Any)")
assert(rel.headline == "Fixes images.", rel.headline)

// End to end: fetch the published release and swap it into a fake install folder.
let up = Updater()
let box = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wc-install-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: box, withIntermediateDirectories: true)
let target = box.appendingPathComponent("WebCloner.app")
try! FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)   // stand-in for the old copy

let done = DispatchSemaphore(value: 0)
var result = ""
up.check(manual: true)
DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
    guard let dmg = up.release?.dmg else { result = "no release"; done.signal(); return }
    URLSession.shared.downloadTask(with: dmg) { tmp, _, err in
        guard let tmp else { result = "download failed: \(err?.localizedDescription ?? "")"; done.signal(); return }
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("t-\(UUID().uuidString).dmg")
        try! FileManager.default.moveItem(at: tmp, to: file)
        do {
            let staged = try up.stage(dmg: file, for: target)
            try FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: staged, to: target)      // what the helper script does
            let exe = target.appendingPathComponent("Contents/MacOS/WebCloner")
            let plist = target.appendingPathComponent("Contents/Info.plist")
            result = FileManager.default.isExecutableFile(atPath: exe.path)
                && FileManager.default.fileExists(atPath: plist.path)
                ? "ok \(up.release?.version ?? "?")" : "swapped bundle is broken"
        } catch { result = "stage failed: \(error.localizedDescription)" }
        try? FileManager.default.removeItem(at: file)
        done.signal()
    }.resume()
}
DispatchQueue.global().async { done.wait(); print("swap: \(result)"); try? FileManager.default.removeItem(at: box)
    assert(result.hasPrefix("ok"), result); print("updater checks passed"); exit(0) }
RunLoop.main.run()
