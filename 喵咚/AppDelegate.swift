//
//  AppDelegate.swift
//  喵咚
//

import AppKit
import SwiftUI
import CoreData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var container: NSPersistentContainer!

    private var currentIconMode: IconDisplayMode?
    private var modeChangeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1) 数据容器
        do {
            container = try TodoStore.makeDefaultContainer()
        } catch {
            fatalError("ModelContainer 初始化失败: \(error)")
        }

        // 三处图标共享的「有无未完成任务」状态，绑定主上下文（决定小猫挥手/睡觉）
        CatActivityState.shared.attach(context: container.viewContext)

        // 2) 提醒系统：调度器 + 系统通知 + 应用内弹窗
        //    NotificationManager 单例 init 时会自动挂上 UNUserNotificationCenter delegate
        _ = NotificationManager.shared
        NotificationManager.shared.requestAuthorizationIfNeeded()

        ReminderScheduler.shared.attach(container: container)
        ReminderScheduler.shared.onFire = { [weak self] todo in
            guard let self else { return }
            let ctx = self.container.viewContext
            AlertWindowController.shared.show(
                for: todo,
                onComplete: { t in
                    t.markCompleted()
                    t.clearSnooze()
                    try? ctx.save()
                    // ReminderScheduler.cancel 会同时撤销系统通知
                    ReminderScheduler.shared.cancel(todoId: t.id)
                    ReminderScheduler.shared.reload()
                },
                onSnooze: { t, seconds in
                    t.snooze(for: seconds)
                    try? ctx.save()
                    // snooze 重排：先撤销系统通知，reload 内部会按新 notifyDate 重新 schedule
                    ReminderScheduler.shared.reload()
                },
                onDismiss: { t in
                    t.clearSnooze()
                    try? ctx.save()
                    // 间隔重复继续；首次提醒已消费
                }
            )
        }
        ReminderScheduler.shared.reload()

        // 3) 全局快速捕获（⌥Space 默认）
        QuickCaptureController.shared.attach(context: container.viewContext)
        if UserDefaults.standard.object(forKey: AppSettingsKeys.quickCaptureEnabled) as? Bool ?? true {
            GlobalHotkeyManager.shared.onTriggered = {
                QuickCaptureController.shared.toggle()
            }
            GlobalHotkeyManager.shared.registerFromUserDefaults()
        }

        // 4) 按设置项装载图标显示模式 + 监听运行时切换
        applyIconMode()
        modeChangeObserver = NotificationCenter.default.addObserver(
            forName: .iconDisplayModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.applyIconMode() }
        }

        // 5) 后台异步检查更新（有新版本弹 Alert）
        UpdateChecker.shared.checkAndAlertIfNeeded()
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
        switch mode {
        case .menuBar:
            NotchIconController.shared.teardown()
            FloatingIconController.shared.teardown()
            let root = ContentView(attachedToNotch: false)
                .environment(\.managedObjectContext, container.viewContext)
            MenuBarController.shared.setup(rootView: root, context: container.viewContext)
        case .notch:
            MenuBarController.shared.teardown()
            FloatingIconController.shared.teardown()
            let hasPhysicalNotch = NSScreen.notchPreferred?.notchMetrics.hasPhysicalNotch ?? false
            let root = ContentView(attachedToNotch: hasPhysicalNotch)
                .environment(\.managedObjectContext, container.viewContext)
            NotchIconController.shared.setup(rootView: root, context: container.viewContext)
        case .floating:
            MenuBarController.shared.teardown()
            NotchIconController.shared.teardown()
            let root = ContentView(attachedToNotch: false)
                .environment(\.managedObjectContext, container.viewContext)
            FloatingIconController.shared.setup(rootView: root)
        }
    }
}
