import AVFoundation

/// Plays the per-rep chime. The player is prepared once so playback at each
/// rep boundary has no file-loading latency.
@MainActor
final class ChimePlayer {
    private var player: AVAudioPlayer?

    init() {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        } catch {
            player = nil
        }
    }

    func play() {
        player?.currentTime = 0
        player?.play()
    }
}
