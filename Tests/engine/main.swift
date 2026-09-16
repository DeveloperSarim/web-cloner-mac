// Parsing + sitemap smoke test.
// swiftc Sources/Engine.swift Tests/main.swift -o /tmp/enginetest && /tmp/enginetest
import Foundation

let c = Cloner()
c.url = "example.com";        assert(c.target == "https://example.com", c.target)
c.url = " http://foo.dev/x "; assert(c.target == "http://foo.dev/x", c.target)

[
    "--2026-09-09 17:10:29--  https://site.com/",
    "HTTP request sent, awaiting response... 200 OK",
    "2026-09-09 17:10:32 (35.5 MB/s) - 'out/index.html' saved [559]",
    "--2026-09-09 17:10:33--  https://site.com/logo.png",
    "2026-09-09 17:10:33 (1.0 MB/s) - 'out/logo.png' saved [2048/2048]",
    "--2026-09-09 17:10:34--  https://site.com/about#team",
    "--2026-09-09 17:10:35--  https://site.com/about",
    "--2026-09-09 17:10:36--  https://site.com/gone",
    "HTTP request sent, awaiting response... 404 Not Found",
    "--2026-09-09 17:10:37--  https://site.com/q?a=1&b=2",
    "2026-09-09 17:10:38 (1.0 MB/s) - 'out/q.html' saved [100]",
].forEach(c.consume)

assert(c.pages.map(\.id) == ["https://site.com/", "https://site.com/about",
                             "https://site.com/gone", "https://site.com/q?a=1&b=2"], "\(c.pages.map(\.id))")
assert(c.pages.map(\.state) == [.done, .done, .failed, .done], "\(c.pages.map(\.state))")
assert(c.pages[0].bytes == 559, "\(c.pages[0].bytes)")
assert(c.files == 3 && c.bytes == 2707, "\(c.files) \(c.bytes)")
assert(c.counts[.done] == 3 && c.counts[.failed] == 1, "\(c.counts)")
assert(c.pages[3].short == "/q?a=1&b=2", c.pages[3].short)
assert(isAsset("https://a.com/x.PNG") && !isAsset("https://a.com/about"))
assert(!isAsset("https://a.com/") && !isAsset("https://a.com/q?a=1&b=2"))
// wget hands us entity-mangled URLs out of style="background-image:url(&quot;...&quot;)"
let mangled = "https://cdn.x.com/a/Rectangle%203.jpg&quot;"
assert(isAsset(mangled), "mangled CDN image must count as an asset, not a page")
assert(trimTail(mangled) == "https://cdn.x.com/a/Rectangle%203.jpg", trimTail(mangled))
// --convert-links then prefixes that mangled URL with the site host; the real one is inside
let wrapped = "https://site.com/&quot;https://cdn.x.com/a/Rectangle%203.jpg"
assert(unwrapURL(wrapped) == "https://cdn.x.com/a/Rectangle%203.jpg", unwrapURL(wrapped))
assert(unwrapURL("https://cdn.x.com/a.jpg") == "https://cdn.x.com/a.jpg")
assert(trimTail(wrapped + "&quot;") == wrapped, trimTail(wrapped + "&quot;"))

c.dest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wc-\(UUID().uuidString)")

// external assets: local layout must match what wget --force-directories writes,
// and links back to them must be relative and percent-encoded
c.url = "site.com"
let asset = URL(string: "https://cdn.x.com/dir/Rectangle%203.jpg")!
let local = c.localPath(asset)
assert(local.path == c.dest.path + "/cdn.x.com/dir/Rectangle 3.jpg", local.path)
let page = c.dest.appendingPathComponent("site.com/work/slate.html")
assert(c.relativePath(from: page, to: local) == "../../cdn.x.com/dir/Rectangle%203.jpg",
       c.relativePath(from: page, to: local))
let root = c.dest.appendingPathComponent("site.com/index.html")
assert(c.relativePath(from: root, to: local) == "../cdn.x.com/dir/Rectangle%203.jpg",
       c.relativePath(from: root, to: local))
let queried = c.localPath(URL(string: "https://cdn.x.com/f.woff2?v=2")!)
assert(queried.lastPathComponent == "f.woff2?v=2", queried.lastPathComponent)
assert(c.relativePath(from: root, to: queried).hasSuffix("f.woff2%3Fv=2"),
       c.relativePath(from: root, to: queried))
c.writeSitemap()
let xml = try! String(contentsOf: c.dest.appendingPathComponent("sitemap.xml"), encoding: .utf8)
assert(xml.contains("<loc>https://site.com/about</loc>"), xml)
assert(xml.contains("a=1&amp;b=2"), xml)
assert(!xml.contains("/gone"), "failed pages must stay out of the sitemap")
try? FileManager.default.removeItem(at: c.dest)

print("engine checks passed")
