//
//  HeaderAtmosphere.swift
//  喵咚
//
//  顶部 header 的氛围装饰组件：
//    - NoiseTexture       —— 稳定的细噪点（无闪烁）
//    - TwinklingStars     —— 大小不一、呼吸闪烁的星点
//    - CatBowlShape       —— 半圆形猫窝路径（上平下凸）
//    - CatBowlView        —— 渐变 + 高光 + 投影 + 蓝紫辉光的完整猫窝
//

import SwiftUI

// MARK: - 稳定噪点

/// 用一组在编译期生成的随机点位画噪点，避免每次重绘抖动。
struct NoiseTexture: View {
    /// 1pt 噪点的总数；越多越脏，越少越干净
    var count: Int = 240
    /// 噪点最大透明度
    var maxOpacity: Double = 0.18

    /// 静态种子点：[(归一化 x, 归一化 y, alpha)]
    private static let positions: [(CGFloat, CGFloat, Double)] = {
        var rng = SystemRandomNumberGenerator()
        return (0..<600).map { _ in
            (
                CGFloat.random(in: 0..<1, using: &rng),
                CGFloat.random(in: 0..<1, using: &rng),
                Double.random(in: 0.18...1.0, using: &rng)
            )
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            let take = min(count, Self.positions.count)
            for i in 0..<take {
                let (nx, ny, weight) = Self.positions[i]
                let rect = CGRect(
                    x: nx * size.width,
                    y: ny * size.height,
                    width: 1,
                    height: 1
                )
                ctx.fill(
                    Path(rect),
                    with: .color(AppPalette.noiseColor.opacity(maxOpacity * weight))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 云雾层（低 opacity blur 椭圆，制造夜空层次）

/// 3 团缓慢移动的蓝紫云团，blur 很大，提供"深度"的感觉
struct CloudLayer: View {
    private struct Cloud {
        let center: UnitPoint
        let size: CGSize
        let color: Color
        let blur: CGFloat
        let drift: CGFloat
        let phase: Double
    }

    private var clouds: [Cloud] {
        [
            Cloud(
                center: .init(x: 0.28, y: 0.62),
                size: CGSize(width: 160, height: 80),
                color: AppPalette.cloudPurple.opacity(0.22),
                blur: 28, drift: 6, phase: 0
            ),
            Cloud(
                center: .init(x: 0.78, y: 0.32),
                size: CGSize(width: 140, height: 70),
                color: AppPalette.cloudPink.opacity(0.16),
                blur: 26, drift: 5, phase: 1.7
            ),
            Cloud(
                center: .init(x: 0.55, y: 0.85),
                size: CGSize(width: 200, height: 60),
                color: AppPalette.cloudBlue.opacity(0.18),
                blur: 30, drift: 7, phase: 3.1
            ),
        ]
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0, paused: false)) { ctx in
            GeometryReader { geo in
                ZStack {
                    ForEach(clouds.indices, id: \.self) { i in
                        cloudView(
                            clouds[i],
                            containerSize: geo.size,
                            t: ctx.date.timeIntervalSinceReferenceDate
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func cloudView(_ cloud: Cloud, containerSize: CGSize, t: TimeInterval) -> some View {
        let dx = CGFloat(sin((t + cloud.phase) * 0.09)) * cloud.drift
        let dy = CGFloat(cos((t + cloud.phase) * 0.065)) * (cloud.drift * 0.6)
        return Ellipse()
            .fill(cloud.color)
            .frame(width: cloud.size.width, height: cloud.size.height)
            .blur(radius: cloud.blur)
            .position(
                x: cloud.center.x * containerSize.width + dx,
                y: cloud.center.y * containerSize.height + dy
            )
    }
}

// MARK: - 头部 → 主体过渡（一条 fade，避免硬切）

/// 用在主体顶部：从顶部柔和的紫色阴影 → 中间淡紫 → 底部透明，
/// 让深色 header 像"雾气一样"漫到奶白主体上。默认 80pt 高度，避免硬切。
struct HeaderToBodyFade: View {
    var height: CGFloat = 80
    var color: Color = AppPalette.headerToBodyFade

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: color.opacity(0.32), location: 0.0),
                .init(color: color.opacity(0.20), location: 0.25),
                .init(color: color.opacity(0.10), location: 0.55),
                .init(color: color.opacity(0.04), location: 0.80),
                .init(color: color.opacity(0.0),  location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

// MARK: - Zzz 浮动（睡觉态用）

/// 三只小 Z 缓缓向上飘 + 淡出，循环
struct ZzzFloater: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: false)) { ctx in
            let now = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3) { i in
                    zz(index: i, time: now)
                }
            }
            .frame(width: 26, height: 32)
        }
        .allowsHitTesting(false)
    }

    private func zz(index: Int, time: TimeInterval) -> some View {
        // 每只 Z 周期 2.4s，间隔 0.8s 错峰
        let period: Double = 4.8
        let offset = Double(index) * 0.8
        let t = ((time + offset).truncatingRemainder(dividingBy: period)) / period  // 0..1
        let y = -CGFloat(t) * 26                              // 向上飘 26pt
        let opacity = sin(.pi * t)                            // 0→1→0
        let size: CGFloat = 9 + CGFloat(t) * 2
        return Text("Z")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(AppPalette.zzzColor.opacity(opacity))
            .offset(x: CGFloat(t) * 6, y: y)
    }
}

// MARK: - 呼吸闪烁星点

/// 几颗大小不一的星，缓慢呼吸式闪烁
struct TwinklingStars: View {
    struct Star {
        let nx: CGFloat   // 归一化 x
        let ny: CGFloat   // 归一化 y
        let size: CGFloat
        let phase: Double // 闪烁相位偏移（秒）
        let speed: Double // 闪烁周期速度
    }

    var stars: [Star] = [
        .init(nx: 0.05, ny: 0.30, size: 7, phase: 0.0, speed: 0.7),
        .init(nx: 0.11, ny: 0.62, size: 4, phase: 1.3, speed: 1.1),
        .init(nx: 0.18, ny: 0.18, size: 5, phase: 2.0, speed: 0.9),
        .init(nx: 0.24, ny: 0.50, size: 3, phase: 0.4, speed: 1.3),
        .init(nx: 0.31, ny: 0.78, size: 4, phase: 2.8, speed: 0.85),
        .init(nx: 0.36, ny: 0.20, size: 6, phase: 1.0, speed: 0.95),
        .init(nx: 0.62, ny: 0.74, size: 4, phase: 1.4, speed: 1.0),
        .init(nx: 0.69, ny: 0.20, size: 6, phase: 1.7, speed: 0.8),
        .init(nx: 0.78, ny: 0.55, size: 4, phase: 0.9, speed: 1.0),
        .init(nx: 0.83, ny: 0.78, size: 3, phase: 2.2, speed: 1.2),
        .init(nx: 0.90, ny: 0.30, size: 7, phase: 2.4, speed: 0.7),
        .init(nx: 0.96, ny: 0.68, size: 3, phase: 0.2, speed: 1.4),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: false)) { ctx in
            GeometryReader { geo in
                let now = ctx.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(stars.indices, id: \.self) { i in
                        let star = stars[i]
                        let t = (now + star.phase) * star.speed * 0.5
                        // 0.35 ~ 0.95 的透明度区间，sin 呼吸
                        let twinkle = 0.65 + 0.30 * sin(t)
                        Image(systemName: "sparkle")
                            .font(.system(size: star.size, weight: .light))
                            .foregroundStyle(AppPalette.starColor.opacity(twinkle))
                            .position(
                                x: star.nx * geo.size.width,
                                y: star.ny * geo.size.height
                            )
                            .blur(radius: star.size < 5 ? 0 : 0.4)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 猫窝形状

/// 半圆形猫窝路径 —— 上边水平，下边外凸的弧。
struct CatBowlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.35)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - 带辉光和高光的完整猫窝（不含小猫本体）

/// 猫窝视觉层：辉光 → 猫窝主体 → 顶部窝沿高光。
/// 不渲染小猫本体（小猫由调用方在该窝上叠加一只 `PixelCatView`）。
struct CatBowlView: View {
    var width: CGFloat = 76
    var height: CGFloat = 26

    var body: some View {
        ZStack {
            // 1. 背后蓝紫辉光
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            AppPalette.bowlHalo.opacity(0.55),
                            AppPalette.bowlHalo.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: width * 0.85
                    )
                )
                .frame(width: width * 1.7, height: height * 2.2)
                .blur(radius: 6)

            // 2. 猫窝主体（渐变填充 + 投影）
            CatBowlShape()
                .fill(AppPalette.bowlGradient)
                .frame(width: width, height: height)
                .shadow(color: AppPalette.bowlShadow, radius: 5, x: 0, y: 3)

            // 3. 顶部窝沿高光（仅上沿亮一条）
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppPalette.bowlHighlight, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: 1.4)
                .offset(y: -height / 2 + 0.7)
        }
        .frame(width: width * 1.7, height: height)
    }
}
