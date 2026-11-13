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
    private var sessionActive: Bool { clock.runState != .idle }

    private var compactLayout: Bool { horizontalSizeClass == .compact }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: compactLayout ? 12 : 16) {
                    if showSessionChrome {
                        topBar(compact: compactLayout)
                    }
                    if sessionActive {
                        Spacer(minLength: compactLayout ? 48 : 64)
                    } else {
                        Spacer(minLength: compactLayout ? 20 : 28)
                    }
                    if let phase = roundsHighlightPhase, sessionActive, clock.mode == .sparring {
                        roundsPhaseIndicator(current: phase, compact: compactLayout)
                    }
                    timerBlock(compact: compactLayout)
                    if sessionActive {
                        Spacer(minLength: compactLayout ? 48 : 64)
                    }
                    if !sessionActive, clock.mode == .stopwatch, !clock.laps.isEmpty {
                        lapsList
                    }
                    if showSettings, selected != .stopwatch {
                        settings(compact: compactLayout)
                    }
                    if !sessionActive {
                        Spacer(minLength: compactLayout ? 8 : 16)
                        if !(showSettings && compactLayout) {
                            hints
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, sessionActive ? 0 : 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, minHeight: sessionActive ? scrollMinHeight(compact: compactLayout) : nil, alignment: .center)
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
            if sessionActive, clock.mode == .sparring, clock.runState != .finished,
               ["prepare", "work", "rest"].contains(display.tint) {
                Circle()
                    .fill(Palette.color(display.tint).opacity(0.38))
                    .frame(width: 460, height: 460)
                    .blur(radius: 90)
                    .offset(y: -80)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.25), value: display.tint)
            } else if !sessionActive {
                Circle()
                    .fill(Palette.color(display.tint).opacity(0.42))
                    .frame(width: 460, height: 460)
                    .blur(radius: 90)
                    .offset(y: -80)
                    .allowsHitTesting(false)
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
        let previewMode = idle ? selected : clock.mode
        let stopwatchSession = previewMode == .stopwatch && idle
        let showDetail = shouldShowTimerDetail(for: previewMode)
        let showPhaseTitle = !stopwatchSession && (idle || (previewMode == .sparring && clock.runState != .finished))
        return VStack(spacing: idle ? 6 : 10) {
            if showPhaseTitle {
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
            if showDetail {
                Text(display.detail)
                    .font(Palette.ui(idle ? 18 : 20))
                    .foregroundStyle(Palette.ink.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, idle ? 12 : 8)
        .animation(.easeInOut(duration: 0.25), value: display.tint)
    }

    private func shouldShowTimerDetail(for mode: TrainingMode) -> Bool {
        guard !display.detail.isEmpty else { return false }
        if sessionActive {
            guard mode == .sparring, clock.runState != .finished else { return false }
            return display.tint == "work" || display.tint == "rest"
        }
        if mode == .stopwatch { return false }
        if mode == .countdown {
            return !(showSettings && clock.countdownSeconds >= 5)
        }
        return true
    }

    private func scrollMinHeight(compact: Bool) -> CGFloat {
        compact ? 520 : 600
    }

    private var roundsHighlightPhase: String? {
        if showSettings, selected == .sparring {
            let tint = clock.previewFace(for: .sparring).tint
            return ["prepare", "work", "rest"].contains(tint) ? tint : nil
        }
        if sessionActive, clock.mode == .sparring, clock.runState != .finished {
            let tint = display.tint
            return ["prepare", "work", "rest"].contains(tint) ? tint : nil
        }
        return nil
    }

    private func roundsPhaseIndicator(current: String, compact: Bool) -> some View {
        HStack(spacing: 6) {
            roundsPhaseChip("prepare", title: L10n.t("setting.prepare"), current: current, compact: compact)
            roundsPhaseChip("work", title: L10n.t("setting.work"), current: current, compact: compact)
            roundsPhaseChip("rest", title: L10n.t("setting.rest"), current: current, compact: compact)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t(current == "prepare" ? "phase.prepare" : current == "work" ? "phase.work" : "phase.rest"))
    }

    private func roundsPhaseChip(_ phase: String, title: String, current: String, compact: Bool) -> some View {
        let isCurrent = phase == current
        return Text(title)
            .font(Palette.ui(compact ? 12 : 13))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 7 : 8)
            .foregroundStyle(isCurrent ? Palette.ink(on: phase) : Palette.ink.opacity(0.55))
            .background(Palette.color(phase).opacity(isCurrent ? 0.92 : 0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Palette.ink.opacity(0.35), lineWidth: 1)
                }
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

    private var presetColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
    }

    private func sparringSettings(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            LazyVGrid(columns: presetColumns, spacing: 6) {
                preset(L10n.t("preset.interval"), "30/15 × 10", compact: compact) {
                    clock.prepareSeconds = 5
                    clock.workSeconds = 30
                    clock.restSeconds = 15
                    clock.rounds = 10
                }
                preset(L10n.t("preset.sparring"), "3:00 / 1:00 × 5", compact: compact) {
                    clock.prepareSeconds = 10
                    clock.workSeconds = 180
                    clock.restSeconds = 60
                    clock.rounds = 5
                }
            }
            .padding(.bottom, compact ? 10 : 14)
            if let phase = roundsHighlightPhase {
                roundsPhaseIndicator(current: phase, compact: compact)
                    .padding(.bottom, compact ? 4 : 6)
            }
            sparringStepRow(phase: "prepare", title: L10n.t("setting.prepare"), text: ClockFormat.clock(seconds: clock.prepareSeconds), compact: compact) {
                clock.prepareSeconds = min(120, max(0, clock.prepareSeconds - 5))
            } increment: {
                clock.prepareSeconds = min(120, max(0, clock.prepareSeconds + 5))
            }
            sparringStepRow(phase: "work", title: L10n.t("setting.work"), text: ClockFormat.clock(seconds: clock.workSeconds), compact: compact) {
                clock.workSeconds = min(3600, max(5, clock.workSeconds - 5))
            } increment: {
                clock.workSeconds = min(3600, max(5, clock.workSeconds + 5))
            }
            sparringStepRow(phase: "rest", title: L10n.t("setting.rest"), text: ClockFormat.clock(seconds: clock.restSeconds), compact: compact) {
                clock.restSeconds = min(1800, max(0, clock.restSeconds - 5))
            } increment: {
                clock.restSeconds = min(1800, max(0, clock.restSeconds + 5))
            }
            stepRow(L10n.t("setting.rounds"), text: "\(clock.rounds)", compact: compact) {
                clock.rounds = min(30, max(1, clock.rounds - 1))
            } increment: {
                clock.rounds = min(30, max(1, clock.rounds + 1))
            }
        }
    }

    private func preset(_ title: String, _ subtitle: String, compact: Bool = false, apply: @escaping () -> Void) -> some View {
        Button {
            apply()
            HapticFeedback.selection()
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(Palette.display(compact ? 13 : 15))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(Palette.ui(compact ? 11 : 12))
                    .foregroundStyle(Palette.ink.opacity(0.64))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 5 : 8)
            .background(Palette.canvas.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.gold.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(.plain)
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

    private func sparringStepRow(
        phase: String,
        title: String,
        text: String,
        compact: Bool = false,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        let isCurrent = roundsHighlightPhase == phase
        return stepRow(title, text: text, compact: compact, decrement: decrement, increment: increment)
            .padding(.horizontal, 6)
            .padding(.vertical, compact ? 4 : 6)
            .background(Palette.color(phase).opacity(isCurrent ? 0.26 : 0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.color(phase).opacity(isCurrent ? 0.75 : 0.28), lineWidth: isCurrent ? 1.5 : 1)
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

    @ViewBuilder
    private var hints: some View {
        let showNotifications = clock.notificationStatus == .needsPrompt || clock.notificationStatus == .denied
        if showNotifications || (showSettings && clock.liveActivitiesOff) {
            VStack(spacing: 8) {
            if showNotifications {
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
