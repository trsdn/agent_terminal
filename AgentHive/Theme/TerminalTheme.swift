import Foundation
import AppKit
import SwiftUI
import SwiftTerm

// MARK: - HexColor

struct HexColor: Codable, Equatable, Hashable, ExpressibleByStringLiteral {
    let hex: String

    init(_ hex: String) { self.hex = hex }
    init(stringLiteral value: String) { self.hex = value }

    init(from decoder: Decoder) throws {
        hex = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }

    private var components: (r: UInt8, g: UInt8, b: UInt8) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt32(h, radix: 16) else { return (0, 0, 0) }
        return (UInt8((val >> 16) & 0xFF), UInt8((val >> 8) & 0xFF), UInt8(val & 0xFF))
    }

    var nsColor: NSColor {
        let c = components
        return NSColor(
            red: CGFloat(c.r) / 255,
            green: CGFloat(c.g) / 255,
            blue: CGFloat(c.b) / 255,
            alpha: 1
        )
    }

    var color: SwiftUI.Color {
        SwiftUI.Color(nsColor: nsColor)
    }

    var swiftTermColor: SwiftTerm.Color {
        let c = components
        return SwiftTerm.Color(
            red: UInt16(c.r) * 257,
            green: UInt16(c.g) * 257,
            blue: UInt16(c.b) * 257
        )
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }
}

// MARK: - TerminalTheme

struct TerminalTheme: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var isBuiltIn: Bool

    // Terminal colors
    var background: HexColor
    var foreground: HexColor
    var cursor: HexColor
    var selection: HexColor
    var ansiColors: [HexColor]  // 16 colors (ANSI 0-15)

    // App UI (nil = derived from terminal background)
    var sidebarBackground: HexColor?
    var gridBackground: HexColor?
}

// MARK: - Derived Colors

extension TerminalTheme {
    var effectiveGridBackground: NSColor {
        if let gb = gridBackground { return gb.nsColor }
        let bg = background.nsColor
        return bg.blended(withFraction: 0.2, of: .black) ?? bg
    }

    var effectiveSidebarBackground: NSColor {
        if let sb = sidebarBackground { return sb.nsColor }
        let bg = background.nsColor
        return bg.blended(withFraction: 0.08, of: .white) ?? bg
    }
}

// MARK: - Built-in Themes

extension TerminalTheme {
    static let builtInThemes: [TerminalTheme] = [
        .agentHiveDark,
        .dracula,
        .nord,
        .solarizedDark,
        .catppuccinMocha,
    ]

    static let agentHiveDark = TerminalTheme(
        id: "agenthive-dark",
        name: "AgentHive Dark",
        isBuiltIn: true,
        background: "#141414",
        foreground: "#D1D1D1",
        cursor: "#59BFFF",
        selection: "#3A3A5C",
        ansiColors: [
            "#000000", "#BB0000", "#00BB00", "#BBBB00",
            "#0000BB", "#BB00BB", "#00BBBB", "#BBBBBB",
            "#555555", "#FF5555", "#55FF55", "#FFFF55",
            "#5555FF", "#FF55FF", "#55FFFF", "#FFFFFF",
        ],
        sidebarBackground: "#1A1A1A",
        gridBackground: "#0F0F0F"
    )

    static let dracula = TerminalTheme(
        id: "dracula",
        name: "Dracula",
        isBuiltIn: true,
        background: "#282A36",
        foreground: "#F8F8F2",
        cursor: "#F8F8F2",
        selection: "#44475A",
        ansiColors: [
            "#21222C", "#FF5555", "#50FA7B", "#F1FA8C",
            "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2",
            "#6272A4", "#FF6E6E", "#69FF94", "#FFFFA5",
            "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF",
        ]
    )

    static let nord = TerminalTheme(
        id: "nord",
        name: "Nord",
        isBuiltIn: true,
        background: "#2E3440",
        foreground: "#D8DEE9",
        cursor: "#D8DEE9",
        selection: "#434C5E",
        ansiColors: [
            "#3B4252", "#BF616A", "#A3BE8C", "#EBCB8B",
            "#81A1C1", "#B48EAD", "#88C0D0", "#E5E9F0",
            "#4C566A", "#BF616A", "#A3BE8C", "#EBCB8B",
            "#81A1C1", "#B48EAD", "#8FBCBB", "#ECEFF4",
        ]
    )

    static let solarizedDark = TerminalTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        isBuiltIn: true,
        background: "#002B36",
        foreground: "#839496",
        cursor: "#839496",
        selection: "#073642",
        ansiColors: [
            "#073642", "#DC322F", "#859900", "#B58900",
            "#268BD2", "#D33682", "#2AA198", "#EEE8D5",
            "#002B36", "#CB4B16", "#586E75", "#657B83",
            "#839496", "#6C71C4", "#93A1A1", "#FDF6E3",
        ]
    )

    static let catppuccinMocha = TerminalTheme(
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        isBuiltIn: true,
        background: "#1E1E2E",
        foreground: "#CDD6F4",
        cursor: "#F5E0DC",
        selection: "#45475A",
        ansiColors: [
            "#45475A", "#F38BA8", "#A6E3A1", "#F9E2AF",
            "#89B4FA", "#F5C2E7", "#94E2D5", "#BAC2DE",
            "#585B70", "#F38BA8", "#A6E3A1", "#F9E2AF",
            "#89B4FA", "#F5C2E7", "#94E2D5", "#A6ADC8",
        ]
    )
}
