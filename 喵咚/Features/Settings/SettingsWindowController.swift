//
//  SettingsWindowController.swift
//  喵咚
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show() {
        // 收起悬浮主面板，避免它残留在设置窗口背后露出深色边
        FloatingIconController.shared.hideContentPanel()

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "喵咚 设置"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        positionNearFrontWindow(win)
        win.delegate = self
        // 背景与 SwiftUI 背景色匹配
        win.backgroundColor = NSColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)
        let hc = NSHostingController(rootView: SettingsView())
        hc.view.wantsLayer = true
        win.contentViewController = hc

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    /// 把设置窗口居中叠在"打开它的那个窗口"（主面板 / 灵动岛 / 悬浮窗）上，
    /// 而不是永远屏幕居中。在 makeKeyAndOrderFront 之前调用，此时 keyWindow 仍是来源面板。
    private func positionNearFrontWindow(_ win: NSWindow) {
        let anchor = NSApp.keyWindow
            ?? NSApp.orderedWindows.first { $0 !== win && $0.isVisible && $0.frame.width > 1 }

        guard let anchor, anchor !== win else { win.center(); return }

        let a = anchor.frame
        let size = win.frame.size
        var origin = NSPoint(x: a.midX - size.width / 2, y: a.midY - size.height / 2)

        // 夹在来源窗口所在屏幕的可视区内，避免被推到屏幕外
        if let vf = (anchor.screen ?? NSScreen.main)?.visibleFrame {
            origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
            origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        }
        win.setFrameOrigin(origin)
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in self.window = nil }
    }
}
