//
//  TodoRowView.swift
//  喵咚
//

import SwiftUI

struct TodoRowView: View {
    @ObservedObject var todo: Todo
    var onToggle: () -> Void = {}
    var onEdit: () -> Void = {}
    /// 行尾装饰小猫的心情；nil = 不显示
    var trailingMood: CatMood? = nil

    /// 点击完成后的过渡状态
    @State private var pendingComplete: Bool = false
    /// 行体悬停态
    @State private var bodyHovered: Bool = false
    /// checkbox 悬停态
    @State private var checkHovered: Bool = false

    private var visualCompleted: Bool { todo.isCompleted || pendingComplete }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            checkbox
            editableBody
            Spacer(minLength: 0)
            if let mood = trailingMood {
                PixelCatView(pixel: 1.8, mood: visualCompleted ? .sleep : mood)
                    .opacity(visualCompleted ? 0.45 : 0.95)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .opacity(pendingComplete ? 0.55 : 1)
        .animation(.easeOut(duration: 0.4), value: pendingComplete)
    }

    // MARK: - macOS 风格 checkbox（28×28 命中区，视觉 18×18，带内阴影 / hover）

    private var checkbox: some View {
        Button(action: tap) {
            ZStack {
                Color.clear
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())

                ZStack {
                    // 底
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            visualCompleted
                            ? LinearGradient(
                                colors: [AppPalette.accentBright, AppPalette.accent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [Color.white, AppPalette.mainBg],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    // 描边
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            visualCompleted
                            ? AppPalette.accent.opacity(0.8)
                            : (checkHovered ? AppPalette.accent.opacity(0.7) : AppPalette.primary.opacity(0.22)),
                            lineWidth: visualCompleted ? 1.0 : 1.2
                        )
                    // 完成的勾
                    if visualCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 0.5, x: 0, y: 0.5)
                    }
                }
                .frame(width: 18, height: 18)
                .shadow(color: visualCompleted ? AppPalette.accent.opacity(0.35) : .clear, radius: 4, x: 0, y: 1)
                .scaleEffect(checkHovered ? 1.06 : 1.0)
                .animation(.easeOut(duration: 0.24), value: checkHovered)
                .animation(.spring(response: 0.56, dampingFraction: 0.6), value: visualCompleted)
            }
        }
        .buttonStyle(.plain)
        .onHover { checkHovered = $0 }
        .help(visualCompleted ? "标记为未完成" : "标记为完成")
    }

    // MARK: - 可编辑标题 / meta

    private var editableBody: some View {
        Button(action: { onEdit() }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(todo.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(visualCompleted ? AppPalette.secondary.opacity(0.55) : AppPalette.primary)
                        .strikethrough(visualCompleted, color: AppPalette.secondary.opacity(0.5))
                        .lineLimit(1)
                }
                metaLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(bodyHovered ? AppPalette.accentSoft.opacity(0.50) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { bodyHovered = $0 }
        .help("点击编辑")
    }

    // MARK: - 时间 / 提前 / 间隔 chip

    @ViewBuilder
    private var metaLine: some View {
        if let due = todo.dueDate {
            VStack(alignment: .leading, spacing: 3) {
                // 第一行：时间 + 提前提醒
                HStack(spacing: 6) {
                    if let snooze = todo.snoozeUntil {
                        metaChip(systemName: "clock.badge", text: snoozeTimeLabel(for: snooze))
                        metaChip(systemName: "bell.badge", text: snoozeRemainingLabel(for: snooze))
                    } else {
                        metaChip(systemName: "clock", text: timeLabel(for: due))
                        if todo.notifyOffsetSeconds > 0 {
                            metaChip(systemName: "bell", text: "提前 \(humanDuration(todo.notifyOffsetSeconds))")
                        }
                    }
                }

                // 第二行：重复间隔（有才显示）
                if let interval = todo.repeatIntervalSeconds {
                    metaChip(systemName: "timer", text: "间隔 \(humanDuration(interval))")
                }
            }
        }
    }

    private func metaChip(systemName: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppPalette.accent.opacity(0.85))
            Text(text)
                .font(.system(size: 10.5))
                .foregroundStyle(AppPalette.secondary)
        }
    }

    // MARK: - 点击

    private func tap() {
        if todo.isCompleted {
            onToggle()
            return
        }
        withAnimation(.easeIn(duration: 0.30)) {
            pendingComplete = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onToggle()
        }
    }

    private func timeLabel(for due: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")

        if todo.isRecurring, let pattern = todo.recurringPattern {
            f.dateFormat = "HH:mm"
            return "\(recurringLabel(pattern)) \(f.string(from: due))"
        }
        if cal.isDateInToday(due) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInTomorrow(due) {
            f.dateFormat = "明天 HH:mm"
        } else {
            f.dateFormat = "M月d日 HH:mm"
        }
        return f.string(from: due)
    }

    private func snoozeTimeLabel(for snooze: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(snooze) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInTomorrow(snooze) {
            f.dateFormat = "明天 HH:mm"
        } else {
            f.dateFormat = "M月d日 HH:mm"
        }
        return "稍后 \(f.string(from: snooze))"
    }

    private func snoozeRemainingLabel(for snooze: Date) -> String {
        let remaining = snooze.timeIntervalSince(Date())
        if remaining <= 0 { return "稍后提醒已到" }
        if remaining < 60 { return "\(max(1, Int(ceil(remaining)))) 秒后提醒" }
        if remaining < 3600 { return "\(max(1, Int(ceil(remaining / 60)))) 分钟后提醒" }
        return "\(max(1, Int(ceil(remaining / 3600)))) 小时后提醒"
    }

    private func recurringLabel(_ pattern: String) -> String {
        if pattern == "daily" { return "每天" }
        if pattern == "weekdays" { return "工作日" }
        if pattern.hasPrefix("weekly:") { return "每周" }
        if pattern.hasPrefix("monthly:") { return "每月" }
        return "重复"
    }

    private func humanDuration(_ seconds: Int) -> String {
        if seconds >= 86_400, seconds % 86_400 == 0 { return "\(seconds / 86_400) 天" }
        if seconds >= 3600, seconds % 3600 == 0 { return "\(seconds / 3600) 小时" }
        if seconds >= 60, seconds % 60 == 0 { return "\(seconds / 60) 分钟" }
        return "\(seconds) 秒"
    }
}
