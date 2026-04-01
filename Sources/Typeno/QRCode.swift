import AppKit
import CoreImage
import SwiftUI

enum QRCodeGenerator {
    static func makeImage(from string: String, size: CGFloat) -> NSImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let scaleX = size / outputImage.extent.width
        let scaleY = size / outputImage.extent.height
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
        image.isTemplate = false
        return image
    }
}

@MainActor
final class PhoneBridgeQRCodeWindowController: NSWindowController {
    private let hostingController: NSHostingController<PhoneBridgeQRCodeView>

    init() {
        let rootView = PhoneBridgeQRCodeView(url: nil)
        hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = L("Phone Input QR Code", "手机输入二维码")
        window.titleVisibility = .visible
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(url: String?) {
        hostingController.rootView = PhoneBridgeQRCodeView(url: url)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}

struct PhoneBridgeQRCodeView: View {
    let url: String?

    var body: some View {
        VStack(spacing: 16) {
            Text(L("Scan with your phone", "用手机扫码"))
                .font(.system(size: 18, weight: .semibold))

            if let url,
               let qrImage = QRCodeGenerator.makeImage(from: url, size: 220) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 220, height: 220)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(url)
                    .font(.system(size: 12, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)

                Button(L("Copy Link", "复制链接")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url, forType: .string)
                }
            } else {
                Spacer()
                ProgressView()
                Text(L("Phone input is starting...", "手机输入正在启动..."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 320, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
