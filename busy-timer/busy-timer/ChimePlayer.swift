import AVFoundation

/// Plays the per-rep chime over whatever else the phone is playing. The
/// session uses .playback so the ring/silent switch can't mute it, and
/// .mixWithOthers so background music or an audiobook keeps playing at full,
/// constant volume — the chime simply layers on top. The player is prepared
/// once so playback at each rep boundary has no file-loading latency.
actor ChimePlayer {
    private var player: AVAudioPlayer?
    private var preparation: Task<Void, Never>?

    /// Prepare once off the main actor; concurrent requests wait for the same setup.
    func prepare() async {
        if preparation == nil {
            preparation = Task { await loadPlayer() }
        }
        await preparation?.value
    }

    /// Activate mixed playback, then load and buffer the bundled chime.
    private func loadPlayer() async {
        guard let url = Bundle.main.url(forResource: "chime", withExtension: "mp3") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback, mode: .default, options: [.mixWithOthers]
            )
            if #available(iOS 27.0, *) {
                guard try await session.activate(options: []) else { return }
            } else {
                try session.setActive(true)
            }
            player = try AVAudioPlayer(contentsOf: url)
            // 1.0 is the ceiling: as loud as the system media volume allows
            player?.volume = 1
            player?.prepareToPlay()
        } catch {
            player = nil
        }
    }

    /// Restart the chime, waiting for preparation if playback is requested early.
    func play() async {
        await prepare()
        player?.currentTime = 0
        player?.play()
    }
}
