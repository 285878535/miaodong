//
//  AppPalette.swift
//  喵咚
//
//  品牌配色 —— 夜晚紫色调（顶部 header）+ 奶白主体 + 粉色 / 紫色点缀
//  设计参考：Raycast / Arc / Notion Calendar / CleanShot X
//

import SwiftUI

// MARK: - 主题色预设

enum ThemeColor: String, CaseIterable {
    case purple, blue, pink, orange, green

    var label: String {
        switch self {
        case .purple: return "紫色"
        case .blue:   return "蓝色"
        case .pink:   return "粉色"
        case .orange: return "橙色"
        case .green:  return "绿色"
        }
    }

    var accent: Color {
        switch self {
        case .purple: return Color(red: 0.545, green: 0.486, blue: 1.00)
        case .blue:   return Color(red: 0.27,  green: 0.52,  blue: 0.96)
        case .pink:   return Color(red: 0.92,  green: 0.38,  blue: 0.62)
        case .orange: return Color(red: 0.95,  green: 0.54,  blue: 0.22)
        case .green:  return Color(red: 0.22,  green: 0.70,  blue: 0.44)
        }
    }

    var accentBright: Color {
        switch self {
        case .purple: return Color(red: 0.643, green: 0.596, blue: 1.00)
        case .blue:   return Color(red: 0.46,  green: 0.66,  blue: 1.00)
        case .pink:   return Color(red: 1.00,  green: 0.55,  blue: 0.76)
        case .orange: return Color(red: 1.00,  green: 0.70,  blue: 0.40)
        case .green:  return Color(red: 0.38,  green: 0.84,  blue: 0.58)
        }
    }

    var accentSoft: Color {
        switch self {
        case .purple: return Color(red: 0.94, green: 0.92, blue: 1.00)
        case .blue:   return Color(red: 0.90, green: 0.94, blue: 1.00)
        case .pink:   return Color(red: 1.00, green: 0.91, blue: 0.95)
        case .orange: return Color(red: 1.00, green: 0.95, blue: 0.89)
        case .green:  return Color(red: 0.89, green: 0.97, blue: 0.92)
        }
    }

    // MARK: - 夜色氛围层（跟随主题切换）

    /// header 三段渐变深色调（从上到下 / 对角分布）
    var headerStops: (Color, Color, Color) {
        switch self {
        case .purple:
            return (
                Color(red: 0.176, green: 0.149, blue: 0.220),
                Color(red: 0.218, green: 0.180, blue: 0.330),
                Color(red: 0.196, green: 0.169, blue: 0.270)
            )
        case .blue:
            return (
                Color(red: 0.090, green: 0.150, blue: 0.270),
                Color(red: 0.130, green: 0.200, blue: 0.380),
                Color(red: 0.105, green: 0.175, blue: 0.310)
            )
        case .pink:
            return (
                Color(red: 0.220, green: 0.135, blue: 0.205),
                Color(red: 0.320, green: 0.165, blue: 0.270),
                Color(red: 0.260, green: 0.145, blue: 0.225)
            )
        case .orange:
            return (
                Color(red: 0.240, green: 0.155, blue: 0.115),
                Color(red: 0.340, green: 0.205, blue: 0.130),
                Color(red: 0.275, green: 0.175, blue: 0.115)
            )
        case .green:
            return (
                Color(red: 0.085, green: 0.180, blue: 0.140),
                Color(red: 0.120, green: 0.245, blue: 0.185),
                Color(red: 0.100, green: 0.205, blue: 0.160)
            )
        }
    }

    /// header 中央 radial 辉光
    var centerGlow: Color {
        switch self {
        case .purple: return Color(red: 0.55, green: 0.45, blue: 0.85)
        case .blue:   return Color(red: 0.40, green: 0.62, blue: 0.96)
        case .pink:   return Color(red: 0.92, green: 0.55, blue: 0.74)
        case .orange: return Color(red: 0.98, green: 0.66, blue: 0.36)
        case .green:  return Color(red: 0.38, green: 0.82, blue: 0.55)
        }
    }

    /// 小猫窝：顶 / 底 / halo
    var bowlTop: Color {
        switch self {
        case .purple: return Color(red: 0.42, green: 0.34, blue: 0.58)
        case .blue:   return Color(red: 0.26, green: 0.42, blue: 0.66)
        case .pink:   return Color(red: 0.56, green: 0.32, blue: 0.46)
        case .orange: return Color(red: 0.55, green: 0.36, blue: 0.22)
        case .green:  return Color(red: 0.26, green: 0.52, blue: 0.36)
        }
    }

    var bowlBottom: Color {
        switch self {
        case .purple: return Color(red: 0.22, green: 0.17, blue: 0.34)
        case .blue:   return Color(red: 0.12, green: 0.20, blue: 0.40)
        case .pink:   return Color(red: 0.30, green: 0.16, blue: 0.24)
        case .orange: return Color(red: 0.28, green: 0.16, blue: 0.10)
        case .green:  return Color(red: 0.12, green: 0.28, blue: 0.20)
        }
    }

