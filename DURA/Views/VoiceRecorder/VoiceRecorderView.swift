import SwiftUI

struct VoiceRecorderView: View {
    let dataService: DataService
    var onSaved: ((Note) -> Void)?

    @State private var recorder = VoiceRecorderService()
    @State private var permissionDenied = false
    @State private var savedNote: Note?
    @State private var isTranscribing = false
    @State private var transcriptionError: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Mic icon
            Image(systemName: recorder.isRecording ? "mic.circle.fill" : "mic.circle")
                .font(.system(size: 72))
                .foregroundStyle(recorder.isRecording ? Color.red : Color.accentColor)
                .symbolEffect(.pulse, isActive: recorder.isRecording)

            // Duration
            Text(formatDuration(recorder.recordingDuration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(recorder.isRecording ? .primary : .secondary)

            if isTranscribing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Transcribing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = transcriptionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            // Controls
            if recorder.isRecording {
                Button {
                    handleStop()
                } label: {
                    Label("Stop Recording", systemImage: "stop.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else if recorder.outputURL != nil {
                HStack(spacing: 20) {
                    Button(role: .destructive) {
                        recorder.discardRecording()
                    } label: {
                        Label("Discard", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        saveVoiceNote()
                    } label: {
                        Label("Save", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button {
                    startRecording()
                } label: {
                    Label("Record", systemImage: "record.circle")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(32)
        .frame(minWidth: 320, minHeight: 340)
        .alert("Microphone Access Denied", isPresented: $permissionDenied) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Please enable microphone access in System Settings to record voice notes.")
        }
    }

    private func startRecording() {
        Task {
            let granted = await recorder.requestPermission()
            guard granted else {
                permissionDenied = true
                return
            }
            try? recorder.startRecording()
        }
    }

    private func handleStop() {
        _ = recorder.stopRecording()
    }

    private func saveVoiceNote() {
        guard let audioURL = recorder.outputURL else { return }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let title = "Voice Note — \(formatter.string(from: Date()))"
        let filename = audioURL.lastPathComponent

        guard let audioData = try? Data(contentsOf: audioURL) else { return }

        let body = "🔊 [\(filename)](attachment://\(filename))"
        let note = dataService.createNote(title: title, body: body, source: .audio)

        let attachment = dataService.createAttachment(
            filename: filename,
            data: audioData,
            mimeType: "audio/mp4",
            note: note
        )
        _ = attachment

        try? dataService.save()
        savedNote = note

        // Run transcription
        transcribeAudio(url: audioURL, note: note)

        onSaved?(note)
    }

    private func transcribeAudio(url: URL, note: Note) {
        isTranscribing = true
        transcriptionError = nil

        Task {
            let service = SpeechTranscriptionService()

            let authorized = await service.requestAuthorization()
            guard authorized else {
                isTranscribing = false
                transcriptionError = "Speech recognition not authorized."
                scheduleDismiss()
                return
            }

            do {
                let transcript = try await service.transcribe(url: url)
                if !transcript.isEmpty {
                    note.body += "\n\n\(transcript)"
                    note.modifiedAt = Date()
                    try? dataService.save()
                }
                isTranscribing = false
                scheduleDismiss()
            } catch {
                isTranscribing = false
                transcriptionError = "Transcription failed: \(error.localizedDescription)"
                scheduleDismiss()
            }
        }
    }

    private func scheduleDismiss() {
        Task {
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - Double(Int(duration))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}
