//
//  NotificationManager.swift
//  喵咚
//
//  系统通知兜底（App 在但 Popover 没打开时也能收到铃声/横幅）
//  - 单例自带 UNUserNotificationCenterDelegate，前台横幅 + 点击横幅 → AlertWindow
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    /// 持有 delegate 桥（避免被释放），UNUserNotificationCenter.delegate 仅是 weak 引用
    private var delegateBridge: NotificationDelegateBridge?

    private override init() {
        super.init()
        let bridge = NotificationDelegateBridge()
        bridge.didReceive = { identifier in
            // 横幅被点击 → 弹应用内 AlertWindow（如果 todo 还存在且未完成）
            guard let uuid = UUID(uuidString: identifier) else { return }
            ReminderScheduler.shared.triggerAlert(for: uuid)
        }
        UNUserNotificationCenter.current().delegate = bridge
        self.delegateBridge = bridge
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// 为某个 Todo 注册系统通知（首次到点）。幂等：会先清理同 id 的旧请求。
    func schedule(for todo: Todo) {
        // 先取消同 id 旧请求（修改 dueDate / snooze 时会再次入口）
        cancel(todoId: todo.id)

        guard let fireDate = todo.notifyDate, fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "喵咚提醒"
        content.body = todo.title
        content.sound = .default

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let req = UNNotificationRequest(identifier: todo.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    func cancel(todoId: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [todoId.uuidString])
    }
}

// MARK: - UNUserNotificationCenter delegate 桥
//
// UNUserNotificationCenter 的 delegate 协议在 Swift 6 严格并发下不能直接挂 @MainActor 类，
// 拆成 nonisolated bridge → 跳回 MainActor 处理业务。

private final class NotificationDelegateBridge: NSObject, UNUserNotificationCenterDelegate {
    /// 用户在横幅 / 通知中心点击了通知
    var didReceive: ((String) -> Void)?

    /// 前台时也展示横幅 + 声音；否则系统会静默吞掉
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        Task { @MainActor in
            self.didReceive?(id)
        }
        completionHandler()
    }
}
