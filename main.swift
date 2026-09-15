import AppKit

// MARK: - 数据采集

struct DevServer {
    let port: String
    let pid: String
    let project: String
}

func shell(_ path: String, _ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(data: data, encoding: .utf8) ?? ""
}

let matchNames: Set<String> = ["node", "bun", "deno", "Python", "ruby", "php", "serve", "http-serv"]

func commandMatches(_ name: String) -> Bool {
    matchNames.contains(name) || name.hasPrefix("python")
}

func collectServers() -> [DevServer] {
    let out = shell("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"])
    var seen = Set<String>()
    var pidPorts: [(pid: String, port: String)] = []
    for line in out.split(separator: "\n").dropFirst() {
        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 9, commandMatches(String(parts[0])) else { continue }
        guard let portSub = parts[8].split(separator: ":").last,
              portSub.allSatisfy({ $0.isNumber }) else { continue }
        let pid = String(parts[1]), port = String(portSub)
        if seen.insert("\(pid):\(port)").inserted {
            pidPorts.append((pid, port))
        }
    }
    var servers: [DevServer] = []
    for (pid, port) in pidPorts {
        var cwd = "?"
        for l in shell("/usr/sbin/lsof", ["-a", "-p", pid, "-d", "cwd", "-Fn"]).split(separator: "\n") {
            if l.hasPrefix("n/") { cwd = String(l.dropFirst()); break }
        }
        let project = cwd.split(separator: "/").last.map(String.init) ?? cwd
        servers.append(DevServer(port: port, pid: pid, project: project))
    }
    return servers.sorted { (Int($0.port) ?? 0) < (Int($1.port) ?? 0) }
}

// MARK: - UI

final class KillButton: NSButton {
    var pid: String = ""
}

// 翻转坐标系, 让滚动内容从顶部开始排 (默认原点在左下, 内容不足时会上方留白)
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var refreshButton: NSButton!
    let rowsStack = NSStackView()
    let countLabel = NSTextField(labelWithString: "")

    static let orange = NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.46, alpha: 1)
    static let dim = NSColor.secondaryLabelColor

    func applicationDidFinishLaunching(_ notification: Notification) {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 180),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        w.title = "Dev Server 监视器"
        w.level = .floating                       // 始终置顶
        w.appearance = NSAppearance(named: .darkAqua)
        w.minSize = NSSize(width: 280, height: 90)
        w.center()
        window = w

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 5
        root.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 8, right: 8)
        root.translatesAutoresizingMaskIntoConstraints = false

        // 顶部栏
        let header = NSStackView()
        header.orientation = .horizontal
        header.spacing = 6
        header.alignment = .centerY
        let titleLabel = NSTextField(labelWithString: "Dev Server")
        titleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        countLabel.font = .systemFont(ofSize: 10)
        countLabel.textColor = AppDelegate.dim
        refreshButton = makeButton("刷新", color: NSColor(calibratedRed: 0.29, green: 0.30, blue: 0.33, alpha: 1),
                                   action: #selector(refresh))
        let killAllButton = makeButton("全部关闭", color: .systemRed, action: #selector(killAll))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        [titleLabel, countLabel, spacer, refreshButton, killAllButton].forEach { header.addArrangedSubview($0) }

        let sep = NSBox()
        sep.boxType = .separator

        // 列表区(可滚动, 内容从顶部排)
        rowsStack.orientation = .vertical
        rowsStack.spacing = 6
        rowsStack.alignment = .leading
        rowsStack.translatesAutoresizingMaskIntoConstraints = false

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            rowsStack.topAnchor.constraint(equalTo: doc.topAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
        ])

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = doc
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        root.addArrangedSubview(header)
        root.addArrangedSubview(sep)
        root.addArrangedSubview(scroll)
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true

        w.contentView = root
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
            root.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            root.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor),
        ])
        w.makeKeyAndOrderFront(nil)
        refresh()
    }

    func styleButton(_ b: NSButton, _ title: String, _ color: NSColor,
                     size: NSControl.ControlSize = .small) {
        b.bezelStyle = .rounded
        b.bezelColor = color
        b.controlSize = size
        b.attributedTitle = NSAttributedString(string: title, attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: size == .mini ? 9 : 10, weight: .medium),
        ])
        b.setContentHuggingPriority(.required, for: .horizontal)
    }

    func makeButton(_ title: String, color: NSColor, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        styleButton(b, title, color)
        return b
    }

    func makeRow(_ s: DevServer) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        row.edgeInsets = NSEdgeInsets(top: 3, left: 2, bottom: 3, right: 2)

        let portLabel = NSTextField(labelWithString: ":\(s.port)")
        portLabel.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        portLabel.textColor = AppDelegate.orange
        portLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let projectLabel = NSTextField(labelWithString: s.project)
        projectLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        projectLabel.lineBreakMode = .byTruncatingTail

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)

        let closeBtn = KillButton(title: "关闭", target: self, action: #selector(killOne(_:)))
        closeBtn.pid = s.pid
        styleButton(closeBtn, "关闭", .systemRed, size: .mini)

        [portLabel, projectLabel, spacer, closeBtn].forEach { row.addArrangedSubview($0) }
        return row
    }

    func render(_ servers: [DevServer]) {
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        countLabel.stringValue = "\(servers.count) 个运行中"
        if servers.isEmpty {
            let empty = NSTextField(labelWithString: "没有正在运行的 dev server")
            empty.textColor = AppDelegate.dim
            empty.font = .systemFont(ofSize: 11)
            rowsStack.addArrangedSubview(empty)
        } else {
            for s in servers {
                let row = makeRow(s)
                row.translatesAutoresizingMaskIntoConstraints = false
                rowsStack.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: rowsStack.widthAnchor).isActive = true
            }
        }
    }

    @objc func refresh() {
        refreshButton.isEnabled = false
        DispatchQueue.global(qos: .userInitiated).async {
            let servers = collectServers()
            DispatchQueue.main.async {
                self.render(servers)
                self.refreshButton.isEnabled = true
            }
        }
    }

    @objc func killOne(_ sender: KillButton) {
        DispatchQueue.global().async {
            _ = shell("/bin/kill", [sender.pid])
            DispatchQueue.main.async { self.refresh() }
        }
    }

    @objc func killAll() {
        DispatchQueue.global().async {
            for s in collectServers() { _ = shell("/bin/kill", [s.pid]) }
            DispatchQueue.main.async { self.refresh() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
