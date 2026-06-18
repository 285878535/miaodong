//
//  ScreenNotchMetrics.swift
//  喵咚
//
//  屏幕刘海检测与回退尺寸 —— 移植自 openIsland。
//

import CoreGraphics

struct ScreenNotchMetrics: Equatable {
    static let fallbackClosedHeight: CGFloat = 32
    static let fallbackNotchWidth: CGFloat = 180
    static let fallbackSize = CGSize(width: 224, height: 38)

    let size: CGSize
    let hasPhysicalNotch: Bool

    /// 闭合态高度：物理刘海用 size.height；无刘海回落到状态栏厚度
    var closedHeight: CGFloat {
        hasPhysicalNotch ? size.height : Self.fallbackClosedHeight
    }

    static func detect(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeftWidth: CGFloat?,
        auxiliaryTopRightWidth: CGFloat?
    ) -> ScreenNotchMetrics {
        let detectedHeight = ceil(safeAreaTop)
        guard detectedHeight > 0 else {
            return ScreenNotchMetrics(
                size: Self.fallbackSize,
                hasPhysicalNotch: false
            )
        }

        let leftPadding = max(0, auxiliaryTopLeftWidth ?? 0)
        let rightPadding = max(0, auxiliaryTopRightWidth ?? 0)
        let detectedWidth: CGFloat

        if leftPadding > 0, rightPadding > 0 {
            detectedWidth = max(
                Self.fallbackNotchWidth,
                ceil(screenFrame.width - leftPadding - rightPadding + 4)
            )
        } else {
            detectedWidth = Self.fallbackNotchWidth
        }

        return ScreenNotchMetrics(
            size: CGSize(width: detectedWidth, height: detectedHeight),
            hasPhysicalNotch: true
        )
    }
}
