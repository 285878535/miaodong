//
//  AddTodoWindowController.swift
//  喵咚
//

import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AddTodoWindowController: NSObject, NSWindowDelegate {
    static let shared = AddTodoWindowController()

    private var window: NSPanel?
    /// 当前正在编辑的 todo（nil = 新增模式）
    private weak var editingTodo: Todo?

    private override init() {
        super.init()
    }

    // MARK: - 公开 API

    /// 新增模式
    func show(modelContainer: ModelContainer) {
        show(modelContainer: modelContainer, editing: nil)
    }

    /// 编辑模式（editing 非 nil）
    func show(modelContainer: ModelContainer, editing: Todo?) {
        // 已开着窗口：如果模式不同（新增 ↔ 编辑、或换了一个编辑对象），先关掉重开
        if let existing = window {
            let sameTarget: Bool = {
                if editing == nil && editingTodo == nil { return true }
                if let a = editing, let b = editingTodo, a.id == b.id { return true }
                return false
            }()
            if sameTarget {
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            } else {
                close()
            }
        }

        editingTodo = editing
        let ctx = modelContainer.mainContext

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
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
            onSubmit: { [weak self] parsed in
                if let target = editingRef {
                    // 编辑模式：把字段写回原 todo
                    target.title = parsed.title
                    target.dueDate = parsed.dueDate
                    target.notifyOffsetSeconds = parsed.notifyOffsetSeconds
                    target.repeatIntervalSeconds = parsed.repeatIntervalSeconds
                    target.isRecurring = parsed.isRecurring
                    target.recurringPattern = parsed.recurringPattern
                    target.priority = parsed.priority
                    target.tags = parsed.tags
                    // 编辑后视为已重新安排：清掉旧 snooze、按新规则重排
                    target.clearSnooze()
                    try? ctx.save()
                    NotificationManager.shared.cancel(todoId: target.id)
                    NotificationManager.shared.schedule(for: target)
                } else {
                    ctx.insert(parsed)
                    try? ctx.save()
                    NotificationManager.shared.schedule(for: parsed)
                }
                ReminderScheduler.shared.reload()
                self?.close()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        .modelContainer(modelContainer)

        let hc = NSHostingController(rootView: root)
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hc
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = panel
    }

    func close() {
        window?.close()
        window = nil
        editingTodo = nil
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.window = nil
            self.editingTodo = nil
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
