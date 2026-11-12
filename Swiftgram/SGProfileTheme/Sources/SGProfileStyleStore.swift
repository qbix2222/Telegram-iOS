import Foundation
import SwiftUI
import SGSwiftUI
import SGStrings
import AccountContext
import TelegramPresentationData

public struct SGProfileStyle: Codable, Equatable {
    public var gradientStart: String
    public var gradientEnd: String
    public var nameFontSize: Double
    public var bioFontStyle: String
    public var accentChats: Bool
    public var bubbleStyle: String
    public var hideOnlineBadge: Bool

    public static let `default` = SGProfileStyle(gradientStart: "#5B72F2", gradientEnd: "#9B5BF2", nameFontSize: 28.0, bioFontStyle: "regular", accentChats: false, bubbleStyle: "classic", hideOnlineBadge: false)

    public init(gradientStart: String, gradientEnd: String, nameFontSize: Double, bioFontStyle: String, accentChats: Bool, bubbleStyle: String, hideOnlineBadge: Bool) {
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
        self.nameFontSize = nameFontSize
        self.bioFontStyle = bioFontStyle
        self.accentChats = accentChats
        self.bubbleStyle = bubbleStyle
        self.hideOnlineBadge = hideOnlineBadge
    }
}

public final class SGProfileStyleStore {
    public static let shared = SGProfileStyleStore()

    private let queue = DispatchQueue(label: "com.swiftgram.profileStyle")
    private var style: SGProfileStyle = .default
    private var loaded = false

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        return dir.appendingPathComponent("sg_profile_style.json")
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode(SGProfileStyle.self, from: data) else { return }
        style = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(style) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public var current: SGProfileStyle {
        get { queue.sync(execute: { loadIfNeeded(); return style }) }
        set { queue.sync(execute: { style = newValue; persist() }) }
    }

    public func color(from hex: String) -> UIColor {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return .systemBlue }
        return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255.0, green: CGFloat((value >> 8) & 0xFF) / 255.0, blue: CGFloat(value & 0xFF) / 255.0, alpha: 1.0)
    }

    public func hex(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
