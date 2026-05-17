//
//  PixelCatView.swift
//  喵咚
//
//  像素风小奶猫 —— 坐姿，2 只耳朵，大眼睛 + 粉腮红。
//  支持 idle / wag / sleep / bell / sparkle / exercise / wave / cheer 多种心情。
//  纯 SwiftUI Canvas 绘制（不依赖图片资源）；网格 18×16，单格 = `pixel` pt。
//

import SwiftUI

enum CatMood: Equatable {
    case idle
    case wag
    case sleep
    case bell
    case sparkle
    case exercise
    /// 抬一只手轻挥
    case wave
    /// 双手举高欢呼（完成时一闪）
    case cheer
}

struct PixelCatView: View {
    /// 单位像素的边长（默认 2pt）
    var pixel: CGFloat = 2
    /// 主色（猫毛颜色 —— 默认暖白偏奶油）
    var bodyColor: Color = Color(red: 0.99, green: 0.96, blue: 0.92)
    /// 描边色
    var strokeColor: Color = Color(red: 0.22, green: 0.18, blue: 0.32)
    /// 腮红色
    var cheekColor: Color = Color(red: 1.00, green: 0.66, blue: 0.78)
    /// 眼睛 / 鼻子色
    var featureColor: Color = Color(red: 0.16, green: 0.13, blue: 0.28)
    /// 当前心情
    var mood: CatMood = .idle
    /// 是否带柔和发光（用 .shadow 实现）
    var glow: Bool = false

    private let cols = 18
    private let rows = 16

