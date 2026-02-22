import Foundation

@Observable
class ThemeManager {
    var currentTheme: TerminalTheme
    var availableThemes: [TerminalTheme]

    private let defaultsKeyThemeId = "selectedThemeId"
    private let defaultsKeyCustomThemes = "customThemes"

    init() {
        let builtIn = TerminalTheme.builtInThemes

        var custom: [TerminalTheme] = []
        if let data = UserDefaults.standard.data(forKey: defaultsKeyCustomThemes),
           let decoded = try? JSONDecoder().decode([TerminalTheme].self, from: data) {
            custom = decoded
        }

        let allThemes = builtIn + custom
        let savedId = UserDefaults.standard.string(forKey: defaultsKeyThemeId)

        availableThemes = allThemes
        currentTheme = allThemes.first(where: { $0.id == savedId }) ?? builtIn[0]
    }

    func selectTheme(_ theme: TerminalTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.id, forKey: defaultsKeyThemeId)
    }

    func importITermColors(from url: URL) throws {
        var theme = try ITermColorsParser.parse(url: url)

        if availableThemes.contains(where: { $0.id == theme.id }) {
            theme = TerminalTheme(
                id: theme.id + "-\(Int.random(in: 1000...9999))",
                name: theme.name,
                isBuiltIn: false,
                background: theme.background,
                foreground: theme.foreground,
                cursor: theme.cursor,
                selection: theme.selection,
                ansiColors: theme.ansiColors
            )
        }

        availableThemes.append(theme)
        saveCustomThemes()
        selectTheme(theme)
    }

    func deleteCustomTheme(_ id: String) {
        availableThemes.removeAll { $0.id == id && !$0.isBuiltIn }
        saveCustomThemes()
        if currentTheme.id == id {
            selectTheme(TerminalTheme.builtInThemes[0])
        }
    }

    private func saveCustomThemes() {
        let custom = availableThemes.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: defaultsKeyCustomThemes)
        }
    }
}
