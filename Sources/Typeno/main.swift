import AppKit
import ApplicationServices
import Combine
import FlyingFox
import Foundation
import SwiftUI

// MARK: - Localization Helper

func L(_ en: String, _ zh: String) -> String {
    Locale.preferredLanguages.first.map { $0.hasPrefix("zh") } == true ? zh : en
}

// MARK: - Persistence

extension UserDefaults {
    private static let phoneBridgeEnabledKey = "ai.marswave.typeno.phoneBridgeEnabled"

    var phoneBridgeEnabled: Bool {
        get {
            if object(forKey: Self.phoneBridgeEnabledKey) == nil {
                return true
            }
            return bool(forKey: Self.phoneBridgeEnabledKey)
        }
        set { set(newValue, forKey: Self.phoneBridgeEnabledKey) }
    }
}

// MARK: - Model

enum NoticeStyle: Equatable {
    case info
    case success
    case warning
}

struct OverlayNotice: Equatable {
    let title: String
    let message: String
    let systemImage: String
    let style: NoticeStyle
}

enum AppPhase: Equatable {
    case idle
    case notice(OverlayNotice)
    case updating(String)
    case error(String)
}

enum TypeNoError: LocalizedError {
    case phoneBridgeUnavailable

    var errorDescription: String? {
        switch self {
        case .phoneBridgeUnavailable:
            return L(
                "Phone input is enabled, but no local network address is available yet.",
                "手机输入已开启，但暂时还没有可用的本地网络地址。"
            )
        }
    }
}

// MARK: - Permissions

enum AccessibilityPermissionManager {
    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestIfNeeded() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    @Published var phase: AppPhase = .idle
    @Published var phoneBridgeRunning = false
    @Published var phoneBridgeURL: String?

    var onOverlayRequest: ((Bool) -> Void)?
    var onPhoneBridgeToggle: (() -> Void)?
    var onPhoneBridgeRefresh: (() -> Void)?
    var onUpdateRequest: (() -> Void)?

