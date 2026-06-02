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
import Combine

@MainActor
final class FloatingIconController: NSObject {
    static let shared = FloatingIconController()

    private var panel: NSPanel?
    /// 用透明 NSPanel 代替 NSPopover —— NSPopover 自带系统箭头和灰色背景 chrome，
    /// 无法通过 ContentView 层修复；手动定位 NSPanel 才能实现零系统背景。
    private var contentPanel: NSPanel?
    private var outsideClickMonitor: Any?

    private static let panelSize: CGFloat = 76
    private static let contentW: CGFloat = 360
    private static let contentH: CGFloat = 560

    private override init() {
        super.init()
    }

    // MARK: - 公开 API

    func setup<Content: View>(rootView: Content) {
        teardown()

        let size = Self.panelSize

        // ── 悬浮图标面板 ──
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let iconView = FloatingIconNSView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        iconView.onClick = { [weak self] in self?.toggleContent() }
        iconView.onDragEnd = { origin in
            let ud = UserDefaults.standard
            ud.set(Double(origin.x), forKey: AppSettingsKeys.floatingIconX)
            ud.set(Double(origin.y), forKey: AppSettingsKeys.floatingIconY)
        }
        panel.contentView = iconView

        let origin = restoredOrigin(panelSize: size)
        panel.setFrameOrigin(origin)

        // ── 内容面板（透明 NSPanel，无箭头无系统背景）──
        let cp = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.contentW, height: Self.contentH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        cp.level = .popUpMenu          // 高于 statusBar，确保盖住其他窗口
        cp.isFloatingPanel = true
        cp.hidesOnDeactivate = false
        cp.becomesKeyOnlyIfNeeded = true
        cp.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        cp.backgroundColor = .clear
        cp.isOpaque = false
        cp.hasShadow = false           // ContentView 已有自己的多层阴影
        cp.ignoresMouseEvents = false

        // ⚠️ 关键：NSPanel + NSHostingController 的组合会把屏幕级 safe-area
        // （菜单栏 ~25–40pt）透传到 SwiftUI，导致 ContentView 顶部空出一段透明背景。
        // 仅用 .ignoresSafeArea() / safeAreaRegions = [] 还不够 —— contentViewController
        // 这条路径在 macOS 上仍会让 hosting view 受窗口 layout margin 影响。
        // 改成：手动建一个固定 frame 的 NSView 容器 + NSHostingView 子视图，
        // 显式把 SwiftUI 钉死在 (0,0,360,560)，AppKit 没有任何机会再去插入 inset。
        let container = NSView(frame: NSRect(x: 0, y: 0, width: Self.contentW, height: Self.contentH))
        container.wantsLayer = true
        container.layer?.isOpaque = false
        container.layer?.backgroundColor = CGColor.clear
        container.autoresizesSubviews = false

        let hostingView = NSHostingView(rootView: rootView.ignoresSafeArea(.all, edges: .all))
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.isOpaque = false
        hostingView.layer?.backgroundColor = CGColor.clear
        container.addSubview(hostingView)

        cp.contentView = container

        panel.orderFrontRegardless()

        self.panel = panel
        self.contentPanel = cp
    }

    func teardown() {
        hideContent()
        panel?.orderOut(nil)
        panel = nil
        contentPanel = nil
    }

    // MARK: - 展开 / 收起

    private func toggleContent() {
        guard let cp = contentPanel else { return }
        if cp.isVisible {
            hideContent()
        } else {
            showContent()
        }
    }

    private func showContent() {
        guard let cp = contentPanel, let panel else { return }
        NSApp.activate(ignoringOtherApps: true)
        cp.setFrameOrigin(contentOrigin(for: panel))
        cp.orderFrontRegardless()
        installOutsideClickMonitor()
    }

    private func hideContent() {
        contentPanel?.orderOut(nil)
        removeOutsideClickMonitor()
    }

    /// 计算内容面板坐标：优先在图标正下方，空间不足则显示在上方
    private func contentOrigin(for iconPanel: NSPanel) -> NSPoint {
        let iconFrame = iconPanel.frame
        let screen = iconPanel.screen ?? NSScreen.main!
        let visible = screen.visibleFrame
        let cw = Self.contentW
        let ch = Self.contentH
        let gap: CGFloat = 8

        // 水平：以图标中心对齐，clamp 到可见区域
        var x = iconFrame.midX - cw / 2
        x = max(visible.minX + 8, min(x, visible.maxX - cw - 8))

        // 垂直：优先向下，不够则向上
        let y: CGFloat
        if iconFrame.minY - ch - gap >= visible.minY {
            y = iconFrame.minY - ch - gap
        } else {
            y = iconFrame.maxY + gap
        }
        return NSPoint(x: x, y: y)
    }

    // MARK: - 点击外部自动收起

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // 点击落在 App 任意一个 visible 窗口内 → 视为"内部点击"，不关闭面板。
            // 用户点行打开 AddTodoWindow / Settings 等次级面板时，曾出现面板被瞬关，
            // 这里加一层"任意我家窗口都不算外部"的兜底。
            let mouseLoc = NSEvent.mouseLocation
            let inOurWindow = NSApp.windows.contains { window in
                window.isVisible && window.frame.contains(mouseLoc)
            }
            if inOurWindow { return }
            Task { @MainActor [weak self] in self?.hideContent() }
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
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

// MARK: - 动态像素猫图标（SwiftUI，与刘海闭合态同款睡眠动画）

private struct FloatingCatView: View {
    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.64, on: .main, in: .common).autoconnect()
    private let frameNames = (5...8).map { "sleep\($0)" }

    var body: some View {
        ZStack {
            // 白色圆角卡片 + 阴影
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: -2)
            // 紫色细边
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.20, green: 0.16, blue: 0.45).opacity(0.10), lineWidth: 1)
            // 动态像素猫
            if let image = loadFrame(named: frameNames[frameIndex]) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 50, height: 42)
            } else {
                // 兜底：系统符号
                Image(systemName: "cat.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.45))
            }
        }
        .padding(4)
        .onReceive(timer) { _ in
            frameIndex = (frameIndex + 1) % frameNames.count
        }
    }

    private func loadFrame(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "SleepCat") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

/// NSHostingView 子类：hit test 返回 nil，让鼠标事件穿透给父 NSView
private final class PassthroughHostingView<T: View>: NSHostingView<T> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - 自定义 NSView：拖动 + 单击区分，视觉由 FloatingCatView 提供

final class FloatingIconNSView: NSView {
    var onClick: () -> Void = {}
    var onDragEnd: (NSPoint) -> Void = { _ in }

    private var dragStartMouseScreen: NSPoint = .zero
    private var dragStartWindowOrigin: NSPoint = .zero
    private var didDrag: Bool = false
    private let dragThreshold: CGFloat = 3

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear

        // 动态猫咪视图（穿透 hit test，鼠标事件由本 NSView 处理）
        let hostingView = PassthroughHostingView(rootView: FloatingCatView())
        hostingView.frame = frameRect
        hostingView.autoresizingMask = [.width, .height]
        addSubview(hostingView)
    }

    required init?(coder: NSCoder) { fatalError() }

    // 任何区域都接收点击
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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
