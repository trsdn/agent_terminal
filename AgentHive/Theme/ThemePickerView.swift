import SwiftUI
import UniformTypeIdentifiers

struct ThemePickerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showFileImporter = false
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(themeManager.availableThemes) { theme in
                Button {
                    themeManager.selectTheme(theme)
                } label: {
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            swatch(theme.background.color)
                            swatch(theme.foreground.color)
                            if theme.ansiColors.count > 4 {
                                swatch(theme.ansiColors[4].color)
                                swatch(theme.ansiColors[2].color)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(.white.opacity(0.15), lineWidth: 0.5)
                        )

                        Text(theme.name)
                            .foregroundStyle(.primary)

                        Spacer()

                        if theme.id == themeManager.currentTheme.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if !theme.isBuiltIn {
                        Button("Delete", role: .destructive) {
                            themeManager.deleteCustomTheme(theme.id)
                        }
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            Button {
                showFileImporter = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import .itermcolors...")
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if let error = importError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 240)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "itermcolors") ?? .xml,
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                do {
                    try themeManager.importITermColors(from: url)
                    importError = nil
                } catch {
                    importError = error.localizedDescription
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
    }

    private func swatch(_ color: SwiftUI.Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 14, height: 14)
    }
}
