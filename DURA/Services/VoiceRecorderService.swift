import Foundation
import AVFoundation

@MainActor
@Observable
final class VoiceRecorderService {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var outputURL: URL?

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    func requestPermission() async -> Bool {
        #if os(iOS)
        return await AVAudioApplication.requestRecordPermission()
        #else
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        #endif
    }

    func startRecording() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "VoiceNote-\(Int(Date().timeIntervalSince1970)).m4a"
        let url = tempDir.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
        #endif

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()

        outputURL = url
        isRecording = true
        recordingDuration = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        return outputURL
    }

    func discardRecording() {
        let url = stopRecording()
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        outputURL = nil
        recordingDuration = 0
    }
}
