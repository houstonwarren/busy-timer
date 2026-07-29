import AVFoundation

/// Plays the per-rep chime over whatever else the phone is playing. The
/// session uses .playback so the ring/silent switch can't mute it, and
/// .mixWithOthers so background music or an audiobook keeps playing at full,
/// constant volume — the chime simply layers on top. The player is prepared
/// once so playback at each rep boundary has no file-loading latency.
@MainActor
final class ChimePlayer {
    private var player: AVAudioPlayer?

    init() {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default, options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            // 1.0 is the ceiling: as loud as the system media volume allows
            player?.volume = 1
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