    func receiveFromPhone(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let targetApp = NSWorkspace.shared.frontmostApplication
        copyToClipboard(trimmed)

        if AccessibilityPermissionManager.isGranted(), let targetApp {
            targetApp.activate()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                Self.postPasteShortcut()
            }

            showNotice(
                title: L("Inserted from Phone", "已从手机插入"),
                message: trimmed,
                systemImage: "iphone.and.arrow.forward",
                style: .success
            )
        } else {
            showNotice(
                title: L("Copied from Phone", "已从手机复制"),
                message: L(
                    "Accessibility is off, so the text was copied to your clipboard instead.",
                    "由于未开启辅助功能权限，文本已复制到剪贴板。"
                ),
                systemImage: "doc.on.clipboard",
                style: .warning
            )
        }
    }

    func showPhoneBridgeState(enabled: Bool, url: String?) {
        phoneBridgeRunning = enabled
        phoneBridgeURL = url
    }

    func showError(_ message: String) {
        phase = .error(message)
        onOverlayRequest?(true)
    }

    func showNotice(title: String, message: String, systemImage: String, style: NoticeStyle) {
        let notice = OverlayNotice(title: title, message: message, systemImage: systemImage, style: style)
        phase = .notice(notice)
        onOverlayRequest?(true)
        dismiss(phase: .notice(notice), after: 2.6)
    }

    func dismissOverlay() {
        phase = .idle
        onOverlayRequest?(false)
    }

    private func dismiss(phase expectedPhase: AppPhase, after seconds: Double) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard self.phase == expectedPhase else { return }
            self.dismissOverlay()
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func postPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    private var statusItemController: StatusItemController?
    private var overlayController: OverlayPanelController?
    private let updateService = UpdateService()
    private var phoneBridge: PhoneBridgeServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayController = OverlayPanelController(appState: appState)
        statusItemController = StatusItemController(appState: appState)

        appState.onOverlayRequest = { [weak self] visible in
            visible ? self?.overlayController?.show() : self?.overlayController?.hide()
        }
        appState.onPhoneBridgeToggle = { [weak self] in
            self?.togglePhoneBridge()
        }
        appState.onPhoneBridgeRefresh = { [weak self] in
            self?.refreshPhoneBridgeState()
        }
        appState.onUpdateRequest = { [weak self] in
            self?.performUpdate()
        }

        let bridge = PhoneBridgeServer()
        bridge.onTextReceived = { [weak self] text in
            Task { @MainActor in
                self?.appState.receiveFromPhone(text)
            }
        }
        phoneBridge = bridge

        if UserDefaults.standard.phoneBridgeEnabled {
            bridge.start()
        }
        refreshPhoneBridgeState()

        Task {
            if let release = await updateService.checkForUpdate() {
                statusItemController?.setUpdateAvailable(release.version)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        phoneBridge?.stop()
    }

    private func togglePhoneBridge() {
        guard let phoneBridge else { return }

        if phoneBridge.isRunning {
            phoneBridge.stop()
            UserDefaults.standard.phoneBridgeEnabled = false
            refreshPhoneBridgeState()
            appState.showNotice(
                title: L("Phone Input Disabled", "手机输入已关闭"),
                message: L("The local phone page is no longer accepting input.", "本地手机输入页面已停止接收内容。"),
                systemImage: "iphone.slash",
                style: .info
            )
        } else {
            phoneBridge.start()
            UserDefaults.standard.phoneBridgeEnabled = true
            refreshPhoneBridgeState()

            if let url = phoneBridge.localURL {
                appState.showNotice(
                    title: L("Phone Input Enabled", "手机输入已开启"),
                    message: url,
                    systemImage: "iphone",
                    style: .success
                )
            } else {
                appState.showError(TypeNoError.phoneBridgeUnavailable.localizedDescription)
            }
        }
    }

    private func refreshPhoneBridgeState() {
        guard let phoneBridge else { return }
        appState.showPhoneBridgeState(enabled: phoneBridge.isRunning, url: phoneBridge.localURL)
    }

    private func performUpdate() {
        Task {
            appState.phase = .updating(L("Checking for updates...", "检查更新..."))
            appState.onOverlayRequest?(true)

            switch await updateService.checkForUpdateDetailed() {
            case .upToDate:
                appState.showNotice(
                    title: L("Already Up to Date", "已经是最新版本"),
                    message: L("You are running the latest TypeNo build.", "当前运行的已经是最新 TypeNo 版本。"),
                    systemImage: "checkmark.circle",
                    style: .success
                )

            case .rateLimited:
                appState.showError(L("GitHub rate limit reached. Try again later.", "GitHub 请求受限，请稍后再试。"))

            case .failed:
                appState.showError(L("Could not check for updates.", "无法检查更新。"))

            case .updateAvailable(let release):
                appState.showNotice(
                    title: L("Update Available", "发现新版本"),
                    message: "v\(release.version)",
                    systemImage: "arrow.down.circle",
                    style: .info
                )
                NSWorkspace.shared.open(URL(string: "https://github.com/\(UpdateService.repoOwner)/\(UpdateService.repoName)/releases/latest")!)
            }
        }
    }
}

// MARK: - Status Item

@MainActor
final class StatusItemController: NSObject {
    private enum MenuTag {
        static let phoneBridgeToggle = 100
        static let phoneBridgeURL = 110
        static let phoneBridgeOpen = 120
        static let phoneBridgeCopy = 130
        static let accessibility = 200
        static let update = 300
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: 28)
    private weak var appState: AppState?
    private var phaseCancellable: AnyCancellable?
    private var bridgeCancellable: AnyCancellable?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        configureMenu()
        updateStatusIcon(for: appState.phase)

