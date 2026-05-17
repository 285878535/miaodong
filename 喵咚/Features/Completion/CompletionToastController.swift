//
//  CompletionToastController.swift
//  喵咚
//
//  右上角"任务完成"通知的 NSPanel 管理器
//  - 与 AlertWindowController 错开堆叠
//  - 入场弹性 + 自动消失（默认 2.5s）+ 出场淡出
//

import AppKit
import SwiftUI

@MainActor
final class CompletionToastController {
    static let shared = CompletionToastController()

    /// 同时存在的所有通知面板 —— key 用一次性 UUID 即可（同一 todo 多次完成可叠多张）
    private var panels: [UUID: NSPanel] = [:]

    /// 自动消失时间
    private let displayDuration: TimeInterval = 2.5

    private init() {}

    // MARK: - 公开 API

    /// 单个任务完成
    func show(for todo: Todo) {
        show(style: .single(title: todo.title))
    }

    /// 今日全部完成
    func showAllDone() {
        show(style: .allDone)
    }

    /// 自定义文案
    func show(title: String, subtitle: String) {
        show(style: .custom(title: title, subtitle: subtitle))
    }

    // MARK: - 内部

    private func show(style: CompletionToast.Style) {
        let id = UUID()
        let panel = makePanel()

        let content = CompletionToast(style: style) { [weak self] in
            self?.dismiss(id: id)
        }
        let hosting = NSHostingController(rootView: content)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hosting
        panel.setContentSize(NSSize(width: 320, height: 76))

        positionPanel(panel)
        panel.orderFrontRegardless()
        panels[id] = panel

        // 自动消失
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) { [weak self] in
            self?.dismiss(id: id)
        }
    }

    private func dismiss(id: UUID) {
        guard let panel = panels[id] else { return }
        panels.removeValue(forKey: id)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.alphaValue = 1
        return panel
    }

    /// 屏幕右上角；与 AlertWindow 错开 + 多张通知自动向下叠
    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let frame = panel.frame
        let x = visible.maxX - frame.width - margin

        // 已经存在的通知数量 —— 决定垂直堆叠
        let stackOffset = CGFloat(panels.count) * (frame.height + 8)
        let y = visible.maxY - frame.height - margin - stackOffset

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
