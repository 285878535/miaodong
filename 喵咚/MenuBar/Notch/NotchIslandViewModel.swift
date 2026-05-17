//
//  NotchIslandViewModel.swift
//  喵咚
//
//  极简灵动岛状态机 —— 取自 openIsland NotchViewModel 的核心思想，
//  剥离 SessionPhase/SessionMonitor 等 Coding Session 业务。
//
//  状态：
//    - .closed：仅显示一个黑色刘海，宽 ≈ 物理刘海宽度
//    - .opened：展开成大面板，承载待办 ContentView
//

import AppKit
import Combine
import SwiftUI

enum NotchIslandStatus: Equatable, Sendable {
    case closed
    case opened
}

@MainActor
final class NotchIslandViewModel: ObservableObject {
    // MARK: - Published 状态

    @Published private(set) var status: NotchIslandStatus = .closed
    @Published private(set) var geometry: NotchGeometry
    @Published private(set) var hasPhysicalNotch: Bool

    // MARK: - 几何派生量

    /// 展开面板期望尺寸 —— 完全等同于 ContentView 的内在尺寸
    /// （以前留过 12pt 边框余量，现在直接贴合，去掉黑边框）
    let openedContentSize = CGSize(width: 360, height: 560)

    var closedHeight: CGFloat {
        max(geometry.deviceNotchRect.height, 32)
    }

    /// 闭合态的可视宽度（约等于真刘海宽 + 一点 padding，便于命中）
    var closedWidth: CGFloat {
        max(geometry.deviceNotchRect.width + 8, 160)
    }

    /// 闭合态的视觉尺寸
    var closedSize: CGSize {
        CGSize(width: closedWidth, height: closedHeight)
    }

    /// 展开态内容上方需要让出的"刘海安全距离" —— 让 ContentView 顶部的
    /// 小猫和问候不再被硬件刘海挡住。无物理刘海的屏幕上也保留一点 16pt 留白。
    var openedSafeTopInset: CGFloat {
        if hasPhysicalNotch {
            // 刘海高度（典型 ~32pt） + 2pt 安全间隙
            return max(geometry.deviceNotchRect.height, 32) + 2
        } else {
            return 16
        }
    }

    /// 展开态的视觉尺寸 —— 宽度紧贴 ContentView；高度 = ContentView + 刘海让位
    var openedSize: CGSize {
        CGSize(
            width: openedContentSize.width,
            height: openedContentSize.height + openedSafeTopInset + 28
        )
    }

    // MARK: - Init

    init(
        deviceNotchRect: CGRect,
        screenRect: CGRect,
        windowHeight: CGFloat,
        hasPhysicalNotch: Bool
    ) {
        self.geometry = NotchGeometry(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenRect,
            windowHeight: windowHeight
        )
        self.hasPhysicalNotch = hasPhysicalNotch
    }

    // MARK: - 外部接口

    func updateGeometry(
        deviceNotchRect: CGRect,
        screenRect: CGRect,
        windowHeight: CGFloat,
        hasPhysicalNotch: Bool
    ) {
        self.geometry = NotchGeometry(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenRect,
            windowHeight: windowHeight
        )
        self.hasPhysicalNotch = hasPhysicalNotch
    }

    func open() {
        guard status != .opened else { return }
        status = .opened
    }

    func close() {
        guard status != .closed else { return }
        status = .closed
    }

    func toggle() {
        switch status {
        case .closed: open()
        case .opened: close()
        }
    }

    // MARK: - 命中测试

    /// 点是否落在闭合刘海的"hover 触发"区域
    func isPointInNotch(_ point: CGPoint) -> Bool {
        geometry.isPointInNotch(point)
    }

    /// 点是否落在展开面板内
    func isPointInOpenedPanel(_ point: CGPoint) -> Bool {
        geometry.isPointInOpenedPanel(point, size: openedSize)
    }
}
