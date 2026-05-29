import SwiftUI

/// One titled paragraph within a legal document.
struct LegalSection: Identifiable {
    var id: String { heading }
    let heading: String
    let body: String
}

/// Renders an in-app legal document (privacy policy / terms): an "updated" date, an intro
/// paragraph, and a list of titled sections. Scrollable, no external links or redirects.
struct LegalDocumentView: View {
    let title: String
    let updated: String
    let intro: String
    let sections: [LegalSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Last updated: \(updated)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(intro)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.heading)
                            .font(.headline)
                        Text(section.body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
