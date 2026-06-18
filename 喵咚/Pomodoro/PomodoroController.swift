//
//  PomodoroController.swift
//  喵咚
//
//  专注模式窗口控制器 —— 单例 NSPanel，PomodoroSession 是模型，PomodoroView 是 UI。
//

import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class PomodoroController: NSObject, NSWindowDelegate {
    static let shared = PomodoroController()

    private var panel: NSPanel?
    let session = PomodoroSession()

    private override init() {
        super.init()
        // 会话自然结束时弹通知
        session.onFinished = { [weak self] in self?.notifyFinished() }
    }

    // MARK: - 公开 API

    func show() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panelSize = NSSize(width: 360, height: 480)
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
        p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.delegate = self

        let root = PomodoroView(session: session) { [weak self] in self?.close() }
        let hc = NSHostingController(rootView: root)
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        // 关掉 NSHostingController 的屏幕安全区透传，跟 FloatingIconController 一个坑
        hc.safeAreaRegions = []
        p.contentViewController = hc

        positionPanel(p)
        p.orderFrontRegardless()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = p
    }

    func close() {
        panel?.close()
        panel = nil
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in self.panel = nil }
    }

    // MARK: - 位置：屏幕居中

    private func positionPanel(_ p: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { p.center(); return }
        let visible = screen.visibleFrame
        let size = p.frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 + 40
        p.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - 完成通知

    private func notifyFinished() {
        let content = UNMutableNotificationContent()
        content.title = "🎉 一个番茄钟完成啦！"
        if !session.taskLabel.isEmpty {
            content.subtitle = session.taskLabel
        }
        content.body = "已专注 \(session.focusMinutes) 分钟，喵咚陪你的第 \(session.todayCount) 个 🍅"
        content.sound = ReminderSound.notificationSound()

        let request = UNNotificationRequest(
            identifier: "pomodoro-finish-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
