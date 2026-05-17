//
//  AlertWindowController.swift
//  喵咚
//
//  最高层级 NSPanel 弹窗 —— 在所有 App 上方（含全屏），不抢焦点
//

import AppKit
import SwiftUI

@MainActor
final class AlertWindowController {
    static let shared = AlertWindowController()

    private var panels: [UUID: NSPanel] = [:]

    private init() {}

    /// 弹出提醒
    func show(for todo: Todo,
              onComplete: @escaping (Todo) -> Void,
              onSnooze: @escaping (Todo, TimeInterval) -> Void,
              onDismiss: @escaping (Todo) -> Void) {

        // 若已有相同 todo 的面板，先关掉再重弹（避免堆叠到屏外）
        if let existing = panels[todo.id] {
            existing.orderOut(nil)
            panels.removeValue(forKey: todo.id)
        }

        let id = todo.id

        let panel = makePanel()

        let content = AlertView(
            title: todo.title,
            timeText: makeTimeText(for: todo),
            offsetText: makeOffsetText(for: todo),
            intervalText: makeIntervalText(for: todo),
            onComplete: { [weak self] in
                self?.dismiss(id: id)
                onComplete(todo)
            },
            onSnooze: { [weak self] seconds in
                self?.dismiss(id: id)
                onSnooze(todo, seconds)
            },
            onDismiss: { [weak self] in
                self?.dismiss(id: id)
                onDismiss(todo)
            }
        )

        let hosting = NSHostingController(rootView: content)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hosting
        panel.setContentSize(NSSize(width: 380, height: 200))

        positionPanel(panel)
        panel.orderFrontRegardless()
        panels[id] = panel
    }

    func dismiss(id: UUID) {
        if let panel = panels[id] {
            panel.orderOut(nil)
            panels.removeValue(forKey: id)
        }
    }

    func dismissAll() {
        for (_, panel) in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
    }

    // MARK: - 内部

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver            // 高于全屏 App
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        return panel
    }

    /// 屏幕右上角；多个弹窗自动向下堆叠
    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let frame = panel.frame
        let x = visible.maxX - frame.width - margin
        // 已有面板数量决定纵向偏移
        let stackOffset = CGFloat(panels.count) * (frame.height + 10)
        let y = visible.maxY - frame.height - margin - stackOffset
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func makeTimeText(for todo: Todo) -> String {
        guard let due = todo.dueDate else { return "现在" }
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(due) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInTomorrow(due) {
            f.dateFormat = "明天 HH:mm"
        } else {
            f.dateFormat = "M月d日 HH:mm"
        }
        return f.string(from: due)
    }

    private func makeOffsetText(for todo: Todo) -> String? {
        guard todo.notifyOffsetSeconds > 0 else { return nil }
        return "提前 \(humanInterval(todo.notifyOffsetSeconds)) 提醒"
    }

    private func makeIntervalText(for todo: Todo) -> String? {
        guard let interval = todo.repeatIntervalSeconds, interval > 0 else { return nil }
        return "每 \(humanInterval(interval)) 再提醒"
    }

    private func humanInterval(_ seconds: Int) -> String {
        if seconds % 3600 == 0 { return "\(seconds / 3600) 小时" }
        if seconds % 60 == 0 { return "\(seconds / 60) 分钟" }
        return "\(seconds) 秒"
    }
}