        phaseCancellable = appState.$phase.sink { [weak self] phase in
            self?.updateStatusIcon(for: phase)
        }
        bridgeCancellable = appState.$phoneBridgeRunning.sink { [weak self] _ in
            self?.refreshPhoneBridgeMenu()
        }
    }

    func setUpdateAvailable(_ version: String) {
        statusItem.menu?.item(withTag: MenuTag.update)?.title = L(
            "Update Available (v\(version))",
            "有新版本 (v\(version))"
        )
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let aboutItem = NSMenuItem(title: "TypeNo  v\(version)", action: nil, keyEquivalent: "")
        aboutItem.isEnabled = false
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "", action: #selector(togglePhoneBridge), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.tag = MenuTag.phoneBridgeToggle
        menu.addItem(toggleItem)

        let urlItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        urlItem.tag = MenuTag.phoneBridgeURL
        urlItem.isEnabled = false
        menu.addItem(urlItem)

        let openItem = NSMenuItem(title: L("Open Phone Page", "打开手机页面"), action: #selector(openPhoneBridgeURL), keyEquivalent: "")
        openItem.target = self
        openItem.tag = MenuTag.phoneBridgeOpen
        menu.addItem(openItem)

        let copyItem = NSMenuItem(title: L("Copy Link", "复制链接"), action: #selector(copyPhoneBridgeURL), keyEquivalent: "")
        copyItem.target = self
        copyItem.tag = MenuTag.phoneBridgeCopy
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        let accessibilityItem = NSMenuItem(
            title: L("Enable Paste Permission", "开启粘贴权限"),
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.tag = MenuTag.accessibility
        menu.addItem(accessibilityItem)

        let updateItem = NSMenuItem(title: L("Check for Updates...", "检查更新..."), action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        updateItem.tag = MenuTag.update
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L("Quit TypeNo", "退出 TypeNo"), action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
        refreshPhoneBridgeMenu()
    }

    private func makeStatusBarImage(systemName: String) -> NSImage? {
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: "TypeNo")
        image?.isTemplate = true
        return image
    }

    private func updateStatusIcon(for phase: AppPhase) {
        guard let button = statusItem.button else { return }

        switch phase {
        case .error:
            button.image = nil
            button.imagePosition = .noImage
            button.title = "!"
        case .updating:
            button.image = nil
            button.imagePosition = .noImage
            button.title = "↓"
        default:
            let running = appState?.phoneBridgeRunning ?? false
            button.image = makeStatusBarImage(systemName: running ? "iphone" : "iphone.slash")
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    private func refreshPhoneBridgeMenu() {
        guard let menu = statusItem.menu,
              let toggleItem = menu.item(withTag: MenuTag.phoneBridgeToggle),
              let urlItem = menu.item(withTag: MenuTag.phoneBridgeURL),
              let openItem = menu.item(withTag: MenuTag.phoneBridgeOpen),
              let copyItem = menu.item(withTag: MenuTag.phoneBridgeCopy) else {
            return
        }

        let running = appState?.phoneBridgeRunning ?? false
        let url = appState?.phoneBridgeURL

        toggleItem.title = running ? L("Disable Phone Input", "关闭手机输入") : L("Enable Phone Input", "开启手机输入")
        toggleItem.state = running ? .on : .off

        urlItem.title = url ?? L("No local URL available yet", "暂时没有可用的本地地址")
        openItem.isHidden = !running || url == nil
        copyItem.isHidden = !running || url == nil
    }

    @objc private func togglePhoneBridge() {
        appState?.onPhoneBridgeToggle?()
    }

    @objc private func openPhoneBridgeURL() {
        guard let urlString = appState?.phoneBridgeURL, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func copyPhoneBridgeURL() {
        guard let url = appState?.phoneBridgeURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermissionManager.requestIfNeeded()
        AccessibilityPermissionManager.openSettings()
    }

    @objc private func checkForUpdates() {
        appState?.onUpdateRequest?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusItemController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        appState?.onPhoneBridgeRefresh?()
        refreshPhoneBridgeMenu()
        updateStatusIcon(for: appState?.phase ?? .idle)
    }
}

// MARK: - Overlay Panel

@MainActor
final class OverlayPanelController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<OverlayView>
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        hostingView = NSHostingView(rootView: OverlayView(appState: appState))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
    }

    func show() {
        hostingView.invalidateIntrinsicContentSize()
        let idealSize = hostingView.fittingSize
        let width = max(idealSize.width, 320)
        let height = max(idealSize.height, 72)

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let x = frame.maxX - width - 18
            let y = frame.maxY - height - 18
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        } else {
            panel.setContentSize(NSSize(width: width, height: height))
        }

        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

// MARK: - Overlay View

struct OverlayView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            switch appState.phase {
            case .idle:
                EmptyView()
            case .notice(let notice):
                noticeView(notice)
            case .updating(let message):
                statusView(
                    title: L("TypeNo", "TypeNo"),
                    message: message,
                    systemImage: "arrow.triangle.2.circlepath"
                )
            case .error(let message):
                statusView(
                    title: L("Something Went Wrong", "发生错误"),
                    message: message,
                    systemImage: "exclamationmark.triangle.fill"
                )
            }
        }
        .fixedSize()
    }

    private func noticeView(_ notice: OverlayNotice) -> some View {
        statusView(title: notice.title, message: notice.message, systemImage: notice.systemImage)
    }

    private func statusView(title: String, message: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)
                .foregroundStyle(.white.opacity(0.92))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 380, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.28), radius: 16, y: 6)
    }
}

