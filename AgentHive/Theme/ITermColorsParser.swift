import Foundation

enum ITermColorsParser {
    enum ParseError: Error, LocalizedError {
        case invalidFormat
        case missingColors

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "Invalid .itermcolors file format"
            case .missingColors: return "Required colors missing from file"
            }
        }
    }

    static func parse(url: URL) throws -> TerminalTheme {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data, format: nil
        ) as? [String: Any] else {
            throw ParseError.invalidFormat
        }

        guard let bg = extractColor(from: plist, key: "Background Color"),
              let fg = extractColor(from: plist, key: "Foreground Color") else {
            throw ParseError.missingColors
        }

        let cursor = extractColor(from: plist, key: "Cursor Color") ?? fg
        let selection = extractColor(from: plist, key: "Selection Color") ?? HexColor("#3A3A5C")

        var ansiColors: [HexColor] = []
        for i in 0..<16 {
            if let color = extractColor(from: plist, key: "Ansi \(i) Color") {
                ansiColors.append(color)
            } else {
                ansiColors.append(TerminalTheme.agentHiveDark.ansiColors[i])
            }
        }

        let name = url.deletingPathExtension().lastPathComponent
        let id = "imported-" + name.lowercased().replacingOccurrences(of: " ", with: "-")

        return TerminalTheme(
            id: id,
            name: name,
            isBuiltIn: false,
            background: bg,
            foreground: fg,
            cursor: cursor,
            selection: selection,
            ansiColors: ansiColors
        )
    }

    private static func extractColor(from plist: [String: Any], key: String) -> HexColor? {
        guard let dict = plist[key] as? [String: Any],
              let r = dict["Red Component"] as? CGFloat,
              let g = dict["Green Component"] as? CGFloat,
              let b = dict["Blue Component"] as? CGFloat else {
            return nil
        }
        let hex = String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)),
            Int(round(g * 255)),
            Int(round(b * 255))
        )
        return HexColor(hex)
    }
}
