//
//  CompletedTodoWindowController.swift
//  喵咚
//
//  已完成任务的「只读详情」窗口控制器。承载 CompletedTodoView：
//  查看完整内容（不可编辑），并支持「设为新任务」复制成一条相同内容的新待办。
//

import AppKit
import SwiftUI
import CoreData

@MainActor
final class CompletedTodoWindowController: NSObject, NSWindowDelegate {
    static let shared = CompletedTodoWindowController()

    private var window: NSPanel?
    /// 当前正在查看的 todo id（用值类型，避免去重判断受对象释放影响）
    private var viewingTodoID: UUID?

    private override init() {
        super.init()
    }

    func show(context: NSManagedObjectContext, todo: Todo) {
        // 收起悬浮主面板，避免它残留在详情窗口背后露出深色边
        FloatingIconController.shared.hideContentPanel()

        // 复用：仅当已有「仍可见」的窗口且查看的是同一条时前置复用
        if let existing = window, existing.isVisible, viewingTodoID == todo.id {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // 其余情况一律先彻底关掉，保证全程只有一个窗口
        close()

        viewingTodoID = todo.id
        let ctx = context

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .screenSaver
        // NSPanel 默认 hidesOnDeactivate=true：切到别的 App 会自动隐藏、回来又冒出来。关掉它。
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isMovable = true
        panel.isMovableByWindowBackground = true

        let root = CompletedTodoView(
            todo: todo,
            onDuplicate: { [weak self] in
                // 用相同内容创建一条全新的未完成待办（completed/snooze 由默认值重置）
                let draft = TodoDraft(
                    title: todo.title,
                    notes: todo.notes,
                    dueDate: todo.dueDate,
                    notifyOffsetSeconds: todo.notifyOffsetSeconds,
                    repeatIntervalSeconds: todo.repeatIntervalSeconds,
                    isRecurring: todo.isRecurring,
                    recurringPattern: todo.recurringPattern,
                    priority: todo.priority,
                    tags: todo.tags,
                    iconName: todo.iconName
                )
                let new = Todo(context: ctx, draft: draft)
                try? ctx.save()
                NotificationManager.shared.schedule(for: new)
                ReminderScheduler.shared.reload()
                self?.close()
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        .environment(\.managedObjectContext, ctx)

        let hc = NSHostingController(rootView: root)
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hc
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        self.window = panel
    }

    func close() {
        window?.orderOut(nil)
        window?.close()
        window = nil
        viewingTodoID = nil
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        Task { @MainActor in
            guard closing === self.window else { return }
            self.window = nil
            self.viewingTodoID = nil
        }
    }
}
