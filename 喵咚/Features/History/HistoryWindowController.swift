//
//  HistoryWindowController.swift
//  喵咚
//
//  历史任务窗口控制器（独立 NSWindow，可拖动 / 可关闭 / 可最小化）
//

import AppKit
import SwiftUI
import CoreData

@MainActor
final class HistoryWindowController: NSObject, NSWindowDelegate {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    func show(context: NSManagedObjectContext) {
        // 收起悬浮主面板，避免它残留在历史窗口背后露出深色边
        FloatingIconController.shared.hideContentPanel()

        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "喵咚 历史任务"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.center()
        win.delegate = self
        // 背景与 SwiftUI 米色一致，避免毛玻璃灰区
        win.backgroundColor = NSColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1.0)

        let root = HistoryView()
            .environment(\.managedObjectContext, context)

        let hc = NSHostingController(rootView: root)
        hc.view.wantsLayer = true
        win.contentViewController = hc

        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = win
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in self.window = nil }
    }
}
