import Foundation
import Speech

struct SpeechTranscriptionService: Sendable {

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(url: URL, progress: (@Sendable (Double) -> Void)? = nil) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        progress?(0.2)

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: TranscriptionError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let result else { return }

                if result.isFinal {
                    progress?(1.0)
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    enum TranscriptionError: LocalizedError {
        case unavailable
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "Speech recognition is not available on this device."
            case .recognitionFailed(let reason):
                "Speech recognition failed: \(reason)"
            }
        }
    }
}
