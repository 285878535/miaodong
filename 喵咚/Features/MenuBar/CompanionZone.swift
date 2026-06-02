//
//  CompanionZone.swift
//  喵咚
//
//  陪伴信息条：今日完成 / 进行中 / 连续天数 + 猫的等级 / XP 进度条
//

import SwiftUI

struct CompanionZone: View {
    let openCount: Int
    let doneCount: Int
    let companionDays: Int

    @ObservedObject private var growth = CatGrowth.shared

    var body: some View {
        VStack(spacing: 8) {
            // 3 个 chip
            HStack(spacing: 8) {
                chip(
                    icon: "checkmark.seal.fill",
                    value: "\(doneCount)",
                    label: "今日完成",
                    accent: AppPalette.accent
                )
                chip(
                    icon: "circle.dashed",
                    value: "\(openCount)",
                    label: "进行中",
                    accent: Color(red: 0.95, green: 0.55, blue: 0.45)
                )
                chip(
                    icon: "flame.fill",
                    value: "\(growth.currentStreak)",
                    label: growth.currentStreak > 0 ? "连续\(growth.currentStreak)天" : "等待开始",
                    accent: Color(red: 0.95, green: 0.45, blue: 0.30)
                )
            }

            // 等级进度条
            levelBar
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Level bar

    private var levelBar: some View {
        HStack(spacing: 10) {
            // Lv badge
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .semibold))
                Text("Lv \(growth.level)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(AppPalette.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AppPalette.accentSoft)
            )

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.55))
                        .overlay(
                            Capsule()
                                .stroke(AppPalette.separator.opacity(0.4), lineWidth: 0.5)
                        )
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppPalette.accent, AppPalette.accentBright],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * growth.levelProgress))
                        .shadow(color: AppPalette.accent.opacity(0.35), radius: 3, x: 0, y: 0)
                        .animation(.easeOut(duration: 0.6), value: growth.levelProgress)
                }
            }
            .frame(height: 6)

            // 距离下一级
            Text("\(growth.totalXP - growth.levelRange.lower)/\(growth.levelRange.upper - growth.levelRange.lower)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(AppPalette.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - chip

    private func chip(icon: String, value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.primary)
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppPalette.secondary.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppPalette.statChipBg)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                            startPoint: .top, endPoint: .center
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.5)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.statChipStroke, lineWidth: 0.5)
        )
        .shadow(color: AppPalette.statChipShadow, radius: 6, x: 0, y: 2)
    }
}

// MARK: - 计算陪伴天数（基于首次启动日期）

enum CompanionDays {
    private static let key = "companion_install_date"

    static func days() -> Int {
        let ud = UserDefaults.standard
        let install: Date
        if let stored = ud.object(forKey: key) as? Date {
            install = stored
        } else {
            install = Date()
            ud.set(install, forKey: key)
        }
        let cal = Calendar.current
        let start = cal.startOfDay(for: install)
        let today = cal.startOfDay(for: Date())
        let diff = cal.dateComponents([.day], from: start, to: today).day ?? 0
        return max(1, diff + 1)
    }
}

#Preview {
    CompanionZone(openCount: 3, doneCount: 5, companionDays: 7)
        .padding()
        .background(AppPalette.mainBg)
}
