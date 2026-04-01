import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    phoneInputSection
                    accessibilitySection
                    actionsSection
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: 860, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .onAppear {
            viewModel.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Phone Input", "手机输入"))
                    .font(.system(size: 24, weight: .semibold))

                Text(
                    L(
                        "Keep the local phone page ready, monitor paste permission, and jump into the phone link quickly.",
                        "保持本地手机页面可用，检查粘贴权限，并快速打开手机链接。"
                    )
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var phoneInputSection: some View {
        SettingsSection(
            title: L("Phone Link", "手机链接"),
            subtitle: L("Control the local bridge and open the current page from here.", "控制本地桥接，并在这里打开当前页面。"),
            systemImage: "iphone.gen3"
        ) {
            SettingsRow(
                title: L("Enable Phone Input", "开启手机输入"),
                description: L("Keeps the local web page ready for typing from your phone.", "保持本地网页可用，以便从手机输入文字。")
            ) {
                Toggle("", isOn: Binding(
                    get: { viewModel.phoneInputEnabled },
                    set: { _ in viewModel.togglePhoneInput() }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }

            StatusRow(
                title: L("Status", "状态"),
                summary: viewModel.phoneInputStatusText,
                state: viewModel.phoneInputEnabled ? .ready : .needsAttention
            )

            SettingsRow(
                title: L("Local Link", "本地链接"),
                description: L("Open this same address on a phone that shares your local network.", "在同一局域网的手机上打开这个地址。")
            ) {
                HStack(spacing: 10) {
                    Group {
                        if let phoneInputURL = viewModel.phoneInputURL,
                           let url = URL(string: phoneInputURL) {
                            Link(phoneInputURL, destination: url)
                                .font(.system(size: 11, design: .monospaced))
                                .lineLimit(1)
                        } else {
                            Text(L("Waiting for local address...", "等待本地地址..."))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: 290, alignment: .trailing)

                    Button(L("Open", "打开")) {
                        viewModel.openPhoneInputLink()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.phoneInputURL == nil)

                    Button(L("Copy", "复制")) {
                        viewModel.copyPhoneInputLink()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.phoneInputURL == nil)
                }
            }

            if let phoneInputURL = viewModel.phoneInputURL, viewModel.phoneInputEnabled {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("QR Access", "二维码访问"))
                            .font(.system(size: 13, weight: .medium))
                        Text(L("Scan to open the current phone page immediately.", "扫码即可立即打开当前手机页面。"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    QRCodeCard(urlString: phoneInputURL)
                }
                .padding(.top, 2)
            } else {
                InlineNote(
                    title: L("Link unavailable", "链接不可用"),
                    message: L(
                        "Turn on Phone Input first. If the address still does not appear, use Refresh once your Mac is connected to Wi-Fi or Ethernet.",
                        "请先开启手机输入。如果地址仍未出现，可在 Mac 连上 Wi-Fi 或网线后点击刷新。"
                    )
                )
            }
        }
    }

    private var accessibilitySection: some View {
        SettingsSection(
            title: L("Paste Permission", "粘贴权限"),
            subtitle: L("Accessibility is optional, but it unlocks direct paste into other Mac apps.", "辅助功能权限并非必需，但开启后可直接粘贴到其他 Mac 应用。"),
            systemImage: "hand.raised.circle"
        ) {
            StatusRow(
                title: L("Accessibility", "辅助功能"),
                summary: viewModel.accessibilitySummary,
                state: viewModel.accessibilityEnabled ? .ready : .needsAttention,
                actionTitle: L("Open Settings", "打开设置"),
                action: {
                    viewModel.openAccessibilitySettings()
                }
            )

            InlineNote(
                title: L("If macOS seems stuck", "如果 macOS 看起来没有生效"),
                message: L(
                    "Remove TypeNo from System Settings > Privacy & Security > Accessibility, then add it again from /Applications.",
                    "如果在“系统设置 > 隐私与安全性 > 辅助功能”里开启后仍无效，请先移除 TypeNo，再从 /Applications 重新添加。"
                )
            )
        }
    }

    private var actionsSection: some View {
        SettingsSection(
            title: L("Actions", "操作"),
            subtitle: L("Refresh local state or check for a newer build when needed.", "需要时可刷新本地状态或检查新版本。"),
            systemImage: "gearshape.2"
        ) {
            HStack(spacing: 10) {
                Button(L("Refresh", "刷新")) {
                    viewModel.refresh()
                }
                .buttonStyle(.borderedProminent)

                Button(L("Check for Updates", "检查更新")) {
                    viewModel.checkForUpdates()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
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
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(.top, 10)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
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
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
        )
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
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

private enum StatusRowState {
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

private struct StatusRow: View {
    let title: String
    let summary: String
    let state: StatusRowState
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
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
    let state: StatusRowState

    var body: some View {
        Label(state.label, systemImage: state.symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(state.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(state.color.opacity(0.12), in: Capsule())
    }
}

private struct InlineNote: View {
    let title: String
    let message: String

    var body: some View {
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
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
        )
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
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
        )
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
