import SwiftUI

struct RootView: View {
    @EnvironmentObject private var clock: TrainingClock
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected: TrainingMode = .sparring
    @State private var showAppSettings = false

    private var display: Face {
        clock.runState == .idle ? clock.previewFace(for: selected) : clock.face
    }

    private var showSettings: Bool { clock.runState == .idle }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Palette.background.ignoresSafeArea()
                Circle()
                    .fill(Palette.color(display.tint).opacity(0.42))
                    .frame(width: 460, height: 460)
                    .blur(radius: 90)
                    .offset(y: -80)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 22) {
                        topBar
                        Spacer(minLength: 8)
                        timerBlock
                        if clock.mode == .stopwatch, clock.runState != .idle, !clock.laps.isEmpty {
                            lapsList
                        }
                        if showSettings {
                            settings
                        }
                        controls
                        hints
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .frame(maxWidth: 560)
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(isPresented: $showAppSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showAppSettings = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Close")
                        }
                    }
            }
            .environmentObject(clock)
            .preferredColorScheme(.dark)
        }
        .onAppear { clock.refreshCapabilities() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                clock.catchUp()
                clock.refreshCapabilities()
            } else if phase == .background {
                clock.prepareForBackground()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(TrainingMode.allCases) { mode in
                    Button {
                        guard clock.runState == .idle || clock.runState == .finished else { return }
                        if clock.runState == .finished, mode != selected {
                            clock.reset()
                        }
                        selected = mode
                        HapticFeedback.selection()
                    } label: {
                        Text(mode.title)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selected == mode ? Color.white.opacity(0.14) : Color.clear, in: Capsule())
                            .foregroundStyle(selected == mode ? Color.white : Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.06), in: Capsule())
            .opacity(clock.runState == .running || clock.runState == .paused ? 0.45 : 1)
            .allowsHitTesting(clock.runState == .idle || clock.runState == .finished)

            Button {
                clock.soundEnabled.toggle()
                HapticFeedback.light()
            } label: {
                Image(systemName: clock.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(clock.soundEnabled ? String(localized: "sound.off") : String(localized: "sound.on"))

            Button {
                showAppSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "settings.title"))
        }
    }

    private var timerBlock: some View {
        VStack(spacing: 8) {
            Text(display.phaseName)
                .font(.subheadline.weight(.bold))
                .tracking(2.4)
                .foregroundStyle(Palette.color(display.tint))
            Text(display.text)
                .font(.system(size: showSettings ? 76 : 96, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(.white)
                .accessibilityLabel("\(display.phaseName) \(display.text)")
            Text(display.detail)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: display.tint)
    }

    private var lapsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(clock.laps.reversed()) { lap in
                    HStack {
                        Text("\(lap.id)")
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .leading)
                        Spacer()
                        Text(ClockFormat.stopwatch(lap.split))
                            .foregroundStyle(.secondary)
                        Text(ClockFormat.stopwatch(lap.total))
                            .frame(width: 116, alignment: .trailing)
                    }
                    .font(.subheadline.monospacedDigit())
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: 168)
    }

    private func adjust(_ value: Int, direction: Int, lower: Int, upper: Int) -> Int {
        let step = value < 60 ? 5 : 15
        return min(upper, max(lower, value + direction * step))
    }

    @ViewBuilder
    private var settings: some View {
        switch selected {
        case .sparring:
            sparringSettings
        case .countdown:
            countdownSettings
        case .stopwatch:
            Text(String(localized: "stopwatch.hint"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var sparringSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    preset(String(localized: "preset.tabata"), "20/10 × 8") {
                        clock.prepareSeconds = 5
                        clock.workSeconds = 20
                        clock.restSeconds = 10
                        clock.rounds = 8
                    }
                    preset(String(localized: "preset.interval"), "30/15 × 10") {
                        clock.prepareSeconds = 5
                        clock.workSeconds = 30
                        clock.restSeconds = 15
                        clock.rounds = 10
                    }
                    preset(String(localized: "preset.sparring"), "3:00 / 1:00 × 5") {
                        clock.prepareSeconds = 10
                        clock.workSeconds = 180
                        clock.restSeconds = 60
                        clock.rounds = 5
                    }
                    preset(String(localized: "preset.round"), "5:00 / 1:00 × 3") {
                        clock.prepareSeconds = 10
                        clock.workSeconds = 300
                        clock.restSeconds = 60
                        clock.rounds = 3
                    }
                }
            }
            stepRow(String(localized: "setting.prepare"), text: ClockFormat.clock(seconds: clock.prepareSeconds)) {
                clock.prepareSeconds = min(120, max(0, clock.prepareSeconds - 5))
            } increment: {
                clock.prepareSeconds = min(120, max(0, clock.prepareSeconds + 5))
            }
            stepRow(String(localized: "setting.work"), text: ClockFormat.clock(seconds: clock.workSeconds)) {
                clock.workSeconds = adjust(clock.workSeconds, direction: -1, lower: 5, upper: 3600)
            } increment: {
                clock.workSeconds = adjust(clock.workSeconds, direction: 1, lower: 5, upper: 3600)
            }
            stepRow(String(localized: "setting.rest"), text: ClockFormat.clock(seconds: clock.restSeconds)) {
                clock.restSeconds = adjust(clock.restSeconds, direction: -1, lower: 0, upper: 1800)
            } increment: {
                clock.restSeconds = adjust(clock.restSeconds, direction: 1, lower: 0, upper: 1800)
            }
            stepRow(String(localized: "setting.rounds"), text: "\(clock.rounds)") {
                clock.rounds = min(30, max(1, clock.rounds - 1))
            } increment: {
                clock.rounds = min(30, max(1, clock.rounds + 1))
            }
            Text(String(localized: "setting.total \(ClockFormat.clock(seconds: clock.sparringTotalSeconds))"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var countdownSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    preset("0:30", "30s") { clock.countdownSeconds = 30 }
                    preset("1:00", "1 min") { clock.countdownSeconds = 60 }
                    preset("3:00", "3 min") { clock.countdownSeconds = 180 }
                    preset("5:00", "5 min") { clock.countdownSeconds = 300 }
                    preset("10:00", "10 min") { clock.countdownSeconds = 600 }
                }
            }
            stepRow(String(localized: "setting.countdown_minutes"), text: "\(clock.countdownSeconds / 60)") {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds - 60))
            } increment: {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds + 60))
            }
            stepRow(String(localized: "setting.countdown_seconds"), text: String(format: "%02d", clock.countdownSeconds % 60)) {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds - 5))
            } increment: {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds + 5))
            }
        }
    }

    private func preset(_ title: String, _ subtitle: String, apply: @escaping () -> Void) -> some View {
        Button {
            apply()
            HapticFeedback.selection()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stepRow(_ title: String, text: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.body.weight(.medium))
            Spacer(minLength: 8)
            stepButton("minus", action: decrement)
            Text(text)
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(width: 78)
            stepButton("plus", action: increment)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(text)
    }

    private func stepButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticFeedback.light()
        } label: {
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var controls: some View {
        switch clock.runState {
        case .idle:
            Button(String(localized: "control.start")) { clock.start(mode: selected) }
                .buttonStyle(PrimaryButton(fill: Palette.color(display.tint)))
                .disabled(!clock.canStart(selected))
                .opacity(clock.canStart(selected) ? 1 : 0.4)
        case .running where clock.mode == .stopwatch:
            HStack(spacing: 12) {
                Button(String(localized: "control.lap")) { clock.lap() }
                    .buttonStyle(SecondaryButton())
                Button(String(localized: "control.pause")) { clock.pause() }
                    .buttonStyle(PrimaryButton(fill: .white, foreground: .black))
            }
        case .running:
            HStack(spacing: 12) {
                Button(String(localized: "control.reset")) { clock.reset() }
                    .buttonStyle(SecondaryButton())
                Button(String(localized: "control.pause")) { clock.pause() }
                    .buttonStyle(PrimaryButton(fill: .white, foreground: .black))
            }
        case .paused:
            HStack(spacing: 12) {
                Button(String(localized: "control.reset")) { clock.reset() }
                    .buttonStyle(SecondaryButton())
                Button(String(localized: "control.resume")) { clock.resume() }
                    .buttonStyle(PrimaryButton(fill: Palette.color(display.tint)))
            }
        case .finished:
            HStack(spacing: 12) {
                Button(String(localized: "control.reset")) { clock.reset() }
                    .buttonStyle(SecondaryButton())
                Button(String(localized: "control.again")) { clock.start(mode: clock.mode) }
                    .buttonStyle(PrimaryButton(fill: Palette.color("end"), foreground: .black))
            }
        }
    }

    private var hints: some View {
        VStack(spacing: 8) {
            Text(String(localized: "hint.background"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if clock.notificationStatus == .needsPrompt || clock.notificationStatus == .denied {
                Button(clock.notificationStatus == .denied
                       ? String(localized: "hint.notifications_denied")
                       : String(localized: "hint.notifications_prompt")) {
                    clock.requestNotifications()
                }
                .font(.footnote.weight(.semibold))
            }
            if showSettings, clock.liveActivitiesOff {
                Button(String(localized: "hint.live_activities")) {
                    clock.openSettings()
                }
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
            }
        }
    }
}

private struct PrimaryButton: ButtonStyle {
    var fill: Color
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(fill.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
    }
}

private struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.white.opacity(configuration.isPressed ? 0.04 : 0.08), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}
