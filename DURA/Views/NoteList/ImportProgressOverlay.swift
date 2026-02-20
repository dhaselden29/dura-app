import SwiftUI

struct ImportProgressOverlay: View {
    let progress: Double

    var body: some View {
        HStack(spacing: 12) {
            ProgressView(value: progress, total: 1.0)
                .frame(width: 120)
            Text("Importing...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 16)
    }
}
