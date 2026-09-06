import Foundation
import AVFoundation

/// Converts an imported video or audio file into a compact audio-only m4a,
/// stripping any video track and compressing so uploads stay under the API limit.
enum AudioNormalizer {

    enum NormalizeError: LocalizedError {
        case noAudioTrack
        case exportFailed(underlying: Error?)

        var errorDescription: String? {
            switch self {
            case .noAudioTrack:
                return "That file has no audio to transcribe."
            case .exportFailed(let underlying):
                return "Could not process that file. \(underlying?.localizedDescription ?? "")"
            }
        }
    }

    /// Exports `sourceURL` (video or audio) to a temporary audio-only m4a file.
    static func normalize(sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        // Confirm there is audio to extract before spinning up an export.
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw NormalizeError.noAudioTrack }

        // AppleM4A preset yields an audio-only AAC m4a — video tracks are dropped.
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NormalizeError.exportFailed(underlying: nil)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-\(UUID().uuidString).m4a")

        export.outputURL = outputURL
        export.outputFileType = .m4a

        await withCheckedContinuation { continuation in
            export.exportAsynchronously {
                continuation.resume()
            }
        }

        switch export.status {
        case .completed:
            return outputURL
        default:
            throw NormalizeError.exportFailed(underlying: export.error)
        }
    }
}
