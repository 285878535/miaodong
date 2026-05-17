//
//  AlertView.swift
//  喵咚
//
//  到时提醒弹窗（按设计图：奶白米色背景 + 像素猫 + 三按钮 + 稍后选项 popover）
//

import SwiftUI

struct AlertView: View {
    let title: String
    let timeText: String
    let offsetText: String?
    let intervalText: String?
    let onComplete: () -> Void
    let onSnooze: (TimeInterval) -> Void
    let onDismiss: () -> Void

    @State private var snoozePopoverShown = false

    private let snoozeOptions: [(label: String, seconds: TimeInterval)] = [
        ("5 分钟后", 5 * 60),
        ("10 分钟后", 10 * 60),
        ("30 分钟后", 30 * 60),
        ("1 小时后", 60 * 60)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            closeButton
        }
        .background(
            ZStack {
                AppPalette.mainBg
                SparkleBackground()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppPalette.primary.opacity(0.14), radius: 18, x: 0, y: 8)
        .preferredColorScheme(.light)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部 "时间到啦！" 居中
            HStack(spacing: 5) {
                Spacer()
                Image(systemName: "alarm.fill")
                    .foregroundStyle(Color(red: 1.00, green: 0.36, blue: 0.36))
                    .font(.system(size: 12, weight: .bold))
                Text("时间到啦！")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 1.00, green: 0.36, blue: 0.36))
                Spacer()
            }
            .padding(.top, 2)

            // 主体：像素猫 + 信息
            HStack(alignment: .center, spacing: 14) {
                PixelCatWithBellView()
                    .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppPalette.primary)
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppPalette.primary)
                            .lineLimit(1)
                    }
                    Text(timeText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppPalette.secondary)
                    if let offsetText {
                        Text(offsetText)
                            .font(.system(size: 11))
                            .foregroundStyle(AppPalette.secondary.opacity(0.85))
                    } else if let intervalText {
                        Text(intervalText)
                            .font(.system(size: 11))
                            .foregroundStyle(AppPalette.secondary.opacity(0.85))
                    }
                }
                Spacer(minLength: 0)
            }

            buttonRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - 按钮行

    private var buttonRow: some View {
        HStack(spacing: 8) {
            primaryButton(title: "完成", icon: "checkmark", action: onComplete)

            snoozeButton

            secondaryButton(title: "忽略", icon: "xmark", action: onDismiss)
        }
    }

    private func primaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(AppPalette.accent)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(AppPalette.primary.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(AppPalette.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.primary.opacity(0.12), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// 稍后提醒 —— 普通 Button + 自定义 popover（避免 SwiftUI Menu 把 label 颜色弄丢）
    private var snoozeButton: some View {
        Button {
            snoozePopoverShown = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "clock")
                    .font(.system(size: 11, weight: .bold))
                Text("稍后提醒")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(AppPalette.primary.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(AppPalette.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppPalette.primary.opacity(0.12), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $snoozePopoverShown, arrowEdge: .top) {
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(AppPalette.secondary)
                    Text("稍后提醒")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppPalette.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)
                Rectangle()
                    .fill(AppPalette.separator.opacity(0.6))
                    .frame(height: 0.5)

                ForEach(snoozeOptions, id: \.label) { opt in
                    Button {
                        snoozePopoverShown = false
                        onSnooze(opt.seconds)
                    } label: {
                        HStack {
                            Text(opt.label)
                                .font(.system(size: 12))
                                .foregroundStyle(AppPalette.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Rectangle()
                    .fill(AppPalette.separator.opacity(0.6))
                    .frame(height: 0.5)
                HStack {
                    Text("自定义时间...")
                        .font(.system(size: 12))
                        .foregroundStyle(AppPalette.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .frame(width: 140)
            .background(AppPalette.white)
            .preferredColorScheme(.light)
        }
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppPalette.secondary.opacity(0.55))
                .padding(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 像素猫占位（等设计图正式 PNG 后用 Image("pixel_cat_alert") 替换）

private struct PixelCatWithBellView: View {
    var body: some View {
        ZStack {
            Image(systemName: "cat")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(AppPalette.primary)

            // 腮红
            HStack(spacing: 18) {
                Circle().fill(Color.pink.opacity(0.45)).frame(width: 4, height: 4)
                Circle().fill(Color.pink.opacity(0.45)).frame(width: 4, height: 4)
            }
            .offset(y: 2)

            // 铃铛
            Image(systemName: "bell.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.orange)
                .offset(x: 20, y: 14)
                .rotationEffect(.degrees(20), anchor: .top)
        }
    }
}

// MARK: - 装饰星点

private struct SparkleBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                sparkle(at: CGPoint(x: 16, y: 22), color: .orange, size: 9, rotation: 15)
                sparkle(at: CGPoint(x: geo.size.width - 22, y: 24), color: .pink, size: 10, rotation: -20)
                sparkle(at: CGPoint(x: geo.size.width - 36, y: geo.size.height / 2), color: .yellow, size: 9, rotation: 30)
                sparkle(at: CGPoint(x: 24, y: geo.size.height - 42), color: .blue.opacity(0.8), size: 8, rotation: -10)
                sparkle(at: CGPoint(x: geo.size.width / 2, y: 12), color: .orange.opacity(0.7), size: 7, rotation: 45)
            }
        }
    }

    private func sparkle(at pos: CGPoint, color: Color, size: CGFloat, rotation: Double) -> some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(rotation))
            .position(pos)
    }
}
