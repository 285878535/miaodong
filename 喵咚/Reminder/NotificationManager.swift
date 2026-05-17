//
//  NotificationManager.swift
//  喵咚
//
//  系统通知兜底（App 在但 Popover 没打开时也能收到铃声/横幅）
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// 为某个 Todo 注册系统通知（首次到点）
    func schedule(for todo: Todo) {
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
