import Foundation
import Combine
import WebKit

enum Mode: String, CaseIterable, Identifiable {
    case clone = "Clone"
    case scan  = "Scan"
    case shot  = "Screenshot"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clone: return "Clone website"
        case .scan:  return "Scan only"
        case .shot:  return "Screenshots"
        }
    }
    var help: String {
        switch self {
        case .clone: return "Pages, styles and assets save karta hai. Site offline khulti hai."
        case .scan:  return "Sirf pages check karta hai, kuch download nahi hota."
        case .shot:  return "Har page ka full-page PNG screenshot leta hai."
        }
    }
}

enum PageState: String {
    case queued = "Queued", active = "Downloading", done = "Done", failed = "Failed", redirect = "Redirect"
}

struct Page: Identifiable {
    let id: String          // full url
    var state: PageState
    var bytes: Int64 = 0
    var note: String = ""
    var short: String {
        guard let u = URL(string: id) else { return id }
        let p = u.path.isEmpty || u.path == "/" ? "/" : u.path
        return u.query == nil ? p : p + "?" + u.query!
    }
    var host: String { URL(string: id)?.host ?? "" }
}

enum Speed: String, CaseIterable, Identifiable {
    case polite = "Polite", normal = "Normal", fast = "Fast"
    var id: String { rawValue }
    var args: [String] {
        switch self {
        case .polite: return ["--wait=1", "--random-wait", "--limit-rate=600k"]
        case .normal: return ["--wait=0.2"]
        case .fast:   return []
        }
    }
}

let assetExts: Set<String> = ["jpg","jpeg","png","gif","webp","svg","ico","bmp","tif","tiff","avif",
                              "mp4","webm","mov","m4v","mp3","wav","ogg","css","js","mjs","json","xml",
                              "woff","woff2","ttf","otf","eot","pdf","zip","gz","txt","map"]

func isAsset(_ url: String) -> Bool {
    assetExts.contains((URL(string: url)?.pathExtension ?? "").lowercased())
}

final class Cloner: ObservableObject {
    // Inputs
    @Published var url = ""
    @Published var dest = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads/WebCloner")
    @Published var mode: Mode = .clone
    @Published var withAssets = true
    @Published var makeSitemap = true
    @Published var ignoreRobots = false
    @Published var depthIndex = 0
    @Published var speed: Speed = .normal
    @Published var shotWidth = 1440

    // Output
    @Published var pages: [Page] = []
    @Published var log: [String] = []
    @Published var running = false
    @Published var files = 0
    @Published var bytes: Int64 = 0
    @Published var status = "Ready"
    @Published var wgetPath: String? = Cloner.findTool("wget")
    @Published var installing = false
    @Published var lastOutput: URL?

    static let depths = ["Whole site", "1 level", "2 levels", "3 levels", "5 levels"]
    static let depthValues = ["inf", "1", "2", "3", "5"]
    static let searchDirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/opt/local/bin"]

    static func findTool(_ name: String) -> String? {
        searchDirs.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private var task: Process?
    private var index: [String: Int] = [:]
    private var current: String?
    private var shooter: Shooter?

    var target: String {
        let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        return t.hasPrefix("http") ? t : "https://" + t
    }
    var ready: Bool { mode == .shot || wgetPath != nil }
    var canStart: Bool { !running && !installing && !target.isEmpty && ready }
    var counts: [PageState: Int] {
        pages.reduce(into: [:]) { $0[$1.state, default: 0] += 1 }
    }
    var siteFolder: URL? {
        guard let host = URL(string: target)?.host else { return nil }
        return dest.appendingPathComponent(host)
    }

    // MARK: Run

    func start() {
        guard let u = URL(string: target), u.host != nil else {
            append("Valid address likhein, jaise example.com"); return
        }
        pages = []; index = [:]; current = nil; log = []; files = 0; bytes = 0; lastOutput = nil
        running = true
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        if mode == .shot && wgetPath == nil { startShots([u.absoluteString]) } else { startWget() }
    }

    private func startWget() {
        guard let wget = wgetPath else { return }
        status = mode == .clone ? "Cloning…" : "Scanning pages…"
        let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("webcloner-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

        var args = ["--recursive", "--level=\(Cloner.depthValues[depthIndex])", "--no-parent",
                    "--timeout=20", "--tries=2", "--waitretry=2"] + speed.args
        args.append("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
                    "(KHTML, like Gecko) Version/17.0 Safari/605.1.15")
        if ignoreRobots { args += ["-e", "robots=off"] }
        if mode != .clone {
            args += ["--spider", "--delete-after"]
        } else {
            args += ["--convert-links", "--adjust-extension", "--page-requisites",
                     "--directory-prefix=\(dest.path)"]
            if !withAssets {
                args += ["--reject", "jpg,jpeg,png,gif,webp,svg,ico,bmp,tif,tiff,avif,mp4,webm,mov,mp3,wav,ogg"]
            }
        }
        args.append(target)
        run(wget, args, in: scratch, label: "wget") { [weak self] code in
            try? FileManager.default.removeItem(at: scratch)
            self?.finish(code: code)
        }
    }

    private func run(_ tool: String, _ args: [String], in dir: URL?, label: String,
                     done: @escaping (Int32) -> Void) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        if let dir { p.currentDirectoryURL = dir }
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = (Cloner.searchDirs + ["/sbin", "/usr/sbin"]).joined(separator: ":")
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        append("$ \(label) " + args.map { $0.contains(" ") ? "\"\($0)\"" : $0 }.joined(separator: " "))

        var carry = ""
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let chunk = h.availableData
            guard !chunk.isEmpty, let text = String(data: chunk, encoding: .utf8) else { return }
            carry += text
            let parts = carry.components(separatedBy: "\n")
            carry = parts.last ?? ""
            for line in parts.dropLast() { DispatchQueue.main.async { self?.consume(line) } }
        }
        p.terminationHandler = { proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { done(proc.terminationStatus) }
        }
        do { try p.run(); task = p } catch {
            append("Chala nahi saka: \(error.localizedDescription)")
            running = false; installing = false; status = "Failed"
        }
    }

