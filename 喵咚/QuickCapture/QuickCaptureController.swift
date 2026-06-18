//
//  QuickCaptureController.swift
//  喵咚
//
//  全局快速捕获面板控制器：屏幕顶部居中弹一个 ~560pt 宽的窄输入框，
//  ESC 关闭、回车保存、点外部自动关闭。
//  与 AddTodoWindowController 解耦 —— 那个是完整面板（带预览/标签/优先级编辑），
//  这个是"边走边记"场景：能多快就多快，不打断手头工作。
//

import AppKit
import SwiftUI
import CoreData

@MainActor
final class QuickCaptureController: NSObject, NSWindowDelegate {
    static let shared = QuickCaptureController()

    private var panel: NSPanel?
    private var context: NSManagedObjectContext?
    private var outsideClickMonitor: Any?

    private override init() {
        super.init()
    }

    /// AppDelegate 启动时调一次，把 Core Data 主上下文攒住
    func attach(context: NSManagedObjectContext) {
        self.context = context
    }

    /// 显示 / 切换：已开着就关，没开就开
    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        guard let ctx = context else {
            NSLog("[QuickCapture] context 还没装好，忽略本次触发")
            return
        }

        // 已经打开过：复用旧 panel 直接前置
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panelSize = NSSize(width: 600, height: 200)  // 留点 padding 给阴影
        let p = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isMovableByWindowBackground = true
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false  // SwiftUI 自己画阴影
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.delegate = self
        p.becomesKeyOnlyIfNeeded = false

        let root = QuickCaptureView(
            onSubmit: { [weak self] draft in
                let todo = Todo(context: ctx, draft: draft)
                try? ctx.save()
                NotificationManager.shared.schedule(for: todo)
                ReminderScheduler.shared.reload()
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        .environment(\.managedObjectContext, ctx)

        let hc = NSHostingController(rootView: root)
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        p.contentViewController = hc

        // 位置：当前活动屏幕顶部 1/3 处居中（参考 Spotlight 视觉重心）
        positionPanel(p)

        p.orderFrontRegardless()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        installOutsideClickMonitor()
        self.panel = p
    }

    func close() {
        removeOutsideClickMonitor()
        panel?.close()
        panel = nil
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.removeOutsideClickMonitor()
            self.panel = nil
        }
    }

    // MARK: - 位置

    /// 鼠标所在屏幕的可视区域顶部 1/3 居中
    private func positionPanel(_ p: NSPanel) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { p.center(); return }

        let visible = screen.visibleFrame
        let size = p.frame.size
        let x = visible.midX - size.width / 2
        // 顶部 1/3：屏幕顶端往下推 ~25% 高度
        let y = visible.maxY - size.height - visible.height * 0.22
        p.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - 点击外部自动关闭

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // 同 FloatingIconController：落在 App 任意 visible 窗口内不算外部
            let mouseLoc = NSEvent.mouseLocation
            let inOurWindow = NSApp.windows.contains { window in
                window.isVisible && window.frame.contains(mouseLoc)
            }
            if inOurWindow { return }
            Task { @MainActor [weak self] in self?.close() }
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
    }
}