    var bowlHalo: Color {
        switch self {
        case .purple: return Color(red: 0.60, green: 0.50, blue: 0.90)
        case .blue:   return Color(red: 0.45, green: 0.68, blue: 0.98)
        case .pink:   return Color(red: 0.96, green: 0.55, blue: 0.78)
        case .orange: return Color(red: 1.00, green: 0.66, blue: 0.40)
        case .green:  return Color(red: 0.45, green: 0.85, blue: 0.60)
        }
    }

    /// 云雾三色（主 / 副 / 第三色）
    var cloudPrimary: Color {
        switch self {
        case .purple: return Color(red: 0.62, green: 0.50, blue: 0.95)
        case .blue:   return Color(red: 0.40, green: 0.62, blue: 0.96)
        case .pink:   return Color(red: 0.95, green: 0.55, blue: 0.75)
        case .orange: return Color(red: 0.98, green: 0.62, blue: 0.36)
        case .green:  return Color(red: 0.40, green: 0.82, blue: 0.55)
        }
    }

    var cloudSecondary: Color {
        switch self {
        case .purple: return Color(red: 0.85, green: 0.55, blue: 0.85)
        case .blue:   return Color(red: 0.55, green: 0.80, blue: 0.96)
        case .pink:   return Color(red: 1.00, green: 0.70, blue: 0.82)
        case .orange: return Color(red: 1.00, green: 0.78, blue: 0.55)
        case .green:  return Color(red: 0.58, green: 0.92, blue: 0.72)
        }
    }

    var cloudTertiary: Color {
        switch self {
        case .purple: return Color(red: 0.40, green: 0.42, blue: 0.85)
        case .blue:   return Color(red: 0.28, green: 0.50, blue: 0.85)
        case .pink:   return Color(red: 0.68, green: 0.40, blue: 0.72)
        case .orange: return Color(red: 0.72, green: 0.46, blue: 0.28)
        case .green:  return Color(red: 0.25, green: 0.58, blue: 0.42)
        }
    }

    /// header → body 雾过渡色
    var headerToBodyFade: Color {
        switch self {
        case .purple: return Color(red: 0.30, green: 0.25, blue: 0.44)
        case .blue:   return Color(red: 0.18, green: 0.30, blue: 0.50)
        case .pink:   return Color(red: 0.40, green: 0.22, blue: 0.34)
        case .orange: return Color(red: 0.38, green: 0.24, blue: 0.15)
        case .green:  return Color(red: 0.16, green: 0.36, blue: 0.26)
        }
    }

    /// 从 UserDefaults 读取当前选择
    static var current: ThemeColor {
        ThemeColor(rawValue: UserDefaults.standard.string(forKey: "accentColor") ?? "purple") ?? .purple
    }
}

enum AppPalette {
    // MARK: - 主色（动态，跟随主题）

    static var accent: Color       { ThemeColor.current.accent }
    static var accentBright: Color { ThemeColor.current.accentBright }
    static var accentSoft: Color   { ThemeColor.current.accentSoft }

    /// 深紫 #332973
    static let primary = Color(red: 0.20, green: 0.16, blue: 0.45)
    /// 副文字 #75709E
    static let secondary = Color(red: 0.46, green: 0.44, blue: 0.62)

    // MARK: - 主体背景

    /// 主背景奶油色 #F6F1EB
    static let mainBg = Color(red: 0.965, green: 0.945, blue: 0.922)
    static let cardHover = Color(red: 0.985, green: 0.97, blue: 0.95)
    static let white = Color.white
    static let card = Color(red: 0.965, green: 0.945, blue: 0.922)

    // MARK: - Header 渐变（跟随主题色切换）

    /// 渐变三段（从上到下 / 对角分布）—— 跟随 ThemeColor 切换
    static var headerGradient1: Color { ThemeColor.current.headerStops.0 }
    static var headerGradient2: Color { ThemeColor.current.headerStops.1 }
    static var headerGradient3: Color { ThemeColor.current.headerStops.2 }

    /// header 顶部高光（细线）
    static let headerTopHighlight = Color.white.opacity(0.08)
    /// header 底部 hairline 分隔
    static let headerBottomHairline = Color.white.opacity(0.06)

    /// 中央 radial 辉光（跟随主题色）
    static var headerCenterGlow: Color { ThemeColor.current.centerGlow }

    /// 标题文字（暖白）
    static let headerTitle = Color(red: 0.98, green: 0.95, blue: 0.93)
    /// 副文字
    static let headerSecondary = Color(red: 0.78, green: 0.74, blue: 0.85)

    // MARK: - Header 按钮（深色圆形泡泡，对当前主题做暗化）

