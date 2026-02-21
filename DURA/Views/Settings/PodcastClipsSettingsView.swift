#if os(macOS)
import SwiftUI

struct PodcastClipsSettingsView: View {
    @AppStorage("podcastClipEnabled") private var isEnabled = true
    @AppStorage("podcastClipDuration") private var clipDuration = 60.0

    var body: some View {
        Form {
            Toggle("Enable Podcast Clipping", isOn: $isEnabled)

            Picker("Clip Duration", selection: $clipDuration) {
                Text("30 seconds").tag(30.0)
                Text("60 seconds").tag(60.0)
                Text("2 minutes").tag(120.0)
                Text("5 minutes").tag(300.0)
            }

            LabeledContent("Keyboard Shortcut") {
                Text("\u{2318}\u{21E7}P")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            LabeledContent("How it works") {
                Text("Press \u{2318}\u{21E7}P while a podcast is playing to capture a clip. DURA reads the now-playing info, resolves the episode via iTunes, extracts the audio segment, and transcribes it into a new note.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 300, alignment: .leading)
            }
        }
        .padding()
    }
}
#endif
