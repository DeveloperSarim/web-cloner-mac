import SwiftUI
import AppKit

let accent = Color(nsColor: NSColor(srgbRed: 0.078, green: 0.455, blue: 0.435, alpha: 1))
let cardBG = Color(nsColor: .controlBackgroundColor)
let hairline = Color(nsColor: .separatorColor)

extension PageState {
    var icon: String {
        switch self {
        case .queued: return "clock"
        case .active: return "arrow.down.circle.fill"
        case .done: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .redirect: return "arrow.turn.down.right"
        }
    }
    var tint: Color {
        switch self {
        case .queued: return .secondary
        case .active: return .blue
        case .done: return accent
        case .failed: return .red
        case .redirect: return .orange
        }
    }
}

struct ContentView: View {
    @StateObject private var c = Cloner()
    @State private var wide = true
    @State private var tab = 0
    @State private var filter: PageState?

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            ScrollView { config.padding(18) }
                .frame(maxHeight: 430)
                .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            results
        }
        .frame(minWidth: 660, minHeight: 580)
        .background(GeometryReader { g in
            Color.clear.onAppear { wide = g.size.width > 840 }
                .onChange(of: g.size.width) { wide = $0 > 840 }
        })
    }

    // MARK: Header

    private var titleBar: some View {
        HStack(spacing: 11) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage(named: "AppIcon") ?? NSImage())
                .resizable().frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("Web Cloner").font(.system(size: 15, weight: .semibold))
                Text("Save, scan or screenshot any website")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            chip(c.wgetPath != nil ? "wget ready" : "wget missing",
                 c.wgetPath != nil ? accent : .orange,
                 c.wgetPath != nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(cardBG)
    }

    // MARK: Config

    private var config: some View {
        VStack(alignment: .leading, spacing: 16) {
            if c.wgetPath == nil { setupCard }
            if wide {
                HStack(alignment: .top, spacing: 16) {
                    sourceCard.frame(width: 400)
                    optionsCard
                }
            } else {
                sourceCard
                optionsCard
            }
            actions
        }
    }

    private var setupCard: some View {
        card("Setup", "wrench.and.screwdriver") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cloning needs wget. This app can install it for you.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button(c.installing ? "Installing…" : "Install wget") { c.installWget() }
                        .buttonStyle(.borderedProminent).tint(accent).disabled(c.installing)
                    if c.installing { ProgressView().controlSize(.small).scaleEffect(0.7) }
                    Button("Check again") { c.recheckWget() }.disabled(c.installing)
                    Spacer()
                }
                Text(c.brewPath == nil
                     ? "Homebrew not found — the button installs Homebrew and wget in Terminal."
                     : "Homebrew found — brew install wget will run.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.07)))
    }

    private var sourceCard: some View {
        card("Website", "link") {
            VStack(alignment: .leading, spacing: 14) {
                labeled("Address") {
                    TextField("example.com", text: $c.url)
                        .textFieldStyle(.roundedBorder).font(.system(size: 13))
                        .frame(maxWidth: 360).disabled(c.running)
                        .onSubmit { if c.canStart { c.start() } }
                }
                labeled("Save to") {
                    HStack(spacing: 8) {
                        Text(c.dest.path.replacingOccurrences(
                            of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                            .font(.system(size: 12)).lineLimit(1).truncationMode(.head)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .frame(maxWidth: 260, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(hairline))
                        Button("Choose…", action: pickFolder).disabled(c.running)
                    }
                }
                labeled("Job") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: $c.mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 330)
                        .disabled(c.running)
                        Text(c.mode.help).font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var optionsCard: some View {
        card("Options", "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 24) {
                    labeled("How deep") {
                        Picker("", selection: $c.depthIndex) {
                            ForEach(Cloner.depths.indices, id: \.self) { Text(Cloner.depths[$0]).tag($0) }
                        }.labelsHidden().frame(width: 140)
                    }
                    labeled("Speed") {
                        Picker("", selection: $c.speed) {
                            ForEach(Speed.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden().frame(width: 120)
                    }
                    if c.mode == .shot {
                        labeled("Width") {
                            Picker("", selection: $c.shotWidth) {
                                Text("1280").tag(1280); Text("1440").tag(1440); Text("1920").tag(1920)
                            }.labelsHidden().frame(width: 100)
                        }
                    }
                }
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 9) {
                    if c.mode == .clone {
                        Toggle("Download images and media", isOn: $c.withAssets)
                        hint("Off = HTML, CSS and JS only. Much faster and smaller.")
                    }
                    Toggle("Create sitemap.xml", isOn: $c.makeSitemap)
                    Toggle("Ignore robots.txt", isOn: $c.ignoreRobots)
                    hint("Only for sites you own or are allowed to copy.")
                    if c.mode == .shot {
                        hint("Up to \(Cloner.shotCap) pages, saved in the screenshots/ folder.")
                    }
                }
                .toggleStyle(.checkbox).font(.system(size: 12)).disabled(c.running)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: { c.running ? c.stop() : c.start() }) {
                Text(c.running ? "Stop" : startLabel)
                    .frame(width: 170).padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent).tint(c.running ? .red : accent)
            .controlSize(.large).keyboardShortcut(.defaultAction)
            .disabled(!c.canStart && !c.running)

            if let out = c.lastOutput, !c.running {
                Button("Open Folder") { NSWorkspace.shared.open(out) }.controlSize(.large)
            }
            if !c.running, c.mode == .clone, let site = c.siteFolder,
               FileManager.default.fileExists(atPath: site.appendingPathComponent("index.html").path) {
                Button("Open Website") {
                    NSWorkspace.shared.open(site.appendingPathComponent("index.html"))
                }.controlSize(.large)
            }
            Spacer()
        }
    }

    private var startLabel: String {
        switch c.mode {
        case .clone: return "Start Cloning"
        case .scan:  return "Start Scan"
        case .shot:  return "Take Screenshots"
        }
    }

    // MARK: Results

    private var results: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Picker("", selection: $tab) {
                    Text("Pages").tag(0); Text("Log").tag(1)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 150)

                if c.running { ProgressView().controlSize(.small).scaleEffect(0.65) }
                Text(c.status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                countChip(.done); countChip(.active); countChip(.failed)
                if c.bytes > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: c.bytes, countStyle: .file))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(cardBG)
            Divider()
            if tab == 0 { pageList } else { logList }
        }
        .frame(maxHeight: .infinity)
    }

    private var shown: [Page] {
        filter == nil ? c.pages : c.pages.filter { $0.state == filter }
    }

    private var pageList: some View {
        ScrollViewReader { sp in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(shown) { p in
                        HStack(spacing: 9) {
                            Image(systemName: p.state.icon).font(.system(size: 11))
                                .foregroundStyle(p.state.tint).frame(width: 14)
                            Text(p.short).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                            Spacer(minLength: 8)
                            if p.state == .failed && !p.note.isEmpty {
                                Text(p.note).font(.system(size: 10)).foregroundStyle(.red).lineLimit(1)
                            } else if p.bytes > 0 {
                                Text(ByteCountFormatter.string(fromByteCount: p.bytes, countStyle: .file))
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(p.state == .active ? accent.opacity(0.07) : .clear)
                        .help(p.id)
                        .id(p.id)
                        Divider().opacity(0.35)
                    }
                    if c.pages.isEmpty {
                        Text("Nothing yet. Enter an address and press start.")
                            .font(.system(size: 12)).foregroundStyle(.secondary).padding(30)
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: c.pages.count) { _ in
                if filter == nil, let last = c.pages.last { sp.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private var logList: some View {
        ScrollViewReader { sp in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(c.log.indices, id: \.self) { i in
                        Text(c.log[i]).font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).id(i)
                    }
                }.padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onChange(of: c.log.count) { _ in
                if let last = c.log.indices.last { sp.scrollTo(last, anchor: .bottom) }
            }
        }
    }

    // MARK: Bits

    private func countChip(_ s: PageState) -> some View {
        let n = c.counts[s] ?? 0
        return Button { filter = (filter == s ? nil : s) } label: {
            HStack(spacing: 4) {
                Image(systemName: s.icon).font(.system(size: 9))
                Text("\(n)").font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(s.tint)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(s.tint.opacity(filter == s ? 0.22 : 0.10)))
        }
        .buttonStyle(.plain).opacity(n == 0 && filter != s ? 0.45 : 1)
        .help("\(s.rawValue) — click to filter")
    }

    private func card<C: View>(_ title: String, _ symbol: String,
                               @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(title).font(.system(size: 10, weight: .semibold)).textCase(.uppercase).kerning(0.5)
            }.foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBG))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(hairline.opacity(0.7)))
    }

    private func labeled<C: View>(_ t: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            content()
        }
    }

    private func hint(_ t: String) -> some View {
        Text(t).font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 20)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func chip(_ text: String, _ color: Color, _ symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private func pickFolder() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true; p.canChooseFiles = false; p.canCreateDirectories = true
        p.directoryURL = c.dest.deletingLastPathComponent()
        p.prompt = "Choose"
        if p.runModal() == .OK, let u = p.url { c.dest = u }
    }
}

@main
struct WebClonerApp: App {
    var body: some Scene {
        Window("Web Cloner", id: "main") { ContentView() }
            .defaultSize(width: 960, height: 820)
    }
}