    static var headerIconBubble: Color {
        // 取主题深色第二段，调到 0.55 透明
        ThemeColor.current.headerStops.1.opacity(0.55)
    }
    static var headerIconBubbleHover: Color {
        ThemeColor.current.headerStops.1.opacity(0.85)
    }
    static let headerIconStroke = Color.white.opacity(0.10)
    static let headerIconStrokeHover = Color.white.opacity(0.22)

    // MARK: - 小猫窝（跟随主题色）

    static var bowlTop: Color    { ThemeColor.current.bowlTop }
    static var bowlBottom: Color { ThemeColor.current.bowlBottom }
    static var bowlHalo: Color   { ThemeColor.current.bowlHalo }
    /// 窝沿高光
    static let bowlHighlight = Color.white.opacity(0.32)
    /// 窝底投影
    static let bowlShadow = Color.black.opacity(0.45)

    // MARK: - 星空 / 噪点 / 云雾

    static let starColor = Color.white
    static let noiseColor = Color.white

    /// 云雾主色（跟随主题）—— 命名保留，含义改成"主云"
    static var cloudPurple: Color { ThemeColor.current.cloudPrimary }
    /// 云雾副色（跟随主题）
    static var cloudPink: Color   { ThemeColor.current.cloudSecondary }
    /// 云雾第三色（跟随主题）
    static var cloudBlue: Color   { ThemeColor.current.cloudTertiary }

    /// header 底部融入 body 的过渡色（跟随主题）
    static var headerToBodyFade: Color { ThemeColor.current.headerToBodyFade }
    /// Zzz 颜色
    static let zzzColor = Color.white.opacity(0.75)

    // MARK: - 主体卡片

    /// 卡片基础色 —— 半透明暖白（rgba(255,255,255,0.65) 同款气质）
    static let rowCard = Color.white.opacity(0.65)
    /// 卡片底层暖白（在 rowCard 之下再叠一层，保证可读性）
    static let rowCardBase = Color(red: 0.998, green: 0.994, blue: 0.985)
    /// 卡片顶部高光
    static let rowCardTopHighlight = Color.white.opacity(0.65)
    /// 卡片紧阴影
    static let rowCardShadowTight = Color(red: 0.20, green: 0.16, blue: 0.45).opacity(0.06)
    /// 卡片散阴影
    static let rowCardShadowSoft = Color(red: 0.20, green: 0.16, blue: 0.45).opacity(0.10)
    /// 卡片描边
    static let rowCardStroke = Color(red: 0.20, green: 0.16, blue: 0.45).opacity(0.06)
    /// hover 辉光（跟随主题色）
    static var rowCardHoverGlow: Color   { accent.opacity(0.16) }
    /// hover 描边（跟随主题色）
    static var rowCardHoverStroke: Color { accent.opacity(0.32) }

    // MARK: - 陪伴 stats chip

    /// stats chip 背景（暖白半透）
    static let statChipBg = Color.white.opacity(0.55)
    /// stats chip 描边
    static let statChipStroke = Color(red: 0.20, green: 0.16, blue: 0.45).opacity(0.07)
    /// stats chip 阴影
    static let statChipShadow = Color(red: 0.20, green: 0.16, blue: 0.45).opacity(0.06)

    // MARK: - 分隔与点缀

    static let separator = Color(red: 0.88, green: 0.86, blue: 0.96)
    static let pink = Color(red: 1.00, green: 0.72, blue: 0.80)
    static let warm = Color(red: 1.00, green: 0.80, blue: 0.60)
}

// MARK: - 渐变快捷

extension AppPalette {
    /// 顶部 header 对角深紫渐变
    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [headerGradient1, headerGradient2, headerGradient3],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 小猫窝渐变（上亮下暗）
    static var bowlGradient: LinearGradient {
        LinearGradient(
            colors: [bowlTop, bowlBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - 时段问候

extension AppPalette {
    static func timeGreeting(for date: Date = .init()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11:  return "早上好呀"
        case 11..<14: return "中午好呀"
        case 14..<18: return "下午好呀"
        case 18..<23: return "晚上好呀"
        default:      return "夜深了呀"
        }
    }
}

// MARK: - 跟随外观色的开关样式
//
// macOS 的 `.switch` 样式不响应 `.tint`（开启色固定走系统强调色，常显示为蓝色），
// 所以自绘一个开关：开启时填充用户在「外观」里选的强调色 AppPalette.accent。
struct AccentSwitchToggleStyle: ToggleStyle {
    var onColor: Color = AppPalette.accent

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        return RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(isOn ? onColor : Color(white: 0.82))
            .frame(width: 38, height: 22)
            .overlay(alignment: .center) {
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.18), radius: 1, x: 0, y: 0.5)
                    .frame(width: 18, height: 18)
                    .offset(x: isOn ? 8 : -8)
            }
            .animation(.easeInOut(duration: 0.18), value: isOn)
            .contentShape(Rectangle())
            .onTapGesture { configuration.isOn.toggle() }
    }
}
