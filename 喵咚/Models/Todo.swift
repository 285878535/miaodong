//
//  Todo.swift
//  喵咚
//

import Foundation
import SwiftData

@Model
final class Todo {
    // 注意：不能用 @Attribute(.unique) —— CloudKit 同步不支持 unique 约束。
    // 业务侧靠 UUID 自身的随机性保证唯一即可。
    var id: UUID
    var title: String
    var notes: String?

    var dueDate: Date?
    var notifyOffsetSeconds: Int
    var repeatIntervalSeconds: Int?

    var isRecurring: Bool
    var recurringPattern: String?

    var isCompleted: Bool
    var completedAt: Date?

    /// 稍后提醒生效时刻：若 > now 则覆盖 notifyDate，触发后自动清空
    var snoozeUntil: Date?

    var priorityRaw: String
    var tagsRaw: [String]
    var iconName: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        notifyOffsetSeconds: Int = 0,
        repeatIntervalSeconds: Int? = nil,
        isRecurring: Bool = false,
        recurringPattern: String? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        snoozeUntil: Date? = nil,
        priority: Priority = .medium,
        tags: [Tag] = [],
        iconName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.notifyOffsetSeconds = notifyOffsetSeconds
        self.repeatIntervalSeconds = repeatIntervalSeconds
        self.isRecurring = isRecurring
        self.recurringPattern = recurringPattern
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.snoozeUntil = snoozeUntil
        self.priorityRaw = priority.rawValue
        self.tagsRaw = tags.map { $0.rawValue }
        self.iconName = iconName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Todo {
    var priority: Priority {
        get { Priority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue; updatedAt = Date() }
    }

    var tags: [Tag] {
        get { tagsRaw.compactMap { Tag(rawValue: $0) } }
        set { tagsRaw = newValue.map { $0.rawValue }; updatedAt = Date() }
    }

    /// 实际提醒时刻：若设置了"稍后提醒"且未到则优先用 snoozeUntil；否则 dueDate - 提前量
    var notifyDate: Date? {
        if let snooze = snoozeUntil, snooze > Date() {
            return snooze
        }
        guard let due = dueDate else { return nil }
        return due.addingTimeInterval(-TimeInterval(notifyOffsetSeconds))
    }

    func snooze(for seconds: TimeInterval) {
        snoozeUntil = Date().addingTimeInterval(seconds)
        updatedAt = Date()
    }

    func clearSnooze() {
        snoozeUntil = nil
        updatedAt = Date()
    }

    func markCompleted() {
        isCompleted = true
        completedAt = Date()
        updatedAt = Date()
    }

    func markUncompleted() {
        isCompleted = false
        completedAt = nil
        updatedAt = Date()
    }

    /// 未完成且 dueDate 已跨日（昨天及更早才算过期；当天即使超时也仍属"今日任务"）
    /// 设计意图：刚到提醒时间不能立刻把任务踢到"已过期"，提醒弹框还在用户面前
    /// 就归到过期是反直觉的。同时，snooze 到未来的任务永远不算过期。
    var isExpired: Bool {
        guard !isCompleted else { return false }
        // 还在 snooze 中 → 任务被推到了未来，不算过期
        if let snooze = snoozeUntil, snooze > Date() { return false }

        let todayStart = Calendar.current.startOfDay(for: Date())
        guard let due = dueDate else {
            // 无截止时间：看创建日期是否早于今天零点
            return createdAt < todayStart
        }
        return due < todayStart
    }
}
