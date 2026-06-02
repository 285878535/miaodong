//
//  MenuBarController.swift
//  喵咚
//
//  状态栏入口：NSStatusItem + NSPopover，支持点击 + 悬停展开
//
//  图标：与 SettingsView 的 PixelCatMiniView 完全一致 —— complete1-8 PNG 序列帧
//        0.64s 一帧循环播放。SF Symbol "cat" 在 macOS 上不存在，必须自己用 PNG。
//

import AppKit
import SwiftUI
import SwiftData
import Combine

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hoverWorkItem: DispatchWorkItem?

    // MARK: - 像素猫动画（complete1-8 序列帧）

    private var animationTimer: Timer?
    private var frameIndex: Int = 0
    /// 与 PixelCatMiniView / NotchIslandView 保持一致的切帧节奏
    private let frameInterval: TimeInterval = 0.64
    /// 帧总数（complete1.png ~ complete8.png）
    private let frameCount: Int = 8
    /// 菜单栏里像素猫展示尺寸。
    /// macOS 菜单栏 thickness 通常 24pt，刨掉 1~2pt 上下安全边，
    /// 22pt 高度差不多就是顶满；保持 ~1.27 宽高比 → 28 宽。
    private let iconSize = NSSize(width: 28, height: 22)

    private override init() {
        super.init()
    }

    func setup<Content: View>(rootView: Content, modelContainer: ModelContainer? = nil) {
        // modelContainer 参数保留 —— AppDelegate 已经在传，未来如果要回到根据 todo
        // 状态切换动画再用；当前 complete1-8 不依赖 SwiftData，所以这里不持有。
        _ = modelContainer

        // 用 variableLength 而不是 squareLength —— 让 status item 按图片宽度伸展，
        // 否则 squareLength (~22pt) 会把 28pt 宽的像素猫挤窄，看起来比别的图标小。
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
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

        // 装第一帧并启动动画循环
        applyCurrentFrame()
        startAnimation()
    }

    /// 切换到悬浮模式时拆掉 status item
    func teardown() {
        stopAnimation()
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

    // MARK: - 像素猫序列帧动画

    private func startAnimation() {
        stopAnimation()
        let timer = Timer(timeInterval: frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        // .common 让滚动 / hover 期间也保持切帧
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func tick() {
        frameIndex = (frameIndex + 1) % frameCount
        applyCurrentFrame()
    }

    /// 把当前帧装到 status button 上
    private func applyCurrentFrame() {
        guard let button = statusItem?.button else { return }
        let name = "complete\(frameIndex + 1)"
        guard let image = loadFrame(named: name) else { return }
        image.size = iconSize
        // 像素猫是彩色的，不能用 template 否则会被 menu bar 拉成单色
        image.isTemplate = false
        button.image = image
    }

    // MARK: - PNG 帧加载（与 SettingsView.PixelCatMiniView 同款）

    private func loadFrame(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        // Dev 兜底：直接从源码 Resources/ 下读，方便不刷新 Xcode resources 时也能跑
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(name).png")
        return NSImage(contentsOf: sourceURL)
    }
}
