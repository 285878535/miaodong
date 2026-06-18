//
//  Enums.swift
//  喵咚
//

import Foundation
import SwiftUI

enum Priority: String, Codable, CaseIterable, Sendable {
    case low, medium, high, urgent

    var label: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .urgent: return "紧急"
        }
    }

    var color: Color {
        switch self {
        case .urgent: return Color(red: 1.00, green: 0.31, blue: 0.31)
        case .high:   return Color(red: 1.00, green: 0.55, blue: 0.20)
        case .medium: return Color(red: 0.55, green: 0.45, blue: 0.95)
        case .low:    return Color(red: 0.40, green: 0.70, blue: 0.95)
        }
    }

    var icon: String {
        switch self {
        case .urgent: return "exclamationmark.triangle.fill"
        case .high:   return "arrow.up.circle.fill"
        case .medium: return "minus.circle.fill"
        case .low:    return "arrow.down.circle.fill"
        }
    }
}

/// 图标显示模式
/// - menuBar：系统状态栏
/// - notch：刘海屏的"灵动岛"位置（贴刘海正下方居中；非刘海屏退化为屏幕顶端居中）
/// - floating：自由悬浮，用户可拖到任意位置
enum IconDisplayMode: String, CaseIterable, Sendable {
    case menuBar  = "menuBar"
    case notch    = "notch"
    case floating = "floating"

    var label: String {
        switch self {
        case .menuBar:  return "状态栏"
        case .notch:    return "灵动岛位置（刘海屏）"
        case .floating: return "悬浮窗（可拖动）"
        }
    }
}

/// 模式变更通知（SettingsView 改值后发出，AppDelegate 监听并重新装载）
extension Notification.Name {
    static let iconDisplayModeDidChange = Notification.Name("iconDisplayModeDidChange")
    static let accentColorDidChange     = Notification.Name("accentColorDidChange")
    /// 悬浮图标大小变更（SettingsView 拖动滑块时发出，FloatingIconController 监听并按新尺寸重建）
    static let floatingIconSizeDidChange = Notification.Name("floatingIconSizeDidChange")
}

enum Tag: String, Codable, CaseIterable, Sendable {
    case work, study, exercise, health, hobby, social, shopping
    case cleaning, finance, planning, creative, rest, learning, family, personal, other

    var label: String {
        switch self {
        case .work:     return "工作"
        case .study:    return "学习"
        case .exercise: return "运动"
        case .health:   return "健康"
        case .hobby:    return "爱好"
        case .social:   return "社交"
        case .shopping: return "购物"
        case .cleaning: return "清洁"
        case .finance:  return "财务"
        case .planning: return "计划"
        case .creative: return "创意"
        case .rest:     return "休息"
        case .learning: return "自学"
        case .family:   return "家庭"
        case .personal: return "个人"
        case .other:    return "其他"
        }
    }

    var icon: String {
        switch self {
        case .work:     return "briefcase.fill"
        case .study:    return "book.fill"
        case .exercise: return "figure.run"
        case .health:   return "heart.fill"
        case .hobby:    return "paintbrush.fill"
        case .social:   return "person.2.fill"
        case .shopping: return "cart.fill"
        case .cleaning: return "sparkles"
        case .finance:  return "creditcard.fill"
        case .planning: return "calendar"
        case .creative: return "lightbulb.fill"
        case .rest:     return "bed.double.fill"
        case .learning: return "book.closed.fill"
        case .family:   return "house.fill"
        case .personal: return "person.fill"
        case .other:    return "tag.fill"
        }
    }
}
