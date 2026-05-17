//
//  CompanionZone.swift
//  喵咚
//
//  陪伴信息条：今日完成 / 进行中 / 陪伴天数 / 当前时段
//  解决"主体空一大片"的问题，同时强化"桌宠陪伴"感。
//

import SwiftUI

struct CompanionZone: View {
    let openCount: Int
    let doneCount: Int
    let companionDays: Int

    var body: some View {
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
                icon: "heart.fill",
                value: "\(companionDays)",
                label: "陪伴天",
                accent: AppPalette.pink
            )
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppPalette.statChipBg)
                // 顶部高光
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
