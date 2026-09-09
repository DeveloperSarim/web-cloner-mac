// Real screenshot check: swiftc Sources/Engine.swift Tests/shot.swift -o /tmp/shottest && /tmp/shottest
import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let out = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wcshot-\(UUID().uuidString)")
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let s = Shooter(width: 1200)
s.capture("https://example.com", into: out) { r in
    switch r {
    case .success(let f):
        let img = NSImage(contentsOf: f)!
        assert(img.size.width >= 1000, "\(img.size)")
        print("screenshot ok: \(Int(img.size.width))x\(Int(img.size.height)) \(f.lastPathComponent)")
        try? FileManager.default.removeItem(at: out)
        exit(0)
    case .failure(let e):
        print("screenshot FAILED: \(e.localizedDescription)"); exit(1)
    }
}
app.run()
