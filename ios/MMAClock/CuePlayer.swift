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
            for item in scheduled { item.player.volume = cueGain }
        }
    }

    private var keepalive: AVAudioPlayer?
    private var playing: [AVAudioPlayer] = []
    private var scheduled: [ScheduledCue] = []
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
        cancelScheduled()
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

    /// Ring bell shared with the web app (work, rest, end, and the volume preview).
    @discardableResult
    func playBell() -> Bool {
        playFile(resource: "bell", ext: "m4a", duck: true)
    }

    /// Queues cues on the audio device clock so they still sound if the run loop
    /// is delayed after the coach leaves the app. Returns the ids that were armed.
    @discardableResult
    func scheduleCues(_ cues: [(id: String, date: Date, sound: SoundID)]) -> Set<String> {
        cancelScheduled()
        ensureRunning()
        guard wantsSession, let clock = keepalive?.deviceCurrentTime else { return [] }
        var armed: Set<String> = []
        let now = Date()
        for cue in cues {
            let delay = cue.date.timeIntervalSince(now)
            guard delay > 0.08 else { continue }
            let file = files(for: cue.sound)
            guard let url = Bundle.main.url(forResource: file.resource, withExtension: file.ext),
                  let player = try? AVAudioPlayer(contentsOf: url)
            else { continue }
            player.volume = cueGain
            player.prepareToPlay()
            guard player.play(atTime: clock + delay) else { continue }
            scheduled.append(ScheduledCue(id: cue.id, starts: cue.date, player: player))
            armed.insert(cue.id)
        }
        holdKeepalive()
        return armed
    }

    func isScheduled(_ id: String) -> Bool {
        scheduled.contains { $0.id == id }
    }

    func cancelScheduled(after cutoff: Date = .distantPast) {
        scheduled.removeAll { item in
            guard item.starts > cutoff else { return false }
            item.player.stop()
            return true
        }
    }

    @discardableResult
    func playCue(_ sound: SoundID) -> Bool {
        if sound == .work || sound == .rest || sound == .end, playBell() {
            return true
        }
        let file = files(for: sound)
        return playFile(resource: file.resource, ext: file.ext, duck: true)
    }

    @discardableResult
    private func playFile(resource: String, ext: String, duck: Bool) -> Bool {
        configureMix()
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            print("MMA Clock: brak pliku \(resource).\(ext)")
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
                options: duck ? [.mixWithOthers, .duckOthers] : [.mixWithOthers]
            )
            playing.removeAll { !$0.isPlaying }
            playing.append(player)
            let started = player.play()
            if !started {
                playing.removeAll { $0 === player }
                restoreMix()
            }
            holdKeepalive()
            return started
        } catch {
            print("MMA Clock: dźwięk \(resource).\(ext): \(error.localizedDescription)")
            return false
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playing.removeAll { $0 === player }
        guard playing.isEmpty else { return }
        if wantsSession {
            restoreMix()
            ensureRunning()
            holdKeepalive()
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

    private func files(for sound: SoundID) -> (resource: String, ext: String) {
        switch sound {
        case .work, .rest, .end:
            if Bundle.main.url(forResource: "bell", withExtension: "m4a") != nil {
                return ("bell", "m4a")
            }
            return (sound.resource, "wav")
        case .prepare, .tick:
            return (sound.resource, "wav")
        }
    }

    private func holdKeepalive() {
        guard wantsSession else { return }
        if keepalive?.isPlaying != true {
            startKeepalive()
        }
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

    private struct ScheduledCue {
        var id: String
        var starts: Date
        var player: AVAudioPlayer
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
