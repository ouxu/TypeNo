import AppKit
import Combine
import SwiftUI

enum AppSettings {
    @MainActor
    static func setHotkeyModifier(_ modifier: HotkeyModifier) {
        guard UserDefaults.standard.hotkeyModifier != modifier else { return }
        UserDefaults.standard.hotkeyModifier = modifier
        NotificationCenter.default.post(name: .hotkeyConfigChanged, object: nil)
    }

    @MainActor
    static func setTriggerMode(_ mode: TriggerMode) {
        guard UserDefaults.standard.triggerMode != mode else { return }
        UserDefaults.standard.triggerMode = mode
        NotificationCenter.default.post(name: .hotkeyConfigChanged, object: nil)
    }

    @MainActor
    static func setMicrophoneSelection(_ selection: MicrophoneSelection) {
        guard UserDefaults.standard.microphoneSelection != selection else { return }
        UserDefaults.standard.microphoneSelection = selection
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    init(appState: AppState) {
        let rootView = SettingsView(appState: appState)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = L("TypeNo Settings", "TypeNo 设置")
        window.titleVisibility = .visible
        window.center()
        window.setContentSize(NSSize(width: 560, height: 620))
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var appState: AppState

    @State private var hotkeyModifier = UserDefaults.standard.hotkeyModifier
    @State private var triggerMode = UserDefaults.standard.triggerMode
    @State private var microphoneSelection = UserDefaults.standard.microphoneSelection
    @State private var availableMicrophones: [MicrophoneOption] = []
    @State private var microphoneAuthorized = false
    @State private var accessibilityAuthorized = false
    @State private var coliInstalled = false
    @State private var npmAvailable = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                recordingSection
                phoneSection
                statusSection
                actionsSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            reload()
        }
        .frame(minWidth: 520, minHeight: 580)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TypeNo")
                .font(.system(size: 24, weight: .semibold))
            Text(L("Configure recording, input and integration behavior in one place.", "在一个界面里管理录音、输入和集成相关设置。"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var recordingSection: some View {
        settingsSection(
            title: L("Recording", "录音"),
            description: L("Choose how TypeNo starts listening and which microphone it uses.", "设置 TypeNo 如何开始录音，以及使用哪个麦克风。")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Hotkey", "快捷键"))
                        .font(.system(size: 13, weight: .medium))
                    Picker("", selection: hotkeyBinding) {
                        ForEach(HotkeyModifier.allCases, id: \.self) { modifier in
                            Text(modifier.label).tag(modifier)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("Trigger Mode", "触发方式"))
                        .font(.system(size: 13, weight: .medium))
                    Picker("", selection: triggerBinding) {
                        ForEach(TriggerMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L("Microphone", "麦克风"))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Button(L("Refresh", "刷新")) {
                            reload()
                        }
                        .buttonStyle(.borderless)
                    }

                    Picker("", selection: microphoneBinding) {
                        Text(L("Automatic", "自动")).tag("")
                        ForEach(availableMicrophones, id: \.uniqueID) { microphone in
                            Text(microphone.localizedName).tag(microphone.uniqueID)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    if availableMicrophones.isEmpty {
                        Text(L("No microphones detected right now.", "当前没有检测到麦克风。"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var phoneSection: some View {
        settingsSection(
            title: L("Phone Input", "手机输入"),
            description: L("Turn your phone into a lightweight input surface over your local network.", "把手机作为局域网内的轻量输入端使用。")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    statusPill(
                        title: appState.phoneBridgeRunning ? L("Running", "运行中") : L("Stopped", "未运行"),
                        color: appState.phoneBridgeRunning ? .green : .secondary
                    )
                    Spacer()
                    Button(appState.phoneBridgeRunning ? L("Disable", "关闭") : L("Enable", "开启")) {
                        appState.onPhoneBridgeToggle?()
                    }
                }

                if appState.phoneBridgeRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("Access Link", "访问链接"))
                            .font(.system(size: 13, weight: .medium))
                        HStack {
                            Text(appState.phoneBridgeURL ?? L("Starting...", "启动中..."))
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button(L("Copy Link", "复制链接")) {
                                copyPhoneBridgeURL()
                            }
                            .disabled(appState.phoneBridgeURL == nil)
                        }

                        if let url = appState.phoneBridgeURL,
                           let qrImage = QRCodeGenerator.makeImage(from: url, size: 180) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L("Scan QR Code", "扫码打开"))
                                    .font(.system(size: 13, weight: .medium))
                                Image(nsImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .frame(width: 180, height: 180)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .padding(.top, 6)
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        settingsSection(
            title: L("Status", "状态"),
            description: L("Quick visibility into permissions and the local speech engine.", "快速查看权限和本地语音引擎状态。")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                statusRow(
                    title: L("Microphone Permission", "麦克风权限"),
                    isHealthy: microphoneAuthorized,
                    detail: microphoneAuthorized ? L("Granted", "已授权") : L("Required for recording", "录音需要此权限"),
                    actionTitle: L("Open Settings", "打开设置"),
                    action: { PermissionManager.openPrivacySettings(for: [.microphone]) }
                )

                statusRow(
                    title: L("Accessibility Permission", "辅助功能权限"),
                    isHealthy: accessibilityAuthorized,
                    detail: accessibilityAuthorized ? L("Granted", "已授权") : L("Required for pasting text into apps", "向应用粘贴文本需要此权限"),
                    actionTitle: L("Open Settings", "打开设置"),
                    action: { PermissionManager.openPrivacySettings(for: [.accessibility]) }
                )

                statusRow(
                    title: L("Speech Engine", "语音引擎"),
                    isHealthy: coliInstalled,
                    detail: coliInstalled
                        ? L("Coli is installed and ready", "Coli 已安装并可用")
                        : (npmAvailable
                            ? L("Node.js found. TypeNo can install Coli automatically when needed.", "已检测到 Node.js，需要时 TypeNo 可自动安装 Coli。")
                            : L("Node.js is missing. Install it before first transcription.", "缺少 Node.js，请在首次转写前安装。")),
                    actionTitle: npmAvailable ? nil : L("Open nodejs.org", "打开 nodejs.org"),
                    action: {
                        guard let url = URL(string: "https://nodejs.org") else { return }
                        NSWorkspace.shared.open(url)
                    }
                )
            }
        }
    }

    private var actionsSection: some View {
        settingsSection(
            title: L("Actions", "操作"),
            description: L("Keep a few power actions visible without hunting through the menu bar.", "把常用动作放在界面里，不用再翻菜单。")
        ) {
            HStack(spacing: 12) {
                Button(L("Check for Updates", "检查更新")) {
                    appState.onUpdateRequest?()
                }
                Button(L("Open Privacy Settings", "打开隐私设置")) {
                    PermissionManager.openPrivacySettings(for: [])
                }
                Button(L("Refresh Status", "刷新状态")) {
                    reload()
                }
            }
        }
    }

    private var hotkeyBinding: Binding<HotkeyModifier> {
        Binding(
            get: { hotkeyModifier },
            set: { newValue in
                hotkeyModifier = newValue
                AppSettings.setHotkeyModifier(newValue)
            }
        )
    }

    private var triggerBinding: Binding<TriggerMode> {
        Binding(
            get: { triggerMode },
            set: { newValue in
                triggerMode = newValue
                AppSettings.setTriggerMode(newValue)
            }
        )
    }

    private var microphoneBinding: Binding<String> {
        Binding(
            get: { microphoneSelection.uniqueID ?? "" },
            set: { newValue in
                let selection: MicrophoneSelection = newValue.isEmpty ? .automatic : .specific(newValue)
                microphoneSelection = selection
                AppSettings.setMicrophoneSelection(selection)
            }
        )
    }

    private func reload() {
        hotkeyModifier = UserDefaults.standard.hotkeyModifier
        triggerMode = UserDefaults.standard.triggerMode
        microphoneSelection = UserDefaults.standard.microphoneSelection
        availableMicrophones = MicrophoneManager.availableMicrophones()
        microphoneAuthorized = PermissionManager.microphoneStatus(requestIfNeeded: false) == .authorized
        accessibilityAuthorized = PermissionManager.accessibilityStatus(requestIfNeeded: false)
        coliInstalled = ColiASRService.isInstalled
        npmAvailable = ColiASRService.isNpmAvailable
    }

    private func copyPhoneBridgeURL() {
        guard let url = appState.phoneBridgeURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, description: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    @ViewBuilder
    private func statusRow(title: String, isHealthy: Bool, detail: String, actionTitle: String?, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(isHealthy ? Color.green : Color.orange)
                .frame(width: 9, height: 9)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let actionTitle {
                Button(actionTitle, action: action)
                    .controlSize(.small)
            }
        }
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}
