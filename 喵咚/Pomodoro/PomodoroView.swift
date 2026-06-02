//
//  PomodoroView.swift
//  喵咚
//
//  专注番茄钟视图 —— 居中大倒计时 + 像素猫 focus 动画。
//  "和你的猫一起专注 25 分钟"是核心情感主张。
//

import SwiftUI
import Combine

struct PomodoroView: View {
    @ObservedObject var session: PomodoroSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 8)

            // 主区：猫 + 倒计时
            VStack(spacing: 18) {
                catBlock
                timerBlock
                taskLabelField
            }

            Spacer(minLength: 12)

            controlsRow
            statsRow
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .frame(width: 360, height: 480)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.accent.opacity(0.18), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 12)
        .shadow(color: AppPalette.accent.opacity(0.16), radius: 22, x: 0, y: 0)
        .preferredColorScheme(.light)
    }

    // MARK: - 背景：复用 header 渐变同款（让"专注"和"猫窝"视觉同源）

    private var panelBackground: some View {
        ZStack {
            AppPalette.accentSoft
            AppPalette.headerGradient.opacity(0.65)
            RadialGradient(
                colors: [
                    AppPalette.headerCenterGlow.opacity(0.55),
                    AppPalette.headerCenterGlow.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.30),
                startRadius: 8,
                endRadius: 200
            )
            .blendMode(.screen)
            LinearGradient(
                colors: [AppPalette.accentSoft.opacity(0.85), AppPalette.accentSoft.opacity(0.0)],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.screen)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.accent)
                Text("专注模式")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppPalette.primary)
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppPalette.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(AppPalette.accentSoft.opacity(0.6)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: - 猫

    private var catBlock: some View {
        ZStack {
            // 背后柔光
            Circle()
                .fill(AppPalette.headerCenterGlow.opacity(0.30))
                .frame(width: 130, height: 130)
                .blur(radius: 22)
            Circle()
                .fill(AppPalette.cloudPurple.opacity(0.35))
                .frame(width: 96, height: 96)
                .blur(radius: 14)

            PomodoroFocusCat(running: session.state == .running)
                .frame(width: 96, height: 80)
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
        }
        .frame(height: 130)
    }

    // MARK: - 倒计时

    private var timerBlock: some View {
        VStack(spacing: 4) {
            Text(formatRemaining(session.remainingSeconds))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppPalette.primary)
            Text(stateCaption)
                .font(.system(size: 11))
                .foregroundStyle(AppPalette.secondary)
        }
    }

    private var stateCaption: String {
        switch session.state {
        case .idle:     return "准备好了就开始吧～"
        case .running:  return "专注中，加油！"
        case .paused:   return "暂停中"
        case .finished: return "🎉 完成一个番茄钟"
        }
    }

    // MARK: - 任务标签

    private var taskLabelField: some View {
        HStack(spacing: 6) {
            Image(systemName: "tag")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppPalette.secondary)
            TextField("正在专注的事（可选）", text: $session.taskLabel)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .disabled(session.state == .running)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.separator.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - 控制按钮

    private var controlsRow: some View {
        HStack(spacing: 12) {
            switch session.state {
            case .idle, .finished:
                primaryButton(label: session.state == .finished ? "再来一次" : "开始", icon: "play.fill") {
                    session.start()
                }
            case .running:
                secondaryButton(label: "暂停", icon: "pause.fill") {
                    session.pause()
                }
                secondaryButton(label: "结束", icon: "stop.fill") {
                    session.stop()
                }
            case .paused:
                primaryButton(label: "继续", icon: "play.fill") {
                    session.start()
                }
                secondaryButton(label: "结束", icon: "stop.fill") {
                    session.stop()
                }
            }
        }
        .padding(.top, 6)
    }

    private func primaryButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(AppPalette.accent)
            )
            .shadow(color: AppPalette.accent.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppPalette.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(.white.opacity(0.7))
            )
            .overlay(
                Capsule().stroke(AppPalette.separator.opacity(0.5), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 统计行

    private var statsRow: some View {
        HStack(spacing: 16) {
            statItem(label: "今日", value: "\(session.todayCount) 🍅")
            statItem(label: "累计", value: humanMinutes(session.totalMinutes))
            Spacer()
            Text("\(session.focusMinutes) 分钟")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.65)))
        }
        .padding(.top, 12)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(AppPalette.secondary.opacity(0.85))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.primary)
                .monospacedDigit()
        }
    }

    // MARK: - 格式化

    private func formatRemaining(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }

    private func humanMinutes(_ m: Int) -> String {
        if m >= 60 {
            let h = m / 60
            let r = m % 60
            return r == 0 ? "\(h) 小时" : "\(h) 时 \(r) 分"
        }
        return "\(m) 分"
    }
}

// MARK: - 专注期循环 focus1-8，闲置期定格 focus1

private struct PomodoroFocusCat: View {
    let running: Bool

    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.32, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let img = loadFrame(named: "focus\(frameIndex + 1)") {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: "cat.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(AppPalette.accent)
            }
        }
        .onReceive(timer) { _ in
            guard running else { return }
            frameIndex = (frameIndex + 1) % 8
        }
        .onChange(of: running) { _, isRunning in
            if !isRunning { frameIndex = 0 }
        }
    }

    private func loadFrame(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(name).png")
        return NSImage(contentsOf: sourceURL)
    }
}
