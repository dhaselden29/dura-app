import SwiftUI

struct AnnotationPopupView: View {
    let note: Note
    let dataService: DataService
    let anchorText: String
    let rangeStart: Int
    let rangeLength: Int
    @Environment(\.dismiss) private var dismiss

    @State private var comment = ""
    @State private var selectedColor: HighlightColor = .yellow

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected Text") {
                    Text(anchorText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Section("Comment") {
                    TextField("Add a comment...", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(HighlightColor.userColors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color.swiftUIColor)
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        if selectedColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.black.opacity(0.6))
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add Annotation")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dataService.addAnnotation(
                            to: note,
                            anchorText: anchorText,
                            rangeStart: rangeStart,
                            rangeLength: rangeLength,
                            comment: comment,
                            color: selectedColor
                        )
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 350, minHeight: 300)
        #endif
    }
}
