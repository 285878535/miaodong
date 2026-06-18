//
//  NotchPanel.swift
//  喵咚
//
//  透明全屏顶部 NSPanel，承载刘海岛 SwiftUI 视图。
//  关键参数与 openIsland 保持一致：
//    - level = .mainMenu + 3 （盖过菜单栏）
//    - collectionBehavior 包含 .fullScreenAuxiliary / .stationary / .canJoinAllSpaces
//    - 闭合时 ignoresMouseEvents = true 让点击穿透菜单栏
//    - 展开时 ignoresMouseEvents = false 让面板内按钮可点
//    - 覆写 constrainFrameRect 阻止 macOS 把窗口压到 visibleFrame 下方
//

import AppKit

final class NotchPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false

        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        hasShadow = false

        isMovable = false

        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]

        level = .mainMenu + 3

        allowsToolTipsWhenApplicationIsInactive = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = true
        acceptsMouseMovedEvents = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 跳过系统的"安全区裁剪"——让窗口能贴满屏幕顶部进入刘海区
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}
