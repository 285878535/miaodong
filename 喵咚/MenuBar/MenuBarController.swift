//
//  MenuBarController.swift
//  喵咚
//
//  状态栏入口：NSStatusItem + NSPopover，支持点击 + 悬停展开
//

import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hoverWorkItem: DispatchWorkItem?

    private override init() {
        super.init()
    }

    func setup<Content: View>(rootView: Content) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            let image = NSImage(systemSymbolName: "cat", accessibilityDescription: "喵咚")
            if let image {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "喵"
            }
            button.target = self
            button.action = #selector(buttonClicked(_:))

            let area = NSTrackingArea(
                rect: button.bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            button.addTrackingArea(area)
        }

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        pop.contentSize = NSSize(width: 360, height: 520)

        // 让 NSPopover 使用干净背景，避免毛玻璃深色覆盖 SwiftUI 颜色
        let hc = NSHostingController(rootView: rootView)
        hc.view.wantsLayer = true
        hc.view.layer?.backgroundColor = NSColor.clear.cgColor
        pop.contentViewController = hc

        self.statusItem = item
        self.popover = pop
    }

    /// 切换到悬浮模式时拆掉 status item
    func teardown() {
        if let popover, popover.isShown {
            popover.performClose(nil)
        }
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        popover = nil
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }

    // MARK: - 点击

    @objc private func buttonClicked(_ sender: Any?) {
        toggle()
    }

    // MARK: - 悬停（≈0.3s 延迟，避免穿越误触）

    @objc(mouseEntered:)
    func mouseEntered(with event: NSEvent) {
        guard let popover, !popover.isShown else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.show()
        }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    @objc(mouseExited:)
    func mouseExited(with event: NSEvent) {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }

    // MARK: - 展开 / 收起

    private func toggle() {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            show()
        }
    }

    private func show() {
        guard let popover, let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
