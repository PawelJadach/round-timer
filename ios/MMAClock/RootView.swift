import SwiftUI

struct RootView: View {
    @EnvironmentObject private var clock: TrainingClock
    @ObservedObject private var language = AppLanguage.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selected: TrainingMode = .sparring
    @State private var showAppSettings = false
    private var display: Face {
        clock.runState == .idle ? clock.previewFace(for: selected) : clock.face
    }

    private var showSettings: Bool { clock.runState == .idle }
    private var showSessionChrome: Bool { clock.runState == .idle }

    private var compactLayout: Bool { horizontalSizeClass == .compact }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: compactLayout ? 12 : 16) {
                    topBar(compact: compactLayout)
                    Spacer(minLength: compactLayout ? 4 : 12)
                    timerBlock(compact: compactLayout)
                    if clock.mode == .stopwatch, clock.runState != .idle, !clock.laps.isEmpty {
                        lapsList
                    }
                    if showSettings, selected != .stopwatch {
                        settings(compact: compactLayout)
                    }
                    Spacer(minLength: compactLayout ? 8 : 16)
                    if !(showSettings && compactLayout) {
                        hints
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: [.horizontal])
            .safeAreaInset(edge: .bottom, spacing: 0) {
                controls(compact: compactLayout)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .background(Palette.background.opacity(0.94))
            }
        }
        .overlay {
            Circle()
                .fill(Palette.color(display.tint).opacity(0.42))
                .frame(width: 460, height: 460)
                .blur(radius: 90)
                .offset(y: -80)
                .allowsHitTesting(false)
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
        .onAppear {
            language.syncWithSystemIfNeeded()
            clock.refreshCapabilities()
        }
        .onChange(of: language.code) { _, _ in
            clock.relocalize()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                language.syncWithSystemIfNeeded()
                clock.catchUp()
                clock.refreshCapabilities()
            } else if phase == .background {
                clock.prepareForBackground()
            }
        }
    }

    private func topBar(compact: Bool) -> some View {
        HStack(spacing: 8) {
            if showSessionChrome {
                modePicker(compact: compact)
            } else {
                Spacer(minLength: 0)
            }
            settingsButton
        }
        .frame(maxWidth: .infinity)
    }

    private func modePicker(compact: Bool) -> some View {
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
                        .font(Palette.display(compact ? 13 : 14))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 8 : 10)
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

    private var settingsButton: some View {
        Button {
            showAppSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(Palette.canvas.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("settings.title"))
    }

    private func timerBlock(compact: Bool) -> some View {
        let idle = showSettings
        let stopwatchSession = selected == .stopwatch && idle
        return VStack(spacing: idle ? 6 : 10) {
            if !stopwatchSession || clock.runState != .idle {
                Text(display.phaseName)
                    .font(Palette.display(idle ? 18 : 22))
                    .tracking(3)
                    .foregroundStyle(Palette.color(display.tint))
            }
            Text(display.text)
                .font(Palette.display(stopwatchSession ? 96 : (idle ? 84 : 96)))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(Palette.ink)
                .accessibilityLabel("\(display.phaseName) \(display.text)")
            if !(stopwatchSession && display.detail.isEmpty) {
                Text(display.detail)
                    .font(Palette.ui(idle ? 18 : 20))
                    .foregroundStyle(Palette.ink.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, idle ? 12 : 8)
        .overlay(ringCorners.allowsHitTesting(false))
        .clipped()
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
    private func settings(compact: Bool) -> some View {
        switch selected {
        case .sparring:
            sparringSettings(compact: compact)
        case .countdown:
            countdownSettings(compact: compact)
        case .stopwatch:
            EmptyView()
        }
    }

    private func sparringSettings(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            stepRow(L10n.t("setting.prepare"), text: ClockFormat.clock(seconds: clock.prepareSeconds), compact: compact) {
                clock.prepareSeconds = min(120, max(0, clock.prepareSeconds - 5))
            } increment: {
                clock.prepareSeconds = min(120, max(0, clock.prepareSeconds + 5))
            }
            stepRow(L10n.t("setting.work"), text: ClockFormat.clock(seconds: clock.workSeconds), compact: compact) {
                clock.workSeconds = min(3600, max(5, clock.workSeconds - 5))
            } increment: {
                clock.workSeconds = min(3600, max(5, clock.workSeconds + 5))
            }
            stepRow(L10n.t("setting.rest"), text: ClockFormat.clock(seconds: clock.restSeconds), compact: compact) {
                clock.restSeconds = min(1800, max(0, clock.restSeconds - 5))
            } increment: {
                clock.restSeconds = min(1800, max(0, clock.restSeconds + 5))
            }
            stepRow(L10n.t("setting.rounds"), text: "\(clock.rounds)", compact: compact) {
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

    private func countdownSettings(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            stepRow(L10n.t("setting.countdown_minutes"), text: "\(clock.countdownSeconds / 60)", compact: compact) {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds - 60))
            } increment: {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds + 60))
            }
            stepRow(L10n.t("setting.countdown_seconds"), text: String(format: "%02d", clock.countdownSeconds % 60), compact: compact) {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds - 5))
            } increment: {
                clock.countdownSeconds = min(86_400, max(0, clock.countdownSeconds + 5))
            }
        }
    }

    private func stepRow(_ title: String, text: String, compact: Bool = false, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
        let controlSize: CGFloat = 34
        return HStack(spacing: 4) {
            Text(title)
                .font(Palette.ui(compact ? 15 : 16))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .layoutPriority(1)
            Spacer(minLength: 0)
            stepButton("minus", label: L10n.t("step.less"), size: controlSize, action: decrement)
            Text(text)
                .font(Palette.ui(compact ? 15 : 16).monospacedDigit())
                .frame(width: compact ? 58 : 64)
            stepButton("plus", label: L10n.t("step.more"), size: controlSize, action: increment)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(text)
    }

    private func stepButton(_ systemName: String, label: String, size: CGFloat = 40, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticFeedback.light()
        } label: {
            Image(systemName: systemName)
                .font(.headline.weight(.semibold))
                .frame(width: size, height: size)
                .background(Palette.canvas.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func controls(compact: Bool) -> some View {
        switch clock.runState {
        case .idle:
            Button(L10n.t("control.start")) { clock.start(mode: selected) }
                .buttonStyle(PrimaryButton(fill: Palette.color(display.tint), foreground: Palette.ink(on: display.tint), height: compact ? 52 : 60))
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
    var height: CGFloat = 60

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Palette.display(20))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
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
