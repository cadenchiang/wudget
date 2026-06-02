import SwiftUI
import UIKit

/// How a `LibraryPickerView` lays out its entries.
enum LibraryPickerStyle {
    /// Squircle logo tiles in an adaptive grid (used for merchants).
    case grid
    /// Contact-style rows (logo + name) in a list (used for cards).
    case list
}

/// A searchable picker for choosing a merchant or card, with a Recent section and the ability to
/// add custom entries.
///
/// Built-in items and any user-added custom entries are shown as icon tiles. Recently picked
/// entries appear in a "Recent" section at the top. Typing a name that isn't known offers an
/// "Add" action that saves it (so it's clickable next time) and selects it. Recents and custom
/// entries are persisted per picker via `AppStorage`.
struct LibraryPickerView: View {
    /// Screen title and search noun (e.g. "Merchant", "Card").
    let title: String
    /// The built-in library entries.
    let builtinItems: [LibraryItem]
    /// Icon used for custom (user-added) entries.
    let fallbackIcon: String
    /// Whether entries render as grid tiles (merchants) or list rows (cards).
    let style: LibraryPickerStyle
    /// Called with the chosen (or custom) name.
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @AppStorage private var recentsRaw: String
    @AppStorage private var customRaw: String

    init(title: String, items: [LibraryItem], fallbackIcon: String, style: LibraryPickerStyle = .grid, onSelect: @escaping (String) -> Void) {
        self.title = title
        self.builtinItems = items
        self.fallbackIcon = fallbackIcon
        self.style = style
        self.onSelect = onSelect
        _recentsRaw = AppStorage(wrappedValue: "", "library.recents.\(title)")
        _customRaw = AppStorage(wrappedValue: "", "library.custom.\(title)")
    }

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 16)]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decodes a newline-delimited stored list.
    private func decode(_ raw: String) -> [String] {
        raw.split(separator: "\n").map(String.init)
    }

    private var customNames: [String] { decode(customRaw) }
    private var recents: [String] { decode(recentsRaw) }

    /// Built-in items plus user-added custom items (custom render with the fallback icon).
    private var allItems: [LibraryItem] {
        let known = Set(builtinItems.map { $0.name.lowercased() })
        let custom = customNames
            .filter { !known.contains($0.lowercased()) }
            .map { LibraryItem(name: $0, systemImage: fallbackIcon, color: .gray) }
        return builtinItems + custom
    }

    /// Resolves a name to a library item, falling back to a gray custom tile.
    private func item(named name: String) -> LibraryItem {
        allItems.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            ?? LibraryItem(name: name, systemImage: fallbackIcon, color: .gray)
    }

    /// Items matching the query (all items when the query is empty).
    private var filtered: [LibraryItem] {
        guard !trimmedQuery.isEmpty else { return allItems }
        return allItems.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
    }

    private var recentItems: [LibraryItem] { recents.map(item(named:)) }

    /// Whether the typed query is a new entry that can be added.
    private var canAddCustom: Bool {
        !trimmedQuery.isEmpty && !allItems.contains { $0.name.caseInsensitiveCompare(trimmedQuery) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if canAddCustom { addCustomButton }
                    if trimmedQuery.isEmpty { recentSection }
                    section(header: trimmedQuery.isEmpty ? "All \(title)s" : "Results", entries: filtered)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search or add \(title.lowercased())"
            )
        }
    }

    /// Row that adds and selects the typed custom entry.
    private var addCustomButton: some View {
        Button {
            addCustom(trimmedQuery)
            select(trimmedQuery)
        } label: {
            Label("Add “\(trimmedQuery)”", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
        .tint(.primary)
    }

    /// The Recent section: recent tiles, or a placeholder when there are none yet, in a card.
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent").font(.headline)
            Group {
                if recentItems.isEmpty {
                    Text("Recent \(title.lowercased())s will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    content(recentItems)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    /// A titled section of entries (grid tiles or list rows) inside a squircle card.
    private func section(header: String, entries: [LibraryItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(header).font(.headline)
            content(entries)
                .padding(style == .list ? 8 : 16)
                .frame(maxWidth: .infinity)
                .background(cardBackground)
        }
    }

    /// Entries laid out per `style`: grid tiles (merchants) or list rows (cards).
    @ViewBuilder
    private func content(_ entries: [LibraryItem]) -> some View {
        switch style {
        case .grid: grid(entries)
        case .list: list(entries)
        }
    }

    /// A grid of tappable icon tiles.
    private func grid(_ entries: [LibraryItem]) -> some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(entries) { entry in
                Button { select(entry.name) } label: { tile(entry) }
                    .tint(.primary)
            }
        }
    }

    /// A contact-style list of rows, separated by hairline dividers inset past the logo.
    private func list(_ entries: [LibraryItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button { select(entry.name) } label: { listRow(entry) }
                    .tint(.primary)
                if index < entries.count - 1 {
                    Divider().padding(.leading, 50)
                }
            }
        }
    }

    /// One list row: a small logo and the card name, like a contacts entry.
    private func listRow(_ item: LibraryItem) -> some View {
        HStack(spacing: 12) {
            logo(for: item)
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(item.name)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    /// Squircle card background for sections.
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    /// One icon tile: a real logo (bundled asset or fetched from the logo service) when available,
    /// otherwise a colored SF Symbol tile.
    private func tile(_ item: LibraryItem) -> some View {
        VStack(spacing: 8) {
            logo(for: item)
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(item.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Logo resolution: bundled asset → fetched logo → SF Symbol fallback (also shown while loading).
    @ViewBuilder
    private func logo(for item: LibraryItem) -> some View {
        if let asset = item.assetName, UIImage(named: asset) != nil {
            imageTile { Image(asset).resizable().scaledToFill() }
        } else if let primary = LogoProvider.logoURL(for: item) {
            AsyncImage(url: primary) { phase in
                if case .success(let image) = phase {
                    imageTile { image.resizable().scaledToFill() }
                } else if let fallback = LogoProvider.fallbackURL(for: item) {
                    AsyncImage(url: fallback) { fallbackPhase in
                        if case .success(let image) = fallbackPhase {
                            imageTile { image.resizable().scaledToFill() }
                        } else {
                            symbolTile(item)
                        }
                    }
                } else {
                    symbolTile(item)
                }
            }
        } else {
            symbolTile(item)
        }
    }

    /// A white tile hosting a fetched/bundled logo image that fills the squircle edge-to-edge.
    private func imageTile<Content: View>(@ViewBuilder _ image: () -> Content) -> some View {
        ZStack {
            Color.white
            image()
        }
    }

    /// The colored SF Symbol fallback tile.
    private func symbolTile(_ item: LibraryItem) -> some View {
        ZStack {
            Rectangle().fill(item.color.gradient)
            Image(systemName: item.systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    /// Records the selection in recents, reports it, and dismisses.
    private func select(_ name: String) {
        Haptics.tap()
        addRecent(name)
        onSelect(name)
        dismiss()
    }

    /// Moves a name to the front of recents (deduped, capped at 8).
    private func addRecent(_ name: String) {
        var list = recents.filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        list.insert(name, at: 0)
        recentsRaw = list.prefix(8).joined(separator: "\n")
    }

    /// Persists a new custom entry (no-op if it already exists as built-in or custom).
    private func addCustom(_ name: String) {
        let existsBuiltin = builtinItems.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        let existsCustom = customNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        guard !existsBuiltin, !existsCustom else { return }
        customRaw = (customNames + [name]).joined(separator: "\n")
    }
}

#Preview {
    LibraryPickerView(title: "Merchant", items: MerchantLibrary.items, fallbackIcon: "tag.fill") { _ in }
}
