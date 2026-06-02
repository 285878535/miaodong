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
    /// 每个 panel 在右上角栈中占用的 slot 序号（0=最上）；
    /// 中间被关闭的 panel 会释放 slot，新弹的填进空位，避免重叠。
    private var panelSlots: [UUID: Int] = [:]

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
            if let slot = panelSlots.removeValue(forKey: todo.id) {
                _ = slot   // 释放该 slot，下面 nextAvailableSlot() 会重新分配
            }
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

        let slot = nextAvailableSlot()
        panelSlots[id] = slot
        positionPanel(panel, slot: slot)
        panel.orderFrontRegardless()
        panels[id] = panel
    }

    func dismiss(id: UUID) {
        if let panel = panels[id] {
            panel.orderOut(nil)
            panels.removeValue(forKey: id)
            panelSlots.removeValue(forKey: id)
        }
    }

    func dismissAll() {
        for (_, panel) in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
        panelSlots.removeAll()
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

    /// 鼠标所在屏的右上角；多个弹窗按 slot 向下堆叠（中间释放的 slot 会被新窗复用）。
    private func positionPanel(_ panel: NSPanel, slot: Int) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let frame = panel.frame
        let x = visible.maxX - frame.width - margin
        let stackOffset = CGFloat(slot) * (frame.height + 10)
        let y = visible.maxY - frame.height - margin - stackOffset
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// 从 0 开始找第一个未被占用的 slot
    private func nextAvailableSlot() -> Int {
        let used = Set(panelSlots.values)
        var slot = 0
        while used.contains(slot) { slot += 1 }
        return slot
    }

    private func makeTimeText(for todo: Todo) -> String {
        if let snooze = todo.snoozeUntil {
            return "稍后提醒：" + formatDate(snooze)
        }
        guard let due = todo.dueDate else { return "现在" }
        return formatDate(due)
    }

    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(date) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInTomorrow(date) {
            f.dateFormat = "明天 HH:mm"
        } else {
            f.dateFormat = "M月d日 HH:mm"
        }
        return f.string(from: date)
    }

    private func makeOffsetText(for todo: Todo) -> String? {
        if let snooze = todo.snoozeUntil {
            let remaining = snooze.timeIntervalSince(Date())
            if remaining <= 0 { return "稍后提醒已到" }
            if remaining < 60 { return "\(max(1, Int(ceil(remaining)))) 秒后再次提醒" }
            if remaining < 3600 { return "\(max(1, Int(ceil(remaining / 60)))) 分钟后再次提醒" }
            return "\(max(1, Int(ceil(remaining / 3600)))) 小时后再次提醒"
        }
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
