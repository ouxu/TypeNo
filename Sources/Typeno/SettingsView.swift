import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                recordingSection
                phoneInputSection
                environmentSection
                actionsSection
            }
            .padding(24)
        }
        .frame(minWidth: 720, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Settings", "设置"))
                    .font(.system(size: 24, weight: .semibold))

                Text(L("Recording, phone input, and environment checks for TypeNo.", "TypeNo 的录音、手机输入与运行环境设置。"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var recordingSection: some View {
        SettingsSection(
            title: L("Recording", "录音"),
            subtitle: L("Choose how TypeNo starts recording and which microphone it listens to.", "选择 TypeNo 如何开始录音，以及使用哪个麦克风。"),
            systemImage: "waveform.circle"
        ) {
            SettingsRow(
                title: L("Hotkey", "快捷键"),
                description: L("The modifier key that toggles recording from anywhere.", "在任何应用里触发录音的修饰键。")
            ) {
                Picker("", selection: Binding(
                    get: { viewModel.hotkeyModifier },
                    set: { viewModel.setHotkeyModifier($0) }
                )) {
                    ForEach(HotkeyModifier.allCases, id: \.self) { modifier in
                        Text(modifier.label).tag(modifier)
                    }
                }
                .labelsHidden()
                .frame(width: 250)
            }

            SettingsRow(
                title: L("Trigger Mode", "触发方式"),
                description: L("Use a single tap for speed or double tap to avoid accidental triggers.", "单击更快，双击更适合避免误触。")
            ) {
                Picker("", selection: Binding(
                    get: { viewModel.triggerMode },
                    set: { viewModel.setTriggerMode($0) }
                )) {
                    ForEach(TriggerMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)
            }

            SettingsRow(
                title: L("Microphone", "麦克风"),
                description: L("Automatic follows the macOS default input device.", "自动将跟随 macOS 默认输入设备。")
            ) {
                Picker("", selection: Binding(
                    get: { viewModel.selectedMicrophoneID },
                    set: { viewModel.setMicrophoneSelectionID($0) }
                )) {
                    Text(L("Automatic", "自动")).tag(SettingsViewModel.automaticMicrophoneID)
                    ForEach(viewModel.microphones, id: \.uniqueID) { microphone in
                        Text(microphone.localizedName).tag(microphone.uniqueID)
                    }
                }
                .labelsHidden()
                .frame(width: 300)
            }

            if viewModel.selectedMicrophoneNeedsAttention {
                attentionNote(
                    title: L("Microphone needs attention", "麦克风需要处理"),
                    message: L("The selected microphone is unavailable. Switch back to Automatic or choose another input.", "当前所选麦克风不可用。请切回自动或选择其他输入设备。")
                )
            }
        }
    }

    private var phoneInputSection: some View {
        SettingsSection(
            title: L("Phone Input", "手机输入"),
            subtitle: L("Use your phone as a lightweight text input surface on the same network.", "在同一网络下把手机当作轻量文字输入面板。"),
            systemImage: "iphone.gen3"
        ) {
            SettingsRow(
                title: L("Enable Phone Input", "开启手机输入"),
                description: L("Starts the local web bridge and keeps the current device link available.", "启动本地网页桥接，并提供当前设备访问链接。")
            ) {
                Toggle("", isOn: Binding(
                    get: { viewModel.phoneInputEnabled },
                    set: { _ in viewModel.togglePhoneInput() }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }

            if let phoneURL = viewModel.phoneInputURL, viewModel.phoneInputEnabled {
                SettingsRow(
                    title: L("Link", "链接"),
                    description: L("Open this URL from a phone on the same local network.", "在同一局域网内，用手机打开这个链接。")
                ) {
                    HStack(spacing: 10) {
                        if let url = URL(string: phoneURL) {
                            Link(phoneURL, destination: url)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1)
                        } else {
                            Text(phoneURL)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Button(L("Copy", "复制")) {
                            viewModel.copyPhoneInputLink()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("QR Code", "二维码"))
                            .font(.system(size: 13, weight: .medium))
                        Text(L("Scan to open the same link quickly on your phone.", "扫描后可在手机上快速打开同一链接。"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    QRCodeCard(urlString: phoneURL)
                }
                .padding(.top, 2)
            } else {
                attentionNote(
                    title: L("Bridge offline", "桥接未开启"),
                    message: L("Enable Phone Input to generate a local link and QR code.", "开启手机输入后才会生成本地链接和二维码。")
                )
            }
        }
    }

    private var environmentSection: some View {
        SettingsSection(
            title: L("Status & Environment", "状态与环境"),
            subtitle: L("Quick checks for permissions and the local transcription stack.", "快速检查权限与本地转录环境。"),
            systemImage: "checklist"
        ) {
            EnvironmentRow(
                title: L("Microphone Permission", "麦克风权限"),
                summary: viewModel.microphonePermissionStatus == .authorized
                    ? L("Granted", "已授权")
                    : L("Required before recording can start.", "开始录音前必须授权。"),
                state: viewModel.microphonePermissionStatus == .authorized ? .ready : .needsAttention,
                actionTitle: viewModel.microphonePermissionStatus == .authorized ? nil : L("Open", "打开"),
                action: viewModel.microphonePermissionStatus == .authorized ? nil : {
                    viewModel.openPermissionSettings(for: .microphone)
                }
            )

            EnvironmentRow(
                title: L("Accessibility Permission", "辅助功能权限"),
                summary: viewModel.accessibilityEnabled
                    ? L("Granted", "已授权")
                    : L("Required so TypeNo can paste text into other apps.", "需要此权限才能把文字输入到其他应用。"),
                state: viewModel.accessibilityEnabled ? .ready : .needsAttention,
                actionTitle: viewModel.accessibilityEnabled ? nil : L("Open", "打开"),
                action: viewModel.accessibilityEnabled ? nil : {
                    viewModel.openPermissionSettings(for: .accessibility)
                }
            )

            EnvironmentRow(
                title: L("Speech Engine", "语音引擎"),
                summary: viewModel.speechEngineSummary,
                state: viewModel.speechEngineReady ? .ready : .needsAttention
            )

            EnvironmentRow(
                title: L("Node.js / npm", "Node.js / npm"),
                summary: viewModel.nodeInstalled
                    ? L("Available for Coli installation and updates.", "可用于安装和更新 Coli。")
                    : L("Missing. Install Node.js to let TypeNo prepare Coli automatically.", "缺失。请先安装 Node.js，TypeNo 才能自动准备 Coli。"),
                state: viewModel.nodeInstalled ? .ready : .needsAttention
            )

            EnvironmentRow(
                title: L("Coli", "Coli"),
                summary: viewModel.coliInstalled
                    ? L("Installed and ready for transcription.", "已安装，可用于转录。")
                    : L("Not installed yet. TypeNo will try to set it up when Node.js is available.", "尚未安装。Node.js 可用后，TypeNo 会尝试自动配置。"),
                state: viewModel.coliInstalled ? .ready : .needsAttention
            )
        }
    }

    private var actionsSection: some View {
        SettingsSection(
            title: L("Actions", "操作"),
            subtitle: L("Manual refresh and system shortcuts when you need them.", "需要时可手动刷新状态并打开系统入口。"),
            systemImage: "gearshape.2"
        ) {
            HStack(spacing: 10) {
                Button(L("Check for Updates", "检查更新")) {
                    viewModel.checkForUpdates()
                }
                .buttonStyle(.borderedProminent)

                Button(L("Open Privacy Settings", "打开隐私设置")) {
                    viewModel.openPrivacySettings()
                }
                .buttonStyle(.bordered)

                Button(L("Refresh Status", "刷新状态")) {
                    viewModel.refreshStatus()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
    }

    private func attentionNote(title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 13))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.top, 6)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    let description: String
    let content: Content

    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
    }
}

private enum EnvironmentRowState {
    case ready
    case needsAttention

    var label: String {
        switch self {
        case .ready:
            L("Ready", "已就绪")
        case .needsAttention:
            L("Needs Attention", "需处理")
        }
    }

    var color: Color {
        switch self {
        case .ready:
            .green
        case .needsAttention:
            .orange
        }
    }

    var symbol: String {
        switch self {
        case .ready:
            "checkmark.circle.fill"
        case .needsAttention:
            "exclamationmark.circle.fill"
        }
    }
}

private struct EnvironmentRow: View {
    let title: String
    let summary: String
    let state: EnvironmentRowState
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                StatusBadge(state: state)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }
}

private struct StatusBadge: View {
    let state: EnvironmentRowState

    var body: some View {
        Label(state.label, systemImage: state.symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(state.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(state.color.opacity(0.12), in: Capsule())
    }
}

private struct QRCodeCard: View {
    let urlString: String

    var body: some View {
        VStack(spacing: 8) {
            if let image = QRCodeRenderer.image(for: urlString) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 132, height: 132)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 132, height: 132)
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    }
            }

            Text(L("Scan on phone", "手机扫码"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum QRCodeRenderer {
    private static let context = CIContext()

    static func image(for string: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: 132, height: 132))
    }
}
