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
import CoreData
import Combine

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var hoverWorkItem: DispatchWorkItem?

    // MARK: - 像素猫动画（按任务状态切换：wave 挥手 / sleep 睡觉）

    private var animationTimer: Timer?
    private var frameIndex: Int = 0
    /// 与 PixelCatMiniView / NotchIslandView 保持一致的切帧节奏
    private let frameInterval: TimeInterval = 0.64
    /// 当前帧集：有未完成任务播 wave3-6，否则 sleep5-8（与灵动岛/悬浮一致）
    private var currentFrames: [String] = (5...8).map { "sleep\($0)" }
    /// 订阅共享任务活跃状态
    private var activityCancellable: AnyCancellable?
    /// 菜单栏里像素猫展示尺寸。高度给到略超菜单栏内容区，让系统把小猫缩放填满高度，
    /// 视觉上尽量大；保持 ~1.3 宽高比（帧约 42×32）。
    private let iconSize = NSSize(width: 37, height: 28)

    private override init() {
        super.init()
    }

    func setup<Content: View>(rootView: Content, context: NSManagedObjectContext? = nil) {
        // context 参数保留 —— AppDelegate 已经在传，未来如果要回到根据 todo
        // 状态切换动画再用；当前 complete1-8 不依赖 Core Data，所以这里不持有。
        _ = context

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

        // 小猫在左、待办数字在右，并让图像紧贴数字，缩小两者间距
        item.button?.imagePosition = .imageLeft
        item.button?.imageHugsTitle = true

        // 订阅未完成任务数：切换帧集 + 更新数字（订阅时立即收到当前值）
        activityCancellable = CatActivityState.shared.$activeCount.sink { [weak self] count in
            Task { @MainActor in self?.applyActivity(count: count) }
        }

        // 装第一帧并启动动画循环
        applyCurrentFrame()
        startAnimation()
    }

    /// 根据未完成任务数切换帧集并显示数量
    private func applyActivity(count: Int) {
        updateFrameSet(active: count > 0)
        // 数字紧跟小猫右侧（无前导空格）；为 0 时不显示
        statusItem?.button?.title = count > 0 ? "\(count)" : ""
    }

    /// 根据是否有未完成任务切换帧集
    private func updateFrameSet(active: Bool) {
        let names = active ? (3...6).map { "wave\($0)" } : (5...8).map { "sleep\($0)" }
        guard names != currentFrames else { return }
        currentFrames = names
        frameIndex = 0
        applyCurrentFrame()
    }

    /// 切换到悬浮模式时拆掉 status item
    func teardown() {
        stopAnimation()
        activityCancellable?.cancel()
        activityCancellable = nil
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
        frameIndex = (frameIndex + 1) % currentFrames.count
        applyCurrentFrame()
    }

    /// 把当前帧装到 status button 上
    private func applyCurrentFrame() {
        guard let button = statusItem?.button else { return }
        let name = currentFrames[frameIndex % currentFrames.count]
        guard let image = loadFrame(named: name) else { return }
        image.size = iconSize
        // 像素猫是彩色的，不能用 template 否则会被 menu bar 拉成单色
        image.isTemplate = false
        button.image = image
    }

    // MARK: - PNG 帧加载（与 SettingsView.PixelCatMiniView 同款）

    private func loadFrame(named name: String) -> NSImage? {
        // wave / sleep 帧在 Resources/SleepCat 下，优先按子目录找，再退回根目录
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "SleepCat") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        // Dev 兜底：直接从源码 Resources/ 下读，方便不刷新 Xcode resources 时也能跑
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
        let candidates = [
            base.appendingPathComponent("SleepCat").appendingPathComponent("\(name).png"),
            base.appendingPathComponent("\(name).png"),
        ]
        return candidates.lazy.compactMap { NSImage(contentsOf: $0) }.first
    }
}
