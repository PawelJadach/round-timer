import SwiftUI

struct RootView: View {
    @EnvironmentObject private var clock: TrainingClock
    @ObservedObject private var language = AppLanguage.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected: TrainingMode = .sparring
    @State private var showAppSettings = false
    @State private var volumePreviewArmed = false

    private var display: Face {
        clock.runState == .idle ? clock.previewFace(for: selected) : clock.face
    }

    private var showSettings: Bool { clock.runState == .idle }
    private var showSessionChrome: Bool { clock.runState == .idle }

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

                ScrollView(.vertical) {
                    VStack(spacing: 18) {
                        topBar
                        if showSessionChrome {
                            volumeRow
                        }
                        timerBlock
                        if clock.mode == .stopwatch, clock.runState != .idle, !clock.laps.isEmpty {
                            lapsList
                        }
                        if showSettings {
                            settings
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        controls
                        hints
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .frame(maxWidth: min(560, geo.size.width))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
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
                            .accessibilityLabel(L10n.t("a11y.close"))
                        }
                    }
            }
            .environmentObject(clock)
            .environmentObject(language)
            .preferredColorScheme(.dark)
        }
        .onAppear { clock.refreshCapabilities() }
        .onChange(of: language.code) { _, _ in
            clock.relocalize()
        }
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
        VStack(spacing: 8) {
            if showSessionChrome {
                modePicker
                HStack(spacing: 10) {
                    languagePicker
                    Spacer(minLength: 0)
                    soundToggleButton
                    settingsButton
                }
            } else {
                HStack {
                    Spacer(minLength: 0)
                    settingsButton
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var modePicker: some View {
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
                        .font(Palette.display(14))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selected == mode ? Palette.gold.opacity(0.18) : Color.clear,
                            in: Capsule()
                        )
                        .overlay {
                            if selected == mode {
                                Capsule().stroke(Palette.gold.opacity(0.45), lineWidth: 1)
                            }
                        }
                        .foregroundStyle(selected == mode ? Palette.gold : Palette.ink.opacity(0.48))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(Palette.canvas.opacity(0.9), in: Capsule())
        .overlay(Capsule().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
    }

    private var soundToggleButton: some View {
        Button {
            clock.soundEnabled.toggle()
            HapticFeedback.light()
        } label: {
            Image(systemName: clock.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(Palette.canvas.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(clock.soundEnabled ? L10n.t("sound.off") : L10n.t("sound.on"))
    }

    private var settingsButton: some View {
        Button {
            showAppSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(Palette.canvas.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("settings.title"))
    }

    private var languagePicker: some View {
        HStack(spacing: 2) {
            ForEach(["en", "pl"], id: \.self) { code in
                Button {
                    language.select(code)
                    HapticFeedback.selection()
                } label: {
                    Text(code.uppercased())
                        .font(Palette.display(12))
                        .frame(minWidth: 28)
                        .padding(.vertical, 7)
                        .background(language.code == code ? Palette.gold : Color.clear, in: Capsule())
                        .foregroundStyle(language.code == code ? Color(red: 0.102, green: 0.063, blue: 0.047) : Palette.ink.opacity(0.48))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Palette.canvas.opacity(0.9), in: Capsule())
        .overlay(Capsule().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        .accessibilityLabel(L10n.t("settings.language"))
    }

    private var volumeRow: some View {
        HStack(spacing: 8) {
            Text(L10n.t("settings.volume"))
                .font(Palette.display(14))
                .foregroundStyle(Palette.ink.opacity(0.64))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Slider(value: $clock.cueVolume, in: 0...100, step: 1) { editing in
                if editing {
                    volumePreviewArmed = true
                } else if volumePreviewArmed {
                    volumePreviewArmed = false
                    clock.previewVolume()
                }
            }
            .tint(Palette.gold)
            .frame(minWidth: 0, maxWidth: .infinity)
            .disabled(!clock.soundEnabled)
            .opacity(clock.soundEnabled ? 1 : 0.4)
            Text("\(Int(clock.cueVolume))")
                .font(Palette.ui(14).monospacedDigit())
                .foregroundStyle(Palette.ink.opacity(0.64))
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var timerBlock: some View {
        VStack(spacing: 8) {
            Text(display.phaseName)
                .font(Palette.display(showSettings ? 18 : 22))
                .tracking(3)
                .foregroundStyle(Palette.color(display.tint))
            Text(display.text)
                .font(Palette.display(showSettings ? 76 : 96))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(Palette.ink)
                .accessibilityLabel("\(display.phaseName) \(display.text)")
            Text(display.detail)
                .font(Palette.ui(20))
                .foregroundStyle(Palette.ink.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay(ringCorners)
        .animation(.easeInOut(duration: 0.25), value: display.tint)
    }

    private var ringCorners: some View {
        ZStack {
            cornerMark(.topLeading)
            cornerMark(.topTrailing)
            cornerMark(.bottomLeading)
            cornerMark(.bottomTrailing)
        }
    }

    private func cornerMark(_ alignment: Alignment) -> some View {
        ZStack(alignment: alignment) {
            Color.clear
            Rectangle()
                .fill(Palette.gold)
                .frame(width: 22, height: 2)
                .offset(x: alignment == .topLeading || alignment == .bottomLeading ? 8 : -8,
                        y: alignment == .topLeading || alignment == .topTrailing ? 10 : -12)
            Rectangle()
                .fill(Palette.gold)
                .frame(width: 2, height: 22)
                .offset(x: alignment == .topLeading || alignment == .bottomLeading ? 8 : -8,
                        y: alignment == .topLeading || alignment == .topTrailing ? 10 : -12)
        }
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

    @ViewBuilder
    private var settings: some View {
        switch selected {
        case .sparring:
            sparringSettings
        case .countdown:
            countdownSettings
        case .stopwatch:
            Text(L10n.t("stopwatch.hint"))
                .font(Palette.ui(15))
                .foregroundStyle(Palette.ink.opacity(0.64))
                .multilineTextAlignment(.center)
        }
    }

    private var sparringSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            clippedHorizontalScroll(height: 58) {
                HStack(spacing: 8) {
                    preset(L10n.t("preset.tabata"), "20/10 × 8") {
                        clock.prepareSeconds = 5
                        clock.workSeconds = 20
                        clock.restSeconds = 10
                        clock.rounds = 8
                    }
                    preset(L10n.t("preset.interval"), "30/15 × 10") {
                        clock.prepareSeconds = 5
                        clock.workSeconds = 30
                        clock.restSeconds = 15
                        clock.rounds = 10
                    }
                    preset(L10n.t("preset.sparring"), "3:00 / 1:00 × 5") {
                        clock.prepareSeconds = 10
                        clock.workSeconds = 180
                        clock.restSeconds = 60
                        clock.rounds = 5
                    }
                    preset(L10n.t("preset.round"), "5:00 / 1:00 × 3") {
                        clock.prepareSeconds = 10
                        clock.workSeconds = 300
                        clock.restSeconds = 60
                        clock.rounds = 3
                    }
                }
            }
            stepRow(L10n.t("setting.prepare"), text: ClockFormat.clock(seconds: clock.prepareSeconds)) {
                clock.prepareSeconds = min(120, max(0, clock.prepareSeconds - 5))
            } increment: {
                clock.prepareSeconds = min(120, max(0, clock.prepareSeconds + 5))
            }
            stepRow(L10n.t("setting.work"), text: ClockFormat.clock(seconds: clock.workSeconds)) {
                clock.workSeconds = min(3600, max(5, clock.workSeconds - 5))
            } increment: {
                clock.workSeconds = min(3600, max(5, clock.workSeconds + 5))
            }
            stepRow(L10n.t("setting.rest"), text: ClockFormat.clock(seconds: clock.restSeconds)) {
                clock.restSeconds = min(1800, max(0, clock.restSeconds - 5))
            } increment: {
                clock.restSeconds = min(1800, max(0, clock.restSeconds + 5))
            }
            stepRow(L10n.t("setting.rounds"), text: "\(clock.rounds)") {
                clock.rounds = min(30, max(1, clock.rounds - 1))
            } increment: {
                clock.rounds = min(30, max(1, clock.rounds + 1))
            }
            Text(L10n.t("setting.total \(ClockFormat.clock(seconds: clock.sparringTotalSeconds))"))
                .font(Palette.ui(13))
                .foregroundStyle(Palette.ink.opacity(0.64))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var countdownSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            clippedHorizontalScroll(height: 58) {
                HStack(spacing: 8) {
                    preset("0:30", L10n.t("preset.countdown_half")) { clock.countdownSeconds = 30 }
                    preset("1:00", L10n.t("preset.countdown_minute")) { clock.countdownSeconds = 60 }
                    preset("3:00", L10n.t("preset.countdown_three")) { clock.countdownSeconds = 180 }
                    preset("5:00", L10n.t("preset.countdown_five")) { clock.countdownSeconds = 300 }
                    preset("10:00", L10n.t("preset.countdown_ten")) { clock.countdownSeconds = 600 }
                }
            }
            stepRow(L10n.t("setting.countdown_minutes"), text: "\(clock.countdownSeconds / 60)") {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds - 60))
            } increment: {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds + 60))
            }
            stepRow(L10n.t("setting.countdown_seconds"), text: String(format: "%02d", clock.countdownSeconds % 60)) {
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
                    .font(Palette.display(15))
                Text(subtitle)
                    .font(Palette.ui(12))
                    .foregroundStyle(Palette.ink.opacity(0.64))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.canvas.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.gold)
                    .frame(width: 3)
            }
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func stepRow(_ title: String, text: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Palette.ui(16))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            stepButton("minus", label: L10n.t("step.less"), action: decrement)
            Text(text)
                .font(Palette.ui(16).monospacedDigit())
                .frame(width: 72)
            stepButton("plus", label: L10n.t("step.more"), action: increment)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(text)
    }

    private func clippedHorizontalScroll<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                content()
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .frame(height: height)
    }

    private func stepButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticFeedback.light()
        } label: {
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(Palette.canvas.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var controls: some View {
        switch clock.runState {
        case .idle:
            Button(L10n.t("control.start")) { clock.start(mode: selected) }
                .buttonStyle(PrimaryButton(fill: Palette.color(display.tint), foreground: Palette.ink(on: display.tint)))
                .disabled(!clock.canStart(selected))
                .opacity(clock.canStart(selected) ? 1 : 0.4)
        case .running where clock.mode == .stopwatch:
            HStack(spacing: 12) {
                Button(L10n.t("control.lap")) { clock.lap() }
                    .buttonStyle(SecondaryButton())
                Button(L10n.t("control.pause")) { clock.pause() }
                    .buttonStyle(PrimaryButton(fill: Palette.ink, foreground: Color(red: 0.102, green: 0.063, blue: 0.047)))
            }
        case .running:
            HStack(spacing: 12) {
                Button(L10n.t("control.reset")) { clock.reset() }
                    .buttonStyle(SecondaryButton())
                Button(L10n.t("control.pause")) { clock.pause() }
                    .buttonStyle(PrimaryButton(fill: Palette.ink, foreground: Color(red: 0.102, green: 0.063, blue: 0.047)))
            }
        case .paused:
            HStack(spacing: 12) {
                Button(L10n.t("control.reset")) { clock.reset() }
                    .buttonStyle(SecondaryButton())
                Button(L10n.t("control.resume")) { clock.resume() }
                    .buttonStyle(PrimaryButton(fill: Palette.color(display.tint), foreground: Palette.ink(on: display.tint)))
            }
        case .finished:
            HStack(spacing: 12) {
                Button(L10n.t("control.reset")) { clock.reset() }
                    .buttonStyle(SecondaryButton())
                Button(L10n.t("control.again")) { clock.start(mode: clock.mode) }
                    .buttonStyle(PrimaryButton(fill: Palette.color("end"), foreground: Color(red: 0.102, green: 0.063, blue: 0.047)))
            }
        }
    }

    private var hints: some View {
        VStack(spacing: 8) {
            bellCredit
            Text(L10n.t("hint.background"))
                .font(Palette.ui(13))
                .foregroundStyle(Palette.ink.opacity(0.64))
                .multilineTextAlignment(.center)
            if clock.notificationStatus == .needsPrompt || clock.notificationStatus == .denied {
                Button(clock.notificationStatus == .denied
                       ? L10n.t("hint.notifications_denied")
                       : L10n.t("hint.notifications_prompt")) {
                    clock.requestNotifications()
                }
                .font(Palette.ui(13).weight(.semibold))
            }
            if showSettings, clock.liveActivitiesOff {
                Button(L10n.t("hint.live_activities")) {
                    clock.openSettings()
                }
                .font(Palette.ui(13).weight(.semibold))
                .multilineTextAlignment(.center)
            }
        }
    }

    private var bellCredit: some View {
        VStack(spacing: 2) {
            Text(L10n.t("hint.bell_credit"))
                .font(Palette.ui(13))
                .foregroundStyle(Palette.ink.opacity(0.64))
                .multilineTextAlignment(.center)
            Link(L10n.t("hint.bell_link"), destination: URL(string: "https://freesound.org/s/66952/")!)
                .font(Palette.ui(13))
        }
    }
}

private struct PrimaryButton: ButtonStyle {
    var fill: Color
    var foreground: Color = Palette.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Palette.display(20))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(fill.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
    }
}

private struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Palette.display(20))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Palette.canvas.opacity(configuration.isPressed ? 0.5 : 0.9), in: Capsule())
            .overlay(Capsule().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
    }
}
