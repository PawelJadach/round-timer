import SwiftUI

enum SettingsChrome {
    static let panelCorner: CGFloat = 16

    struct Panel<Content: View>: View {
        @ViewBuilder var content: () -> Content

        var body: some View {
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.canvas.opacity(0.9), in: RoundedRectangle(cornerRadius: panelCorner, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: panelCorner, style: .continuous)
                        .stroke(Palette.gold.opacity(0.32), lineWidth: 1)
                )
        }
    }

    struct Footer: View {
        let text: String

        var body: some View {
            Text(text)
                .font(Palette.ui(12, weight: .medium))
                .foregroundStyle(Palette.ink.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    struct LinkRow<Destination: View>: View {
        let title: String
        let systemImage: String
        @ViewBuilder var destination: () -> Destination

        var body: some View {
            NavigationLink {
                destination()
            } label: {
                rowLabel(title: title, systemImage: systemImage, trailing: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    struct URLRow: View {
        let title: String
        let systemImage: String
        let url: URL

        var body: some View {
            Link(destination: url) {
                rowLabel(title: title, systemImage: systemImage, trailing: "arrow.up.right")
            }
            .buttonStyle(.plain)
        }
    }

    struct ShareRow: View {
        let url: URL

        var body: some View {
            ShareLink(item: url) {
                rowLabel(title: L10n.t("share.button"), systemImage: "square.and.arrow.up", trailing: "chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private static func rowLabel(title: String, systemImage: String, trailing: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 24)
                .foregroundStyle(Palette.gold)
            Text(title)
                .font(Palette.ui(16))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Image(systemName: trailing)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.ink.opacity(0.35))
        }
        .contentShape(Rectangle())
    }

    struct LanguagePicker: View {
        @ObservedObject var language: AppLanguage

        var body: some View {
            HStack(spacing: 4) {
                languageButton("en", title: "English")
                languageButton("pl", title: "Polski")
            }
            .padding(4)
            .frame(maxWidth: .infinity)
            .background(Palette.canvas.opacity(0.9), in: Capsule())
            .overlay(Capsule().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        }

        private func languageButton(_ code: String, title: String) -> some View {
            let selected = language.code == code
            return Button {
                language.select(code)
                HapticFeedback.selection()
            } label: {
                Text(title)
                    .font(Palette.ui(15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selected ? Palette.gold.opacity(0.2) : Color.clear,
                        in: Capsule()
                    )
                    .overlay {
                        if selected {
                            Capsule().stroke(Palette.gold.opacity(0.55), lineWidth: 1)
                        }
                    }
                    .foregroundStyle(selected ? Palette.gold : Palette.ink.opacity(0.48))
            }
            .buttonStyle(.plain)
        }
    }
}

extension View {
    func settingsScreenChrome() -> some View {
        background(Palette.background.ignoresSafeArea())
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(Palette.gold)
            .foregroundStyle(Palette.ink)
    }
}
