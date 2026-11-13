import AVFoundation
import Foundation

/// Mixes short cues over the user's music. A quiet loop keeps the process
/// awake with the screen locked, so round changes stay on time.
/// `.mixWithOthers` leaves YouTube, Spotify or Apple Music playing.
final class CuePlayer: NSObject, AVAudioPlayerDelegate {
    var onInterruptionBegan: (() -> Void)?

    /// 0...1 linear gain applied to cue playback (web volume slider parity).
    var cueGain: Float = 1 {
        didSet {
            let clamped = max(0, min(1, cueGain))
            if clamped != cueGain { cueGain = clamped; return }
            for player in playing { player.volume = cueGain }
        }
    }

    private var keepalive: AVAudioPlayer?
    private var playing: [AVAudioPlayer] = []
    private var observers: [NSObjectProtocol] = []
    private var wantsSession = false

    override init() {
        super.init()
        let session = AVAudioSession.sharedInstance()
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] note in
            self?.handleInterruption(note)
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            self?.ensureRunning()
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func activate() {
        wantsSession = true
        configureMix()
        startKeepalive()
    }

    func deactivate() {
        wantsSession = false
        keepalive?.stop()
        keepalive = nil
        playing.removeAll()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func ensureRunning() {
        guard wantsSession, keepalive?.isPlaying != true else { return }
        configureMix()
        startKeepalive()
    }

    @discardableResult
    func playCue(_ sound: SoundID) -> Bool {
        configureMix()
        guard let url = Bundle.main.url(forResource: sound.resource, withExtension: "wav") else {
            print("MMA Clock: brak pliku \(sound.filename)")
            return false
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.volume = cueGain
            player.prepareToPlay()
            try? AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            playing.removeAll { !$0.isPlaying }
            playing.append(player)
            let started = player.play()
            if !started {
                playing.removeAll { $0 === player }
                restoreMix()
            }
            return started
        } catch {
            print("MMA Clock: dźwięk \(sound.filename): \(error.localizedDescription)")
            return false
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playing.removeAll { $0 === player }
        guard playing.isEmpty else { return }
        if wantsSession {
            restoreMix()
            ensureRunning()
        } else {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func configureMix() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("MMA Clock: sesja audio: \(error.localizedDescription)")
        }
    }

    private func restoreMix() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
    }

    private func startKeepalive() {
        if keepalive == nil {
            guard let url = Bundle.main.url(forResource: "cue_keepalive", withExtension: "wav") else { return }
            keepalive = try? AVAudioPlayer(contentsOf: url)
            keepalive?.numberOfLoops = -1
            keepalive?.volume = 0.02
            keepalive?.prepareToPlay()
        }
        keepalive?.play()
    }

    private func handleInterruption(_ note: Notification) {
        guard wantsSession,
              let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }
        if type == .began {
            onInterruptionBegan?()
            return
        }
        let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        if AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume) {
            ensureRunning()
        }
    }
}
