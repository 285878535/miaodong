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

    /// 悬浮图标尺寸范围（与设置页滑块保持一致）
    static let minSize: CGFloat = 60
    static let maxSize: CGFloat = 180
    static let defaultSize: CGFloat = 88

    private static let contentW: CGFloat = 360
    private static let contentH: CGFloat = 560
    /// 内容面板四周留白：容纳 ContentView 自身的多层投影（shadow radius 最大 34），
    /// 否则面板方形边界会把圆角矩形的阴影硬裁，四角露出半透明直角边。
    /// 灵动岛模式靠 750pt 高面板天然留白，悬浮面板尺寸贴合内容，必须显式留白。
    private static let contentMargin: CGFloat = 48

    /// 当前生效的悬浮图标尺寸：取设置项，未设过用默认值，并夹在合法范围内
    static func resolvedSize() -> CGFloat {
        let v = CGFloat(UserDefaults.standard.double(forKey: AppSettingsKeys.floatingIconSize))
        guard v > 0 else { return defaultSize }
        return min(max(v, minSize), maxSize)
    }

    private override init() {
        super.init()
        // 监听设置页滑块：仅当悬浮模式正在显示时按新尺寸重建图标（保持中心位置）
        NotificationCenter.default.addObserver(
            forName: .floatingIconSizeDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applySizeChange() }
        }
    }

    // MARK: - 公开 API

    func setup<Content: View>(rootView: Content) {
        teardown()

        let size = Self.resolvedSize()

        // ── 悬浮图标面板 ──
        let panel = makeIconPanel(size: size, origin: restoredOrigin(panelSize: size))

        // ── 内容面板（透明 NSPanel，无箭头无系统背景）──
        // 面板比 ContentView 四周各大 contentMargin，留白用于容纳 ContentView 的外阴影，
        // 避免阴影被面板方形边界硬裁、四角露出半透明直角边。
        let m = Self.contentMargin
        let cp = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.contentW + 2 * m, height: Self.contentH + 2 * m),
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
        let container = MarginPassthroughView(frame: NSRect(x: 0, y: 0, width: Self.contentW + 2 * m, height: Self.contentH + 2 * m))
        container.wantsLayer = true
        container.layer?.isOpaque = false
        container.layer?.backgroundColor = CGColor.clear
        container.autoresizesSubviews = false
        // 只有内容矩形内可交互，四周透明 margin 的点击穿透到下方（图标 / 桌面）
        container.interactiveRect = NSRect(x: m, y: m, width: Self.contentW, height: Self.contentH)

        // ContentView 固定 360×560 居中放在留白容器里（不随容器拉伸），四周 margin 透明承载阴影
        let hostingView = NSHostingView(rootView: rootView.ignoresSafeArea(.all, edges: .all))
        hostingView.frame = NSRect(x: m, y: m, width: Self.contentW, height: Self.contentH)
        hostingView.autoresizingMask = []
        hostingView.wantsLayer = true
        hostingView.layer?.isOpaque = false
        hostingView.layer?.backgroundColor = CGColor.clear
        container.addSubview(hostingView)

        cp.contentView = container

        panel.orderFrontRegardless()

        self.panel = panel
        self.contentPanel = cp
    }

    /// 创建悬浮图标面板（透明 NSPanel + 可拖动/可点击的 FloatingIconNSView），定位到 origin
    private func makeIconPanel(size: CGFloat, origin: NSPoint) -> NSPanel {
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

        panel.setFrameOrigin(origin)
        return panel
    }

    /// 设置页改了大小：仅当悬浮模式激活时用新尺寸重建图标，保持中心点不动并持久化坐标
    private func applySizeChange() {
        guard let old = panel else { return }   // 非悬浮模式不处理
        let oldFrame = old.frame
        let newSize = Self.resolvedSize()
        // 以中心为锚换尺寸，再夹回屏幕可视区
        let centered = NSPoint(x: oldFrame.midX - newSize / 2, y: oldFrame.midY - newSize / 2)
        let origin = clampedOrigin(centered, panelSize: newSize)

        let newPanel = makeIconPanel(size: newSize, origin: origin)
        old.orderOut(nil)
        self.panel = newPanel
        newPanel.orderFrontRegardless()

        let ud = UserDefaults.standard
        ud.set(Double(origin.x), forKey: AppSettingsKeys.floatingIconX)
        ud.set(Double(origin.y), forKey: AppSettingsKeys.floatingIconY)

        // 内容面板正展开时，跟随新图标位置重新定位
        if let cp = contentPanel, cp.isVisible {
            cp.setFrameOrigin(contentOrigin(for: newPanel))
        }
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

    /// 供外部调用：打开设置/历史等独立窗口前收起悬浮主面板，
    /// 避免主面板残留在新窗口背后、深色 header 从边缘露出。非悬浮模式下为空操作。
    func hideContentPanel() {
        hideContent()
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
        // (x, y) 是「内容矩形」的目标位置；内容在面板内缩进了 contentMargin，
        // 所以面板原点要再减去 margin，让内容落在预期位置。
        let m = Self.contentMargin
        return NSPoint(x: x - m, y: y - m)
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
                guard window.isVisible else { return false }
                // 内容面板四周有透明 margin（承载阴影），命中判定要用内层真实内容矩形，
                // 否则点击卡片旁的透明留白会被当成"内部点击"而无法关闭。
                if window === self?.contentPanel {
                    return window.frame.insetBy(dx: Self.contentMargin, dy: Self.contentMargin).contains(mouseLoc)
                }
                return window.frame.contains(mouseLoc)
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
    /// 悬浮面板边长，小猫按它等比缩放（基准 76pt 时猫为 50×42）
    let panelSize: CGFloat

    @ObservedObject private var activity = CatActivityState.shared
    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.64, on: .main, in: .common).autoconnect()

    /// 有未完成任务 → 挥手（活跃）；否则睡觉
    private var frameNames: [String] {
        activity.hasActiveTodos ? (3...6).map { "wave\($0)" } : (5...8).map { "sleep\($0)" }
    }

    private var catWidth: CGFloat { panelSize * 50 / 76 }
    private var catHeight: CGFloat { panelSize * 42 / 76 }

    var body: some View {
        // 去掉白色卡片 / 紫色边框，只留透明悬浮的小猫；
        // 一层柔和深色阴影保证它在浅色 / 白色壁纸上也能看清、与背景分离。
        Group {
            if let image = loadFrame(named: frameNames[frameIndex]) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: catWidth, height: catHeight)
            } else {
                // 兜底：系统符号
                Image(systemName: "cat.fill")
                    .font(.system(size: catWidth * 0.44, weight: .regular))
                    .foregroundStyle(Color(red: 0.20, green: 0.16, blue: 0.45))
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
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

/// 内容面板容器：只有 interactiveRect 内（真正的 ContentView 区域）可交互，
/// 四周透明 margin 的点击穿透到下方窗口（图标 / 桌面），避免留白拦截鼠标。
private final class MarginPassthroughView: NSView {
    var interactiveRect: NSRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        // point 为父视图（无边框面板下即窗口内容）坐标，与本视图坐标一致
        interactiveRect.contains(point) ? super.hitTest(point) : nil
    }
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

        // 动态猫咪视图（穿透 hit test，鼠标事件由本 NSView 处理）。
        // 把面板宽度传进去，让小猫随悬浮图标尺寸等比缩放。
        let hostingView = PassthroughHostingView(rootView: FloatingCatView(panelSize: frameRect.width))
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
