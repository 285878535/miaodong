//
//  AddTodoWindowController.swift
//  喵咚
//

import AppKit
import SwiftUI
import CoreData

@MainActor
final class AddTodoWindowController: NSObject, NSWindowDelegate {
    static let shared = AddTodoWindowController()

    private var window: NSPanel?
    /// 当前正在编辑的 todo id（nil = 新增模式）。用值类型而非 weak 对象，避免去重判断受对象释放影响。
    private var editingTodoID: UUID?

    private override init() {
        super.init()
    }

    // MARK: - 公开 API

    /// 新增模式
    func show(context: NSManagedObjectContext) {
        show(context: context, editing: nil)
    }

    /// 编辑模式（editing 非 nil）
    func show(context: NSManagedObjectContext, editing: Todo?) {
        // 收起悬浮主面板，避免它残留在添加/编辑窗口背后露出深色边
        FloatingIconController.shared.hideContentPanel()

        // 复用：仅当已有「仍可见」的窗口且编辑目标相同时，前置复用。
        // 必须判断 isVisible —— 否则可能把一个正在关闭的窗口重新唤起，叠出第二个窗口。
        if let existing = window, existing.isVisible, editingTodoID == editing?.id {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // 其余情况（无窗口 / 目标不同 / 旧窗口正在关闭）一律先彻底关掉，保证全程只有一个窗口
        close()

        editingTodoID = editing?.id
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
        // 让 SwiftUI 背景色完整显示，不被系统毛玻璃覆盖
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // 允许从窗口任意空白区域拖拽（避开 TextEditor / 按钮等交互区由 SwiftUI 自身命中处理）
        panel.isMovable = true
        panel.isMovableByWindowBackground = true

        let initialText = editing.map { Self.composeInitialText(from: $0) } ?? ""
        let editingRef = editing

        let root = AddTodoView(
            initialText: initialText,
            isEditing: editing != nil,
            onSubmit: { [weak self] draft in
                if let target = editingRef {
                    // 编辑模式：把字段写回原 todo
                    target.title = draft.title
                    target.dueDate = draft.dueDate
                    target.notifyOffsetSeconds = draft.notifyOffsetSeconds
                    target.repeatIntervalSeconds = draft.repeatIntervalSeconds
                    target.isRecurring = draft.isRecurring
                    target.recurringPattern = draft.recurringPattern
                    target.priority = draft.priority
                    target.tags = draft.tags
                    // 编辑后视为已重新安排：清掉旧 snooze、按新规则重排
                    target.clearSnooze()
                    try? ctx.save()
                    NotificationManager.shared.cancel(todoId: target.id)
                    NotificationManager.shared.schedule(for: target)
                } else {
                    let todo = Todo(context: ctx, draft: draft)
                    try? ctx.save()
                    NotificationManager.shared.schedule(for: todo)
                }
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
        editingTodoID = nil
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        Task { @MainActor in
            // 只在关闭的确实是当前窗口时清引用，避免迟到的旧窗口关闭通知把新窗口的引用清空，
            // 从而导致下次打开又新建一个、屏幕上叠出两个编辑窗口。
            guard closing === self.window else { return }
            self.window = nil
            self.editingTodoID = nil
        }
    }

    // MARK: - 编辑预填文本

    /// 把 todo 还原成接近原始自然语言的字符串，便于用户修改
    /// 例如："今天 17:00 写周报 提前 10 分钟提醒 间隔 5 分钟"
    private static func composeInitialText(from todo: Todo) -> String {
        var parts: [String] = []

        // 日期 + 时间
        if let due = todo.dueDate {
            parts.append(humanDate(due, isRecurring: todo.isRecurring, pattern: todo.recurringPattern))
        }

        // 标题
        if !todo.title.isEmpty {
            parts.append(todo.title)
        }

        // 提前提醒
        if todo.notifyOffsetSeconds > 0 {
            parts.append("提前 \(humanDuration(todo.notifyOffsetSeconds)) 提醒")
        }

        // 间隔重复
        if let interval = todo.repeatIntervalSeconds, interval > 0 {
            parts.append("间隔 \(humanDuration(interval))")
        }

        return parts.joined(separator: " ")
    }

    private static func humanDate(_ d: Date, isRecurring: Bool, pattern: String?) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        let cal = Calendar.current

        if isRecurring, let pattern {
            f.dateFormat = "HH:mm"
            let prefix: String = {
                if pattern == "daily" { return "每天" }
                if pattern == "weekdays" { return "工作日" }
                if pattern.hasPrefix("weekly:") { return "每周" }
                if pattern.hasPrefix("monthly:") { return "每月" }
                return ""
            }()
            return "\(prefix) \(f.string(from: d))".trimmingCharacters(in: .whitespaces)
        }
        if cal.isDateInToday(d) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInTomorrow(d) {
            f.dateFormat = "明天 HH:mm"
        } else {
            f.dateFormat = "M月d日 HH:mm"
        }
        return f.string(from: d)
    }

    private static func humanDuration(_ seconds: Int) -> String {
        if seconds >= 86_400, seconds % 86_400 == 0 { return "\(seconds / 86_400) 天" }
        if seconds >= 3600, seconds % 3600 == 0 { return "\(seconds / 3600) 小时" }
        if seconds >= 60, seconds % 60 == 0 { return "\(seconds / 60) 分钟" }
        return "\(seconds) 秒"
    }
}
