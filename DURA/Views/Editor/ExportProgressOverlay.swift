import SwiftUI

struct ExportProgressOverlay: View {
    let progress: Double
    let label: String

    init(progress: Double, label: String = "Exporting...") {
        self.progress = progress
        self.label = label
    }

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: progress, total: 1.0)
                .frame(width: 120)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 16)
    }
}
