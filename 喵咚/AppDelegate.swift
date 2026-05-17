//
//  AppDelegate.swift
//  喵咚
//

import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var container: ModelContainer!

    private var currentIconMode: IconDisplayMode?
    private var modeChangeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1) 数据容器
        do {
            container = try TodoStore.makeDefaultContainer()
        } catch {
            fatalError("ModelContainer 初始化失败: \(error)")
        }

        // 2) 调度器 + 弹窗
        ReminderScheduler.shared.attach(container: container)
        ReminderScheduler.shared.onFire = { [weak self] todo in
            guard let self else { return }
            let ctx = self.container.mainContext
            AlertWindowController.shared.show(
                for: todo,
                onComplete: { t in
                    t.markCompleted()
                    t.clearSnooze()
                    try? ctx.save()
                    NotificationManager.shared.cancel(todoId: t.id)
                    ReminderScheduler.shared.reload()
                },
                onSnooze: { t, seconds in
                    t.snooze(for: seconds)
                    try? ctx.save()
                    ReminderScheduler.shared.reload()
                },
                onDismiss: { _ in
                    // 间隔重复继续；首次提醒已消费
                }
            )
        }
        NotificationManager.shared.requestAuthorizationIfNeeded()
        ReminderScheduler.shared.reload()

        // 3) 按设置项装载图标显示模式
        applyIconMode()

        // 4) 监听运行时切换
        modeChangeObserver = NotificationCenter.default.addObserver(
            forName: .iconDisplayModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.applyIconMode() }
        }
    }

    deinit {
        if let modeChangeObserver {
            NotificationCenter.default.removeObserver(modeChangeObserver)
        }
    }

    // MARK: - 图标显示模式装载

    private func applyIconMode() {
        // 默认改为 .notch（参照 openIsland 的灵动岛显示）。
        // 用户在设置里仍可切到 menuBar / floating。
        let raw = UserDefaults.standard.string(forKey: AppSettingsKeys.iconDisplayMode)
                  ?? IconDisplayMode.notch.rawValue
        let mode = IconDisplayMode(rawValue: raw) ?? .notch

        // 同模式不重复装载
        if mode == currentIconMode { return }
        currentIconMode = mode

        // 切换前先关掉所有其他模式（避免叠加）
        let root = ContentView().modelContainer(container)
        switch mode {
        case .menuBar:
            NotchIconController.shared.teardown()
            FloatingIconController.shared.teardown()
            MenuBarController.shared.setup(rootView: root)
        case .notch:
            MenuBarController.shared.teardown()
            FloatingIconController.shared.teardown()
            NotchIconController.shared.setup(rootView: root)
        case .floating:
            MenuBarController.shared.teardown()
            NotchIconController.shared.teardown()
            FloatingIconController.shared.setup(rootView: root)
        }
    }
}