    var body: some View {
        let canvas = TimelineView(.animation(minimumInterval: 0.35, paused: false)) { ctx in
            Canvas { context, _ in
                draw(in: context, time: ctx.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: pixel * CGFloat(cols), height: pixel * CGFloat(rows))
        .accessibilityHidden(true)

        if glow {
            canvas
                .shadow(color: Color(red: 0.85, green: 0.78, blue: 1.0).opacity(0.55), radius: 4)
                .shadow(color: Color(red: 0.55, green: 0.45, blue: 0.95).opacity(0.30), radius: 10)
        } else {
            canvas
        }
    }

    // MARK: - 主绘制

    private func draw(in context: GraphicsContext, time: TimeInterval) {
        let phase = Int(time / 0.7)
        let wagFrame = phase & 1
        let blinkFrame = phase % 9 == 0
        let bellFrame = phase & 1
        let sparkleFrame = phase % 3
        let waveFrame = phase & 1

        var grid = emptyGrid()

        // 1. 身体（部分 mood 用不同的腿/手姿势）
        switch mood {
        case .wave:
            paintBody(into: &grid, rightArmRaised: waveFrame == 1)
        case .cheer:
            paintBody(into: &grid, leftArmRaised: true, rightArmRaised: true)
        default:
            paintBody(into: &grid)
        }

        // 2. 脸（按 mood 决定眨眼）
        let isBlinking: Bool
        switch mood {
        case .sleep:                      isBlinking = true
        case .idle:                       isBlinking = blinkFrame
        case .wag, .bell, .sparkle, .exercise, .wave, .cheer:
                                          isBlinking = false
        }
        paintFace(into: &grid, blink: isBlinking, smile: mood == .cheer)

        // 3. 尾巴
        let tailUp = mood != .sleep && wagFrame == 0
        paintTail(into: &grid, up: tailUp)

        // 4. 附加饰物
        switch mood {
        case .bell:
            paintBell(into: &grid, frame: bellFrame)
        case .sparkle, .cheer:
            paintSparkles(into: &grid, frame: sparkleFrame, big: mood == .cheer)
        case .exercise:
            paintHeadband(into: &grid)
        default:
            break
        }

        // 渲染
        for y in 0..<rows {
            for x in 0..<cols {
                guard let cell = grid[y][x] else { continue }
                let rect = CGRect(
                    x: CGFloat(x) * pixel,
                    y: CGFloat(y) * pixel,
                    width: pixel,
                    height: pixel
                )
                context.fill(Path(rect), with: .color(color(for: cell)))
            }
        }
    }

    private enum Cell {
        case stroke
        case body
        case cheek
        case feature
        case bellMetal
        case sparkle
        case band
    }

    private func color(for cell: Cell) -> Color {
        switch cell {
        case .stroke:    return strokeColor
        case .body:      return bodyColor
        case .cheek:     return cheekColor
        case .feature:   return featureColor
        case .bellMetal: return Color(red: 1.00, green: 0.80, blue: 0.32)
        case .sparkle:   return Color(red: 1.00, green: 0.92, blue: 0.55)
        case .band:      return Color(red: 0.95, green: 0.45, blue: 0.50)
        }
    }

    private func emptyGrid() -> [[Cell?]] {
        Array(repeating: Array(repeating: nil, count: cols), count: rows)
    }

    // MARK: - 像素图：身体

    /// 根据手臂状态绘制身体
    /// - 默认双臂下垂作为前爪
    /// - 单臂抬起：右手举到耳侧
    private func paintBody(
        into grid: inout [[Cell?]],
        leftArmRaised: Bool = false,
        rightArmRaised: Bool = false
    ) {
        // 主身体（无四肢）
        let map = [
            "                  ",
            "   ##        ##   ",
            "  #..#      #..#  ",
            " #....######....# ",
            " #..............# ",
            " #..............# ",
            " #..............# ",
            " #..............# ",
            "  #............#  ",
            "  #............#  ",
            "   #..........#   ",
            "   #..........#   ",
            "                  ",
            "                  ",
            "                  ",
            "                  ",
        ]
        applyMap(map, into: &grid) { ch in
            switch ch {
            case "#": return .stroke
            case ".": return .body
            default:  return nil
            }
        }

        // 左前爪 / 抬起的左手
        if leftArmRaised {
            // 高举：col 4 区，row 1-3
            for (x, y) in [(4, 1), (4, 2), (5, 2), (5, 3), (5, 4)] {
                set(&grid, x: x, y: y, cell: .stroke)
            }
        } else {
            // 下垂前爪
            for (x, y) in [(4, 12), (4, 13), (5, 13)] {
                set(&grid, x: x, y: y, cell: .stroke)
            }
            for (x, y) in [(3, 12)] {
                set(&grid, x: x, y: y, cell: .stroke)
            }
        }

        // 右前爪 / 抬起的右手
        if rightArmRaised {
            for (x, y) in [(13, 1), (13, 2), (12, 2), (12, 3), (12, 4)] {
                set(&grid, x: x, y: y, cell: .stroke)
            }
        } else {
            for (x, y) in [(12, 12), (12, 13), (13, 13)] {
                set(&grid, x: x, y: y, cell: .stroke)
            }
            for (x, y) in [(14, 12)] {
                set(&grid, x: x, y: y, cell: .stroke)
            }
        }
    }

    // MARK: - 像素图：脸

    private func paintFace(into grid: inout [[Cell?]], blink: Bool, smile: Bool) {
        let eyeLX = 5
        let eyeRX = 11
        let eyeY = 5

        if blink {
            // 闭眼：一条水平线
            for dx in 0..<2 {
                set(&grid, x: eyeLX + dx, y: eyeY + 1, cell: .feature)
                set(&grid, x: eyeRX + dx, y: eyeY + 1, cell: .feature)
            }
        } else {
            // 睁眼：2×2 黑色方块 + 右上角白色高光
            for dx in 0..<2 {
                for dy in 0..<2 {
                    set(&grid, x: eyeLX + dx, y: eyeY + dy, cell: .feature)
                    set(&grid, x: eyeRX + dx, y: eyeY + dy, cell: .feature)
                }
            }
            set(&grid, x: eyeLX + 1, y: eyeY, cell: .body)
            set(&grid, x: eyeRX + 1, y: eyeY, cell: .body)
        }

        // 腮红：2 像素宽，眼下侧
        for dx in 0..<2 {
            set(&grid, x: 3 + dx, y: 7, cell: .cheek)
            set(&grid, x: 13 + dx, y: 7, cell: .cheek)
        }

        // 鼻子：2 像素，正中
        set(&grid, x: 8, y: 7, cell: .feature)
        set(&grid, x: 9, y: 7, cell: .feature)

        // 笑脸（cheer 时）
        if smile {
            set(&grid, x: 7, y: 8, cell: .feature)
            set(&grid, x: 8, y: 9, cell: .feature)
            set(&grid, x: 9, y: 9, cell: .feature)
            set(&grid, x: 10, y: 8, cell: .feature)
        }
    }

    // MARK: - 像素图：尾巴

    private func paintTail(into grid: inout [[Cell?]], up: Bool) {
        if up {
            for (x, y) in [(15, 9), (16, 8), (17, 7), (17, 6)] {
                set(&grid, x: x, y: y, cell: .stroke)
            }
        } else {
            for (x, y) in [(15, 10), (16, 11), (17, 12), (17, 13)] {
                set(&grid, x: x, y: y, cell: .stroke)
            }
        }
    }

    // MARK: - 铃铛（脖子下方，两帧摇摆）

    private func paintBell(into grid: inout [[Cell?]], frame: Int) {
        let dx = frame == 0 ? 0 : 1
        let cx = 8 + dx
        let cy = 10
        set(&grid, x: cx, y: cy, cell: .stroke)
        set(&grid, x: cx + 1, y: cy, cell: .stroke)
        set(&grid, x: cx, y: cy + 1, cell: .bellMetal)
        set(&grid, x: cx + 1, y: cy + 1, cell: .bellMetal)
        set(&grid, x: cx, y: cy + 2, cell: .stroke)
        set(&grid, x: cx + 1, y: cy + 2, cell: .stroke)
    }

    // MARK: - 闪光

    private func paintSparkles(into grid: inout [[Cell?]], frame: Int, big: Bool) {
        if big {
            // cheer：十字星形闪光（4 个角各一）
            let crosses: [(Int, Int)] = [(1, 1), (16, 1), (1, 5), (16, 5)]
            for (cx, cy) in crosses {
                set(&grid, x: cx, y: cy, cell: .sparkle)
                set(&grid, x: cx, y: cy - 1, cell: .sparkle)
                set(&grid, x: cx, y: cy + 1, cell: .sparkle)
                set(&grid, x: cx - 1, y: cy, cell: .sparkle)
                set(&grid, x: cx + 1, y: cy, cell: .sparkle)
            }
        } else {
            switch frame {
            case 0:
                set(&grid, x: 1, y: 3, cell: .sparkle)
                set(&grid, x: 16, y: 4, cell: .sparkle)
            case 1:
                set(&grid, x: 0, y: 5, cell: .sparkle)
                set(&grid, x: 17, y: 2, cell: .sparkle)
            default:
                set(&grid, x: 1, y: 1, cell: .sparkle)
                set(&grid, x: 16, y: 6, cell: .sparkle)
            }
        }
    }

    // MARK: - 运动头带

    private func paintHeadband(into grid: inout [[Cell?]]) {
        for x in 3...14 {
            set(&grid, x: x, y: 4, cell: .band)
        }
        set(&grid, x: 15, y: 5, cell: .band)
        set(&grid, x: 16, y: 5, cell: .band)
    }

    // MARK: - Helpers

    private func set(_ grid: inout [[Cell?]], x: Int, y: Int, cell: Cell) {
        guard y >= 0, y < rows, x >= 0, x < cols else { return }
        grid[y][x] = cell
    }

    private func applyMap(
        _ map: [String],
        into grid: inout [[Cell?]],
        decoder: (Character) -> Cell?
    ) {
        for (y, row) in map.enumerated() where y < rows {
            for (x, ch) in row.enumerated() where x < cols {
                if let cell = decoder(ch) {
                    grid[y][x] = cell
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            PixelCatView(mood: .idle, glow: true)
            PixelCatView(mood: .wag, glow: true)
            PixelCatView(mood: .sleep, glow: true)
            PixelCatView(mood: .bell, glow: true)
        }
        HStack(spacing: 16) {
            PixelCatView(mood: .sparkle, glow: true)
            PixelCatView(mood: .exercise, glow: true)
            PixelCatView(mood: .wave, glow: true)
            PixelCatView(mood: .cheer, glow: true)
        }
    }
    .padding(40)
    .background(
        LinearGradient(
            colors: [
                Color(red: 0.106, green: 0.086, blue: 0.196),
                Color(red: 0.196, green: 0.169, blue: 0.270)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