    func stop() {
        status = "Stopping…"
        task?.terminate()
        shooter?.cancel()
    }

    // MARK: Parsing

    func consume(_ line: String) {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }

        if t.hasPrefix("--"), let r = t.range(of: "http") {
            begin(String(t[r.lowerBound...]))
        } else if let r = t.range(of: "awaiting response... ") {
            let rest = t[r.upperBound...]
            let code = Int(rest.prefix(3)) ?? 0
            if code >= 400 { close(.failed, note: String(rest)) }
            else if code >= 300 { close(.redirect, note: String(rest)) }
        } else if t.contains(" saved [") || t.hasPrefix("URL:") {
            files += 1
            let n = size(in: t)
            bytes += n
            close(.done, size: n)
        } else if t.hasPrefix("ERROR ") || t.contains("failed: ") || t.contains("Remote file does not exist") {
            close(.failed, note: t)
        }
        append(t)
    }

    private func size(in line: String) -> Int64 {
        guard let open = line.range(of: "["),
              let close = line.range(of: "]", range: open.upperBound..<line.endIndex) else { return 0 }
        let n = line[open.upperBound..<close.lowerBound].split(separator: "/").first ?? ""
        return Int64(n) ?? 0
    }

    private func begin(_ raw: String) {
        close(.done)                                  // previous one finished
        let url = raw.components(separatedBy: "#").first ?? raw
        guard !isAsset(url) else { current = nil; return }
        current = url
        if let i = index[url] { pages[i].state = .active }
        else {
            index[url] = pages.count
            pages.append(Page(id: url, state: .active))
        }
    }

    private func close(_ state: PageState, size: Int64 = 0, note: String = "") {
        guard let cur = current, let i = index[cur], pages[i].state == .active else { return }
        pages[i].state = state
        if size > 0 { pages[i].bytes = size }
        if !note.isEmpty { pages[i].note = note }
        if state != .active { current = nil }
    }

    func append(_ line: String) {
        log.append(line)
        if log.count > 1200 { log.removeFirst(log.count - 1200) }
    }

    private func finish(code: Int32) {
        close(.done)
        if mode == .shot && running {
            let found = pages.filter { $0.state == .done || $0.state == .active }.map(\.id)
            let list = Array(found.prefix(Cloner.shotCap))
            if found.count > list.count {
                append("Note: pehle \(Cloner.shotCap) pages ke screenshots liye ja rahe hain.")
            }
            startShots(list.isEmpty ? [target] : list)
            return
        }
        running = false
        task = nil
        if makeSitemap && !pages.isEmpty { writeSitemap() }
        let done = counts[.done] ?? 0
        status = "Done — \(done) pages, \(files) files, \(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))"
        if code != 0 && done == 0 { status = "Finished with errors (exit \(code))" }
        append(""); append(status)
        lastOutput = dest
    }

    // MARK: Screenshots

    static let shotCap = 60

    private func startShots(_ list: [String]) {
        let folder = dest.appendingPathComponent("screenshots")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        pages = []; index = [:]; files = 0; bytes = 0
        for u in list { index[u] = pages.count; pages.append(Page(id: u, state: .queued)) }
        shooter = Shooter(width: CGFloat(shotWidth))
        shootNext(list, 0, folder)
    }

    private func shootNext(_ list: [String], _ i: Int, _ folder: URL) {
        guard running, i < list.count, let shooter else {
            for k in pages.indices where pages[k].state == .queued || pages[k].state == .active {
                pages[k].state = .failed
            }
            if makeSitemap { writeSitemap() }
            self.status = "Done — \(counts[.done] ?? 0) screenshots in screenshots/"
            self.running = false; self.lastOutput = folder; self.shooter = nil
            self.append(""); self.append(self.status); return
        }
        let url = list[i]
        if let k = index[url] { pages[k].state = .active }
        status = "Screenshot \(i + 1)/\(list.count)…"
        append("Capturing \(url)")
        shooter.capture(url, into: folder) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let file):
                let n = ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? Int64) ?? 0
                self.files += 1; self.bytes += n
                if let k = self.index[url] { self.pages[k].state = .done; self.pages[k].bytes = n }
                self.append("Saved \(file.lastPathComponent)")
            case .failure(let e):
                if let k = self.index[url] { self.pages[k].state = .failed; self.pages[k].note = e.localizedDescription }
                self.append("Failed: \(e.localizedDescription)")
            }
            self.shootNext(list, i + 1, folder)
        }
    }

    // MARK: Sitemap

    func writeSitemap() {
        let esc: (String) -> String = {
            $0.replacingOccurrences(of: "&", with: "&amp;")
              .replacingOccurrences(of: "<", with: "&lt;")
              .replacingOccurrences(of: ">", with: "&gt;")
              .replacingOccurrences(of: "\"", with: "&quot;")
        }
        let live = pages.filter { $0.state == .done }.map(\.id)
        guard !live.isEmpty else { return }
        let body = live.map { "  <url><loc>\(esc($0))</loc></url>" }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        \(body)
        </urlset>
        """
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        let file = dest.appendingPathComponent("sitemap.xml")
        do {
            try xml.write(to: file, atomically: true, encoding: .utf8)
            append("Sitemap: \(file.path)")
        } catch { append("Sitemap fail: \(error.localizedDescription)") }
    }

    // MARK: wget setup

    var brewPath: String? { Cloner.findTool("brew") }

    func installWget() {
        guard let brew = brewPath else { installHomebrewInTerminal(); return }
        installing = true
        status = "Installing wget…"
        log = []
        run(brew, ["install", "wget"], in: nil, label: "brew") { [weak self] code in
            guard let self else { return }
            self.installing = false
            self.wgetPath = Cloner.findTool("wget")
            self.status = self.wgetPath != nil ? "wget ready" : "Install failed (exit \(code))"
            self.append(""); self.append(self.status)
        }
    }

    func installHomebrewInTerminal() {
        let cmd = "/bin/bash -c \\\"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\\\" && brew install wget"
        let script = "tell application \"Terminal\" to do script \"\(cmd)\"\ntell application \"Terminal\" to activate"
        status = "Terminal me Homebrew install ho raha hai…"
        append("Homebrew nahi mila. Terminal khol raha hoon — apna Mac password wahan dalein.")
        run("/usr/bin/osascript", ["-e", script], in: nil, label: "osascript") { _ in }
    }

    func recheckWget() { wgetPath = Cloner.findTool("wget") }
}

// MARK: - Full page screenshots

final class Shooter: NSObject, WKNavigationDelegate {
    private let width: CGFloat
    private var web: WKWebView?
    private var window: NSWindow?
    private var done: ((Result<URL, Error>) -> Void)?
    private var out: URL?
    private var cancelled = false

    init(width: CGFloat) { self.width = width }

    func cancel() { cancelled = true; finish(.failure(Err("cancelled"))) }

    struct Err: LocalizedError { let m: String; init(_ m: String) { self.m = m }
        var errorDescription: String? { m } }

    func capture(_ urlString: String, into folder: URL, done: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: urlString) else { done(.failure(Err("bad url"))); return }
        self.done = done
        let name = (url.host ?? "page") + (url.path.isEmpty || url.path == "/" ? "-home" :
                    url.path.replacingOccurrences(of: "/", with: "-"))
        out = folder.appendingPathComponent(name + ".png")

        let cfg = WKWebViewConfiguration()
        let w = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: 1000), configuration: cfg)
        w.navigationDelegate = self
        let win = NSWindow(contentRect: w.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = w
        win.setFrameOrigin(NSPoint(x: -30000, y: -30000))
        win.orderBack(nil)
        web = w; window = win
        w.load(URLRequest(url: url))
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { [weak self] in
            guard let self, self.web === w, self.done != nil else { return }
            self.finish(.failure(Err("timeout")))
        }
    }

    func webView(_ w: WKWebView, didFinish nav: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !self.cancelled else { return }
            w.evaluateJavaScript("document.body.scrollHeight") { value, _ in
                let h = min(max((value as? CGFloat) ?? 1200, 600), 12000)
                w.frame = CGRect(x: 0, y: 0, width: self.width, height: h)
                self.window?.setContentSize(NSSize(width: self.width, height: h))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    let cfg = WKSnapshotConfiguration()
                    cfg.rect = w.bounds
                    cfg.afterScreenUpdates = true
                    w.takeSnapshot(with: cfg) { image, error in
                        guard let image, let out = self.out else {
                            self.finish(.failure(error ?? Err("snapshot failed"))); return
                        }
                        guard let tiff = image.tiffRepresentation,
                              let rep = NSBitmapImageRep(data: tiff),
                              let png = rep.representation(using: .png, properties: [:]) else {
                            self.finish(.failure(Err("png encode failed"))); return
                        }
                        do { try png.write(to: out); self.finish(.success(out)) }
                        catch { self.finish(.failure(error)) }
                    }
                }
            }
        }
    }

    func webView(_ w: WKWebView, didFail nav: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ w: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ r: Result<URL, Error>) {
        guard let cb = done else { return }
        done = nil
        window?.orderOut(nil); window = nil; web = nil
        cb(r)
    }
}
