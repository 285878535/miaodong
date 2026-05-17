//
//  AppPalette.swift
//  喵咚
//
//  品牌配色 —— 夜晚紫色调（顶部 header）+ 奶白主体 + 粉色 / 紫色点缀
//  设计参考：Raycast / Arc / Notion Calendar / CleanShot X
//

import SwiftUI

enum AppPalette {
    // MARK: - 主色

    /// 主紫 #8B7CFF
    static let accent = Color(red: 0.545, green: 0.486, blue: 1.00)
    /// 主紫亮版 (hover) #A498FF
    static let accentBright = Color(red: 0.643, green: 0.596, blue: 1.00)
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

    // MARK: - Header 渐变（深灰紫 → 深蓝紫，对角分布）

    /// 渐变起点：深灰紫 #2D2638
    static let headerGradient1 = Color(red: 0.176, green: 0.149, blue: 0.220)
    /// 渐变中点：柔和紫雾
    static let headerGradient2 = Color(red: 0.218, green: 0.180, blue: 0.330)
    /// 渐变终点：深蓝紫 #322B45
    static let headerGradient3 = Color(red: 0.196, green: 0.169, blue: 0.270)

    /// header 顶部高光（细线）
    static let headerTopHighlight = Color.white.opacity(0.08)
    /// header 底部 hairline 分隔
    static let headerBottomHairline = Color.white.opacity(0.06)

    /// 中央 radial 辉光（紫蓝色）
    static let headerCenterGlow = Color(red: 0.55, green: 0.45, blue: 0.85)

    /// 标题文字（暖白）
    static let headerTitle = Color(red: 0.98, green: 0.95, blue: 0.93)
    /// 副文字
    static let headerSecondary = Color(red: 0.78, green: 0.74, blue: 0.85)

    // MARK: - Header 按钮（深紫圆形泡泡）

    static let headerIconBubble = Color(red: 0.20, green: 0.17, blue: 0.32).opacity(0.55)
    static let headerIconBubbleHover = Color(red: 0.28, green: 0.23, blue: 0.42).opacity(0.85)
    static let headerIconStroke = Color.white.opacity(0.10)
    static let headerIconStrokeHover = Color.white.opacity(0.22)

    // MARK: - 小猫窝

    /// 窝顶色（亮紫）
    static let bowlTop = Color(red: 0.42, green: 0.34, blue: 0.58)
    /// 窝底色（深紫）
    static let bowlBottom = Color(red: 0.22, green: 0.17, blue: 0.34)
    /// 窝沿高光
    static let bowlHighlight = Color.white.opacity(0.32)
    /// 窝底投影
    static let bowlShadow = Color.black.opacity(0.45)
    /// 窝周围辉光
    static let bowlHalo = Color(red: 0.60, green: 0.50, blue: 0.90)

    // MARK: - 星空 / 噪点 / 云雾

    static let starColor = Color.white
    static let noiseColor = Color.white

    /// 云雾色（柔和的蓝紫团块，用 blur）
    static let cloudPurple = Color(red: 0.62, green: 0.50, blue: 0.95)
    /// 云雾色（偏粉的暖紫）
    static let cloudPink = Color(red: 0.85, green: 0.55, blue: 0.85)
    /// 云雾色（深蓝紫）
    static let cloudBlue = Color(red: 0.40, green: 0.42, blue: 0.85)

    /// header 底部融入 body 的过渡色
    static let headerToBodyFade = Color(red: 0.30, green: 0.25, blue: 0.44)
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
    /// hover 紫色辉光
    static let rowCardHoverGlow = Color(red: 0.55, green: 0.48, blue: 1.00).opacity(0.16)
    /// hover 描边
    static let rowCardHoverStroke = Color(red: 0.55, green: 0.48, blue: 1.00).opacity(0.32)

    // MARK: - 陪伴 stats chip

    /// stats chip 背景（暖白半透）
    static let statChipBg = Color.white.opacity(0.55)
    /// stats chip 描边
    static let statChipStroke = Color(red: 0.20, green: 0.16, blue: 0.45).opacity(0.07)
    /// stats chip 阴影
    static let statChipShadow = Color(red: 0.20, green: 0.16, blue: 0.45).opacity(0.06)

    // MARK: - 分隔与点缀

    static let separator = Color(red: 0.88, green: 0.86, blue: 0.96)
    static let accentSoft = Color(red: 0.94, green: 0.92, blue: 1.00)
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
