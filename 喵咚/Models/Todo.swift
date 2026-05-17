//
//  Todo.swift
//  喵咚
//

import Foundation
import SwiftData

@Model
final class Todo {
    @Attribute(.unique) var id: UUID
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
}
