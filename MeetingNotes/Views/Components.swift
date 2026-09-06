import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Color helper

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}

// MARK: - Industry design system

/// Tokens for the "Industry" look: a technical blueprint identity — steel-blue
/// accent, Barlow / Barlow Condensed type, squared corners, hairline rules.
enum Theme {
    static let bg = Color(hex: 0xF2F2F3)
    static let surface = Color(hex: 0xE9E9EA)
    static let text = Color(hex: 0x1D1F20)
    static let accent = Color(hex: 0x5980A6)
    static let accent100 = Color(hex: 0xEEF6FF)
    static let accent200 = Color(hex: 0xD6EBFF)
    static let accent300 = Color(hex: 0xB5D9FD)
    static let accent600 = Color(hex: 0x597EA3)
    static let accent700 = Color(hex: 0x416180)
    static let accent800 = Color(hex: 0x2C455D)
    static let accent900 = Color(hex: 0x1D2D3D)
    static let neutral100 = Color(hex: 0xF5F5F8)
    static let neutral800 = Color(hex: 0x424244)

    static var divider: Color { text.opacity(0.16) }
    static func ink(_ o: Double) -> Color { text.opacity(o) }

    // Barlow Condensed — headings.
    static func head(_ size: CGFloat) -> Font { .custom("BarlowCondensed-SemiBold", size: size) }
    static func headLight(_ size: CGFloat) -> Font { .custom("BarlowCondensed-Regular", size: size) }
    // Barlow — body.
    static func body(_ size: CGFloat) -> Font { .custom("Barlow-Regular", size: size) }
    static func bodyMedium(_ size: CGFloat) -> Font { .custom("Barlow-Medium", size: size) }
    static func bodyBold(_ size: CGFloat) -> Font { .custom("Barlow-Bold", size: size) }
}

/// A tracked, uppercase label — the system's eyebrow/kicker.
struct Eyebrow: View {
    let text: String
    var size: CGFloat = 10
    var em: CGFloat = 0.18
    var color: Color = Theme.accent700
    var heading: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(heading ? Theme.head(size) : Theme.body(size))
            .tracking(size * em)
            .foregroundStyle(color)
    }
}

/// Draws blueprint registration brackets just outside a view's corners.
struct BlueprintCornersShape: Shape {
    var out: CGFloat = 6
    var len: CGFloat = 11
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let minX = rect.minX - out, minY = rect.minY - out
        let maxX = rect.maxX + out, maxY = rect.maxY + out
        p.move(to: CGPoint(x: minX, y: minY + len)); p.addLine(to: CGPoint(x: minX, y: minY)); p.addLine(to: CGPoint(x: minX + len, y: minY))
        p.move(to: CGPoint(x: maxX - len, y: minY)); p.addLine(to: CGPoint(x: maxX, y: minY)); p.addLine(to: CGPoint(x: maxX, y: minY + len))
        p.move(to: CGPoint(x: minX, y: maxY - len)); p.addLine(to: CGPoint(x: minX, y: maxY)); p.addLine(to: CGPoint(x: minX + len, y: maxY))
        p.move(to: CGPoint(x: maxX - len, y: maxY)); p.addLine(to: CGPoint(x: maxX, y: maxY)); p.addLine(to: CGPoint(x: maxX, y: maxY - len))
        return p
    }
}

extension View {
    func blueprintCorners(color: Color = Theme.ink(0.5), out: CGFloat = 6) -> some View {
        overlay(BlueprintCornersShape(out: out).stroke(color, lineWidth: 1))
    }
}

/// A small squared tag (neutral / outline / accent).
struct Tag: View {
    enum Kind { case neutral, outline, accent }
    let text: String
    var kind: Kind = .neutral

    var body: some View {
        Text(text)
            .font(Theme.body(11))
            .tracking(0.2)
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(bg)
            .overlay(border)
    }

    private var fg: Color {
        switch kind {
        case .neutral: return Theme.neutral800
        case .outline: return Theme.accent
        case .accent: return Theme.accent800
        }
    }
    private var bg: Color {
        switch kind {
        case .neutral: return Theme.neutral100
        case .outline: return .clear
        case .accent: return Theme.accent100
        }
    }
    @ViewBuilder private var border: some View {
        if kind == .outline { Rectangle().strokeBorder(Theme.accent, lineWidth: 1) }
    }
}

/// The squared segmented control (accent fill on the selected option).
struct IndustrySegmented: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                let selected = selection == i
                Text(options[i].uppercased())
                    .font(Theme.body(11.5))
                    .tracking(1.15)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(selected ? Theme.bg : Theme.text)
                    .background(selected ? Theme.accent : Color.clear)
                    .overlay(alignment: .leading) {
                        if i > 0 { Rectangle().fill(Theme.divider).frame(width: 1) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { selection = i } }
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
    }
}

/// An animated bar waveform for the recording screen.
struct WaveformView: View {
    var color: Color = Theme.accent300
    var barCount: Int = 46
    @State private var animate = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { i in
                Rectangle()
                    .fill(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(y: animate ? 1 : 0.06, anchor: .center)
                    .animation(
                        .easeInOut(duration: 0.7 + Double(i % 5) * 0.16)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i % 9) * 0.11),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

extension View {
    /// The squared, surface-filled input styling used across Settings.
    func industryField(height: CGFloat = 44) -> some View {
        self
            .font(Theme.body(14))
            .tint(Theme.accent)
            .padding(.horizontal, 10)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .overlay(Rectangle().strokeBorder(Theme.divider, lineWidth: 1))
    }
}

/// Gentle press feedback for tappable controls.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Media

/// A video chosen from the Photos library, copied into the app's temp directory
/// so it has a stable URL we can hand to `AudioNormalizer`.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("photos-\(UUID().uuidString).\(ext)")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}
