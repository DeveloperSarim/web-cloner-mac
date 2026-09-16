import Foundation
import AppKit

struct WCError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}

struct Release: Decodable, Equatable {
    struct Asset: Decodable, Equatable { let name: String; let browserDownloadUrl: String }
    let tagName: String
    let body: String?
    let assets: [Asset]

    var version: String { tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName }
    var dmg: URL? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }
            .flatMap { URL(string: $0.browserDownloadUrl) }
    }
    /// First real line of the release notes, for the one-line summary in the banner.
    var headline: String {
        (body ?? "").split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("#") } ?? ""
    }
}

func isNewer(_ remote: String, than local: String) -> Bool {
    let a = remote.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    let b = local.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    for i in 0 ..< max(a.count, b.count) {
        let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
        if x != y { return x > y }
    }
    return false
}

/// Replaces the running app with the newest GitHub release: download the DMG, copy the app
/// out of it next to the current one, then let a small script swap them once we quit.
final class Updater: ObservableObject {
    enum State: Equatable { case idle, checking, found, downloading, installing, current, failed(String) }

    @Published var state: State = .idle
    @Published var release: Release?
    @Published var manual = false

    static let repo = "DeveloperSarim/web-cloner-mac"
    var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func dismiss() { state = .idle; release = nil }

    func check(manual: Bool = false) {
        if state == .checking || state == .downloading || state == .installing { return }
        self.manual = manual
        state = .checking
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Updater.repo)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20
        URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let data, err == nil else {
                    self.state = .failed(err?.localizedDescription ?? "GitHub did not answer")
                    return
                }
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                guard let rel = try? decoder.decode(Release.self, from: data) else {
                    self.state = .failed("Could not read the latest release")
                    return
                }
                self.release = rel
                self.state = isNewer(rel.version, than: self.current) ? .found : .current
                if self.state == .current && !manual {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.dismiss() }
                }
            }
        }.resume()
    }

    func install(into target: URL = Bundle.main.bundleURL) {
        guard let dmg = release?.dmg else { state = .failed("That release has no DMG"); return }
        let folder = target.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            state = .failed("\(folder.lastPathComponent) is locked — install the DMG by hand")
            return
        }
        state = .downloading
        URLSession.shared.downloadTask(with: dmg) { [weak self] tmp, _, err in
            guard let self else { return }
            guard let tmp else {
                DispatchQueue.main.async { self.state = .failed(err?.localizedDescription ?? "Download failed") }
                return
            }
            let file = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("WebCloner-update-\(UUID().uuidString).dmg")
            do { try FileManager.default.moveItem(at: tmp, to: file) } catch {
                DispatchQueue.main.async { self.state = .failed(error.localizedDescription) }
                return
            }
            DispatchQueue.main.async { self.state = .installing }
            do {
                let staged = try self.stage(dmg: file, for: target)
                try? FileManager.default.removeItem(at: file)
                DispatchQueue.main.async { self.swapAndRelaunch(staged: staged, target: target) }
            } catch {
                try? FileManager.default.removeItem(at: file)
                DispatchQueue.main.async { self.state = .failed(error.localizedDescription) }
            }
        }.resume()
    }

    /// Mounts the DMG and copies the app beside the current one. Returns the staged copy.
    func stage(dmg: URL, for target: URL) throws -> URL {
        let fm = FileManager.default
        let mount = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wc-mount-\(UUID().uuidString)")
        try fm.createDirectory(at: mount, withIntermediateDirectories: true)
        try sh("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mount.path])
        defer {
            _ = try? sh("/usr/bin/hdiutil", ["detach", mount.path, "-force"])
            try? fm.removeItem(at: mount)
        }
        let apps = try fm.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "app" }
        guard let fresh = apps.first else { throw WCError("No app inside the disk image") }
        let staged = target.deletingLastPathComponent()
            .appendingPathComponent(".\(target.deletingPathExtension().lastPathComponent)-update.app")
        try? fm.removeItem(at: staged)
        try fm.copyItem(at: fresh, to: staged)
        return staged
    }

    /// The running app cannot replace itself, so hand the swap to a script that waits for us to quit.
    private func swapAndRelaunch(staged: URL, target: URL) {
        let script = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(target.path)"
        mv "\(staged.path)" "\(target.path)"
        xattr -cr "\(target.path)" 2>/dev/null
        open "\(target.path)"
        rm -f "$0"
        """
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wc-update-\(UUID().uuidString).sh")
        guard (try? script.write(to: file, atomically: true, encoding: .utf8)) != nil else {
            state = .failed("Could not write the update helper"); return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = [file.path]
        do { try p.run() } catch { state = .failed(error.localizedDescription); return }
        NSApp.terminate(nil)
    }

    @discardableResult
    func sh(_ tool: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        try p.run()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw WCError("\(URL(fileURLWithPath: tool).lastPathComponent): "
                          + out.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return out
    }
}
