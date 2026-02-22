import SwiftUI

struct HighlightsPanelView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                let highlights = note.highlights.sorted { $0.rangeStart < $1.rangeStart }
                if highlights.isEmpty {
                    ContentUnavailableView(
                        "No Highlights",
                        systemImage: "highlighter",
                        description: Text("Select text in the editor and tap Highlight to add one.")
                    )
                } else {
                    List {
                        ForEach(highlights) { highlight in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(highlight.color.swiftUIColor)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(highlight.anchorText)
                                            .font(.caption)
                                            .lineLimit(2)

                                        if highlight.author == .ai {
                                            Image(systemName: "sparkle")
                                                .font(.caption2)
                                                .foregroundStyle(.purple)
                                        }
                                    }

                                    if let annotation = highlight.annotation, !annotation.isEmpty {
                                        Text(annotation)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            var highlights = note.highlights.sorted { $0.rangeStart < $1.rangeStart }
                            highlights.remove(atOffsets: indexSet)
                            note.highlights = highlights
                        }
                    }
                }
            }
            .navigationTitle("Highlights")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 300)
    }
}
