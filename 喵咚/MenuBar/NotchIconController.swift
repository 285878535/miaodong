//
//  NotchIconController.swift
//  喵咚
//
//  灵动岛位置入口 —— 在 MacBook 刘海处显示一个黑色 NotchShape，
//  鼠标 hover 时展开成大面板承载待办 ContentView。
//
//  实现取自 openIsland 的"刘海岛显示框架"思路：
//    1) 全屏宽 + 750pt 高的透明 NSPanel 覆盖屏幕顶部一带；
//    2) NotchPanel.constrainFrameRect 跳过系统安全区裁剪，让窗口真正"进入"刘海；
//    3) 闭合态 ignoresMouseEvents = true，点击穿透到菜单栏；
//    4) 展开态 ignoresMouseEvents = false，面板内可交互；
//    5) 全局/本地 NSEvent monitor 跟踪鼠标位置，进入刘海命中区 → open；
//       离开展开面板矩形 → close。
//

import AppKit
import SwiftUI
import CoreData

@MainActor
final class NotchIconController: NSObject {
    static let shared = NotchIconController()

    private var panel: NotchPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var viewModel: NotchIslandViewModel?

    private var screenObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var keyboardMonitor: Any?

    private var context: NSManagedObjectContext?

    private var currentScreen: NSScreen?

    /// 窗口总高（与 openIsland 保持一致：750pt 足够任何展开面板）
    private let windowHeight: CGFloat = 750

    private override init() {
        super.init()
    }

    // MARK: - 公共 API

    func setup<Content: View>(rootView: Content, context: NSManagedObjectContext? = nil) {
        self.context = context
        teardown()

        guard let screen = NSScreen.notchPreferred else { return }
        currentScreen = screen

        let geometry = computeGeometry(for: screen)
        let metrics = screen.notchMetrics

        let viewModel = NotchIslandViewModel(
            deviceNotchRect: geometry.deviceNotchRect,
            screenRect: geometry.screenRect,
            windowHeight: windowHeight,
            hasPhysicalNotch: metrics.hasPhysicalNotch
        )
        self.viewModel = viewModel

        let panel = NotchPanel(
            contentRect: geometry.windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel = panel

        let island = NotchIslandView(viewModel: viewModel) {
                AnyView(rootView)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.clear)

        let islandRoot = if let context {
            AnyView(island.environment(\.managedObjectContext, context))
        } else {
            AnyView(island)
        }
        let hosting = NSHostingController(rootView: islandRoot)
        // wantsLayer = true 之后 layer 才存在；显式清空 isOpaque 和 backgroundColor
        // 防止透明 NSPanel 在某些 macOS 版本上出现白色闪烁或渲染残影。
        hosting.view.wantsLayer = true
        hosting.view.layer?.isOpaque = false
        hosting.view.layer?.backgroundColor = CGColor.clear
        self.hostingController = hosting

        panel.contentViewController = hosting
        panel.setFrame(geometry.windowFrame, display: true)
        panel.orderFrontRegardless()

        installEventMonitors()
        installScreenObserver()
    }

    func teardown() {
        removeEventMonitors()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
            self.spaceObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
        hostingController = nil
        viewModel = nil
        currentScreen = nil
    }

    // MARK: - 几何

    private struct Geometry {
        let deviceNotchRect: CGRect
        let screenRect: CGRect
        let windowFrame: NSRect
    }

    private func computeGeometry(for screen: NSScreen) -> Geometry {
        let screenFrame = screen.frame
        let notchSize = screen.notchSize
        let deviceNotchRect = CGRect(
            x: (screenFrame.width - notchSize.width) / 2,
            y: 0,
            width: notchSize.width,
            height: notchSize.height
        )
        let windowFrame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )
        return Geometry(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenFrame,
            windowFrame: windowFrame
        )
    }

    // MARK: - 屏幕变化（外接屏插拔/分辨率切换）

    private func installScreenObserver() {
        // 外接屏插拔 / 分辨率切换
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reposition() }
        }

        // 切换 Mission Control / Spaces 时强制归位。
        // macOS 在 Space 切换期间有时会将 NSPanel 向下偏移一个状态栏高度（~38pt），
        // 即使 collectionBehavior 包含 .stationary 也无法完全阻止。
        // 在 activeSpaceDidChange 回调里重新 setFrame 可以把 panel 拉回正确位置。
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reposition() }
        }
    }

    private func reposition() {
        guard let panel,
              let viewModel,
              let screen = NSScreen.notchPreferred else { return }
        currentScreen = screen
        let geometry = computeGeometry(for: screen)
        let metrics = screen.notchMetrics
        viewModel.updateGeometry(
            deviceNotchRect: geometry.deviceNotchRect,
            screenRect: geometry.screenRect,
            windowHeight: windowHeight,
            hasPhysicalNotch: metrics.hasPhysicalNotch
        )
        panel.setFrame(geometry.windowFrame, display: true)
    }

    // MARK: - 事件监听（hover / click）

    private func installEventMonitors() {
        removeEventMonitors()

        let moveMask: NSEvent.EventTypeMask = [.mouseMoved]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: moveMask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMoved(event)
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: moveMask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMoved(event)
            }
            return event
        }

        let clickMask: NSEvent.EventTypeMask = [.leftMouseDown]
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clickMask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseDown(event)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clickMask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseDown(event)
            }
            return event
        }

        // Cmd+N：.nonactivatingPanel 永远不是 key window，SwiftUI .keyboardShortcut 不触发，
        // 需要在本地事件监听里手动拦截。面板展开时消费事件，闭合时放行。
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  self.viewModel?.status == .opened,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers == "n"
            else { return event }
            Task { @MainActor [weak self] in
                guard let ctx = self?.context else { return }
                AddTodoWindowController.shared.show(context: ctx)
            }
            return nil  // 消费掉，不再向下传递
        }
    }

    private func removeEventMonitors() {
        for monitor in [globalMouseMonitor, localMouseMonitor, globalClickMonitor, localClickMonitor, keyboardMonitor] {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        globalClickMonitor = nil
        localClickMonitor = nil
        keyboardMonitor = nil
    }

    private func handleMouseMoved(_ event: NSEvent) {
        guard let viewModel else { return }
        let mouse = NSEvent.mouseLocation
        switch viewModel.status {
        case .closed:
            if viewModel.isPointInNotch(mouse) {
                viewModel.open()
                refreshPanelInteractivity()
            }
        case .opened:
            if !viewModel.isPointInOpenedPanel(mouse) {
                viewModel.close()
                refreshPanelInteractivity()
            }
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let viewModel else { return }
        let mouse = NSEvent.mouseLocation
        // 闭合状态下点击刘海也能打开（方便快速访问）
        if viewModel.status == .closed, viewModel.isPointInNotch(mouse) {
            viewModel.open()
            refreshPanelInteractivity()
        }
    }

    /// 根据 status 切换 panel 的鼠标穿透状态
    private func refreshPanelInteractivity() {
        guard let panel, let viewModel else { return }
        switch viewModel.status {
        case .opened:
            panel.ignoresMouseEvents = false
            NSApp.activate(ignoringOtherApps: false)
        case .closed:
            panel.ignoresMouseEvents = true
        }
    }
}
