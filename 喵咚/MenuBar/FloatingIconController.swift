//
//  FloatingIconController.swift
//  喵咚
//
//  屏幕级悬浮图标 —— 用户拖到屏幕任意位置，点击展开 ContentView 弹窗。
//  - 与 MenuBarController 二选一（由设置项 iconDisplayMode 决定）
//  - 拖动持久化到 UserDefaults
//  - 单击 vs 拖动 通过 mouse-move 阈值区分
//

import AppKit
import SwiftUI

@MainActor
final class FloatingIconController: NSObject {
    static let shared = FloatingIconController()

    private var panel: NSPanel?
    private var popover: NSPopover?

    private static let panelSize: CGFloat = 48

    private override init() {
        super.init()
    }

    // MARK: - 公开 API

    func setup<Content: View>(rootView: Content) {
        teardown()

        let size = Self.panelSize
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar              // 浮在普通窗口之上
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let iconView = FloatingIconNSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        iconView.onClick = { [weak self] in self?.togglePopover() }
        iconView.onDragEnd = { origin in
            let ud = UserDefaults.standard
            ud.set(Double(origin.x), forKey: AppSettingsKeys.floatingIconX)
            ud.set(Double(origin.y), forKey: AppSettingsKeys.floatingIconY)
        }
        panel.contentView = iconView

        // 恢复持久化坐标，没有则给一个默认（屏幕右侧中部）
        let origin = restoredOrigin(panelSize: size)
        panel.setFrameOrigin(origin)

        // Popover —— 复用 ContentView
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentSize = NSSize(width: 360, height: 520)
        let hc = NSHostingController(rootView: rootView)
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        pop.contentViewController = hc

        panel.orderFrontRegardless()

        self.panel = panel
        self.popover = pop
    }

    func teardown() {
        if let popover, popover.isShown {
            popover.performClose(nil)
        }
        panel?.orderOut(nil)
        panel = nil
        popover = nil
    }

    // MARK: - 切换 popover

    private func togglePopover() {
        guard let popover, let panel, let anchor = panel.contentView else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        // 优先向下展开；如果离屏幕下边太近，自动转为向上
        let edge: NSRectEdge = preferredEdge(forAnchor: anchor)
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: edge)
    }

    private func preferredEdge(forAnchor anchor: NSView) -> NSRectEdge {
        guard let win = anchor.window, let screen = win.screen ?? NSScreen.main else {
            return .minY
        }
        let winFrame = win.frame
        let visible = screen.visibleFrame
        let distanceToBottom = winFrame.minY - visible.minY
        let distanceToTop = visible.maxY - winFrame.maxY

        // 弹窗高度约 520，留 24 余量
        let popoverHeight: CGFloat = 540
        if distanceToBottom >= popoverHeight {
            return .minY    // 向下
        } else if distanceToTop >= popoverHeight {
            return .maxY    // 向上
        }
        // 都不够：选剩余空间大的一边
        return distanceToTop > distanceToBottom ? .maxY : .minY
    }

    // MARK: - 坐标恢复

    private func restoredOrigin(panelSize size: CGFloat) -> NSPoint {
        let ud = UserDefaults.standard
        // 没有保存过坐标：放屏幕右侧偏上
        guard ud.object(forKey: AppSettingsKeys.floatingIconX) != nil,
              ud.object(forKey: AppSettingsKeys.floatingIconY) != nil
        else {
            if let screen = NSScreen.main {
                let visible = screen.visibleFrame
                return NSPoint(
                    x: visible.maxX - size - 24,
                    y: visible.maxY - size - 80
                )
            }
            return NSPoint(x: 100, y: 100)
        }
        let savedX = ud.double(forKey: AppSettingsKeys.floatingIconX)
        let savedY = ud.double(forKey: AppSettingsKeys.floatingIconY)
        return clampedOrigin(NSPoint(x: savedX, y: savedY), panelSize: size)
    }

    /// 防止保存的坐标落在已断开的外接屏区域外
    private func clampedOrigin(_ p: NSPoint, panelSize size: CGFloat) -> NSPoint {
        let screens = NSScreen.screens
        // 任一屏的 visibleFrame 包含该点就直接采用
        if screens.contains(where: { $0.frame.contains(NSPoint(x: p.x + size / 2, y: p.y + size / 2)) }) {
            return p
        }
        // 否则回退到主屏右上
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            return NSPoint(
                x: visible.maxX - size - 24,
                y: visible.maxY - size - 80
            )
        }
        return p
    }
}

// MARK: - 自定义 NSView：拖动 + 单击区分 + 绘制图标

final class FloatingIconNSView: NSView {
    var onClick: () -> Void = {}
    var onDragEnd: (NSPoint) -> Void = { _ in }

    private var dragStartMouseScreen: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero
    private var didDrag: Bool = false
    private let dragThreshold: CGFloat = 3

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    // 任何区域都接收点击
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let inset: CGFloat = 4
        let cardRect = bounds.insetBy(dx: inset, dy: inset)
        let radius: CGFloat = 12

        // 阴影 + 白底圆角卡片
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 6
        shadow.set()

        NSColor.white.setFill()
        let bg = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)
        bg.fill()
        NSGraphicsContext.restoreGraphicsState()

        // 紫色细边
        NSColor(red: 0.20, green: 0.16, blue: 0.45, alpha: 0.10).setStroke()
        let border = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)
        border.lineWidth = 1
        border.stroke()

        let tintColor = NSColor(red: 0.20, green: 0.16, blue: 0.45, alpha: 1)
        let drawRect = NSRect(
            x: cardRect.midX - 12,
            y: cardRect.midY - 11,
            width: 24,
            height: 22
        )
        drawCatIcon(in: drawRect, tint: tintColor, fallbackFontSize: 15)
    }

    private func drawCatIcon(in rect: NSRect, tint: NSColor, fallbackFontSize: CGFloat) {
        for name in ["cat.fill", "pawprint.fill"] {
            guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: "喵咚") else {
                continue
            }
            let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .regular)
            let image = symbol.withSymbolConfiguration(config) ?? symbol
            drawTintedImage(image, in: rect, tint: tint)
            return
        }

        let text = "喵" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fallbackFontSize, weight: .bold),
            .foregroundColor: tint
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2),
            withAttributes: attributes
        )
    }

    private func drawTintedImage(_ image: NSImage, in rect: NSRect, tint: NSColor) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.draw(in: rect)
            return
        }
        context.saveGState()
        defer { context.restoreGState() }
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        // tint：用 destinationIn 让 alpha 保留 + 颜色覆盖
        context.setBlendMode(.sourceAtop)
        tint.setFill()
        rect.fill()
    }

    // MARK: - 鼠标事件：拖动 vs 单击

    override func mouseDown(with event: NSEvent) {
        dragStartMouseScreen = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStartMouseScreen.x
        let dy = current.y - dragStartMouseScreen.y

        if !didDrag {
            let dist = (dx * dx + dy * dy).squareRoot()
            if dist < dragThreshold { return }
            didDrag = true
        }

        win.setFrameOrigin(NSPoint(
            x: dragStartWindowOrigin.x + dx,
            y: dragStartWindowOrigin.y + dy
        ))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            if let win = window {
                onDragEnd(win.frame.origin)
            }
        } else {
            onClick()
        }
        didDrag = false
    }
}