// MARK: - Update Service

final class UpdateService: @unchecked Sendable {
    static let repoOwner = "marswaveai"
    static let repoName = "TypeNo"
    static let assetName = "TypeNo.app.zip"

    struct ReleaseInfo {
        let version: String
        let downloadURL: URL
    }

    enum CheckResult {
        case updateAvailable(ReleaseInfo)
        case upToDate
        case rateLimited
        case failed
    }

    func checkForUpdate() async -> ReleaseInfo? {
        switch await checkForUpdateDetailed() {
        case .updateAvailable(let info): return info
        default: return nil
        }
    }

    func checkForUpdateDetailed() async -> CheckResult {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest") else {
            return .failed
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("TypeNo/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failed
            }

            if json["message"] as? String != nil && json["tag_name"] == nil {
                return .rateLimited
            }

            guard let tagName = json["tag_name"] as? String,
                  let assets = json["assets"] as? [[String: Any]] else {
                return .failed
            }

            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

            guard Self.isNewer(remote: remoteVersion, current: currentVersion) else {
                return .upToDate
            }

            guard let asset = assets.first(where: { ($0["name"] as? String) == Self.assetName }),
                  let downloadURLString = asset["browser_download_url"] as? String,
                  let downloadURL = URL(string: downloadURLString) else {
                return .failed
            }

            return .updateAvailable(ReleaseInfo(version: remoteVersion, downloadURL: downloadURL))
        } catch {
            return .failed
        }
    }

    private static func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }

        return false
    }
}

// MARK: - Phone Bridge Server

private func loadPhoneInputHTML() -> String {
    guard let url = Bundle.module.url(forResource: "phone-input", withExtension: "html"),
          let html = try? String(contentsOf: url, encoding: .utf8) else {
        return "<h1 style='font-family:sans-serif;padding:2em'>Error: phone-input.html not found in bundle</h1>"
    }
    return html
}

struct HTMLPageHandler: HTTPHandler, Sendable {
    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(
            statusCode: .ok,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: Data(loadPhoneInputHTML().utf8)
        )
    }
}

struct PhoneWSHandler: WSMessageHandler, Sendable {
    let continuation: AsyncStream<String>.Continuation

    func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        let continuation = continuation
        return AsyncStream { _ in
            Task {
                for await message in client {
                    if case .text(let text) = message {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            continuation.yield(trimmed)
                        }
                    }
                }
            }
        }
    }
}

@MainActor
final class PhoneBridgeServer {
    var onTextReceived: ((String) -> Void)?

    let port: UInt16 = 7878

    private(set) var isRunning = false
    private var serverTask: Task<Void, Never>?
    private let continuation: AsyncStream<String>.Continuation
    private let textStream: AsyncStream<String>

    init() {
        let (stream, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .bufferingNewest(20))
        self.textStream = stream
        self.continuation = continuation
        startTextListener()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let continuation = continuation
        let port = port
        serverTask = Task.detached(priority: .utility) {
            do {
                let server = HTTPServer(port: port)
                await server.appendRoute("GET /", to: HTMLPageHandler())
                await server.appendRoute("GET /ws", to: .webSocket(PhoneWSHandler(continuation: continuation)))
                try await server.run()
            } catch {
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        serverTask?.cancel()
        serverTask = nil
    }

    var localURL: String? {
        guard isRunning, let ip = Self.localIPAddress() else { return nil }
        return "http://\(ip):\(port)"
    }

    private func startTextListener() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for await text in self.textStream {
                self.onTextReceived?(text)
            }
        }
    }

    private static func localIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let addr = ptr {
            defer { ptr = addr.pointee.ifa_next }
            guard let sa = addr.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: addr.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                sa,
                socklen_t(MemoryLayout<sockaddr_in>.size),
                &hostname,
                socklen_t(NI_MAXHOST),
                nil,
                0,
                NI_NUMERICHOST
            )

            let ipBytes = hostname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            let ip = String(bytes: ipBytes, encoding: .utf8) ?? ""
            if !ip.isEmpty && ip != "0.0.0.0" {
                return ip
            }
        }

        return nil
    }
}

// MARK: - Entry Point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
