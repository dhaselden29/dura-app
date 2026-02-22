import SwiftUI

struct AnnotationSidebarView: View {
    @Bindable var note: Note
    let dataService: DataService

    @State private var showAIAnnotations = true
    @State private var editingAnnotationID: UUID?
    @State private var editText = ""

    private var personalAnnotations: [Highlight] {
        note.highlights
            .filter { $0.isComment && $0.author == .personal }
            .sorted { $0.rangeStart < $1.rangeStart }
    }

    private var aiAnnotations: [Highlight] {
        note.highlights
            .filter { $0.isComment && $0.author == .ai }
            .sorted { $0.rangeStart < $1.rangeStart }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Annotations")
                    .font(.headline)
                Spacer()
                Text("\(personalAnnotations.count + aiAnnotations.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if personalAnnotations.isEmpty && aiAnnotations.isEmpty {
                ContentUnavailableView(
                    "No Annotations",
                    systemImage: "text.bubble",
                    description: Text("Highlight text and add comments to annotate this article.")
                )
            } else {
                List {
                    if !personalAnnotations.isEmpty {
                        Section("Personal") {
                            ForEach(personalAnnotations) { highlight in
                                annotationRow(highlight)
                            }
                        }
                    }

                    if !aiAnnotations.isEmpty {
                        Section {
                            ForEach(aiAnnotations) { highlight in
                                aiAnnotationRow(highlight)
                            }
                        } header: {
                            HStack {
                                Label("AI", systemImage: "sparkle")
                                Spacer()
                                Toggle("", isOn: $showAIAnnotations)
                                    .toggleStyle(.switch)
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Row Views

    @ViewBuilder
    private func annotationRow(_ highlight: Highlight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(highlight.color.swiftUIColor)
                    .frame(width: 8, height: 8)

                Text(highlight.anchorText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if editingAnnotationID == highlight.id {
                HStack {
                    TextField("Edit comment", text: $editText)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    Button("Save") {
                        dataService.updateAnnotation(id: highlight.id, on: note, newComment: editText)
                        editingAnnotationID = nil
                    }
                    .font(.caption)
                }
            } else if let comment = highlight.annotation, !comment.isEmpty {
                Text(comment)
                    .font(.caption)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                editText = highlight.annotation ?? ""
                editingAnnotationID = highlight.id
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                dataService.removeAnnotation(id: highlight.id, from: note)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func aiAnnotationRow(_ highlight: Highlight) -> some View {
        if showAIAnnotations {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.caption2)
                        .foregroundStyle(.purple)

                    Text(highlight.anchorText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let comment = highlight.annotation, !comment.isEmpty {
                    Text(comment)
                        .font(.caption)
                        .lineLimit(3)
                        .textSelection(.disabled)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
