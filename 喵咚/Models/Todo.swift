//
//  Todo.swift
//  喵咚
//

import Foundation
import CoreData

/// 新建/编辑待办时在视图与控制器之间传递的纯值类型。
///
/// Core Data 的 NSManagedObject 无法脱离 context 创建（SwiftData 的 @Model 可以先建后插），
/// 因此输入视图不再直接构造 Todo，而是产出 TodoDraft，由控制器在自己的 context 里落库 /
/// 或写回到正在编辑的对象。这样既避开了"在视图 context 里建了又不保存导致残留"的坑，
/// 也让视图保持与持久化无关。
struct TodoDraft {
    var title: String
    var notes: String? = nil
    var dueDate: Date? = nil
    var notifyOffsetSeconds: Int = 0
    var repeatIntervalSeconds: Int? = nil
    var isRecurring: Bool = false
    var recurringPattern: String? = nil
    var priority: Priority = .medium
    var tags: [Tag] = []
    var iconName: String? = nil
}

@objc(Todo)
final class Todo: NSManagedObject, Identifiable {
    // 注意：不能用唯一约束 —— CloudKit 同步不支持 unique constraint。
    // 业务侧靠 UUID 自身的随机性保证唯一即可。
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var notes: String?

    @NSManaged var dueDate: Date?
    @NSManaged var notifyOffsetSeconds: Int
    /// Core Data 标量不能表达 optional，用 NSNumber? 作后备，对外仍暴露 Int?
    @NSManaged private var repeatIntervalRaw: NSNumber?

    @NSManaged var isRecurring: Bool
    @NSManaged var recurringPattern: String?

    @NSManaged var isCompleted: Bool
    @NSManaged var completedAt: Date?

    /// 稍后提醒生效时刻：若 > now 则覆盖 notifyDate，触发后自动清空
    @NSManaged var snoozeUntil: Date?

    @NSManaged var priorityRaw: String
    /// Core Data + CloudKit 不直接支持 [String]，用逗号分隔的字符串存储，对外暴露 [String]。
    /// Tag 的 rawValue 都是无逗号的小写词，拼接安全。
    @NSManaged private var tagsStorage: String?
    @NSManaged var iconName: String?

    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date

    /// 间隔重复秒数（nil = 不重复）
    var repeatIntervalSeconds: Int? {
        get { repeatIntervalRaw?.intValue }
        set { repeatIntervalRaw = newValue.map(NSNumber.init(value:)) }
    }

    /// 标签 rawValue 数组（底层以逗号分隔的字符串存储）
    var tagsRaw: [String] {
        get {
            guard let s = tagsStorage, !s.isEmpty else { return [] }
            return s.split(separator: ",").map(String.init)
        }
        set { tagsStorage = newValue.joined(separator: ",") }
    }

    convenience init(
        context: NSManagedObjectContext,
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
        self.init(context: context)
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

    /// `id` 是唯一没有模型层默认值的非可选属性（UUID 无法在程序化模型里设默认值）。
    /// 这里在对象插入时兜底赋值，防止 CloudKit 同步来一条缺 `id` 字段的记录时，
    /// 后续读取 `todo.id` 触发非可选解包崩溃。本地新建会被 convenience init 的真实值覆盖。
    override func awakeFromInsert() {
        super.awakeFromInsert()
        if value(forKey: "id") == nil {
            id = UUID()
        }
    }

    /// 从草稿在指定 context 里创建
    convenience init(context: NSManagedObjectContext, draft: TodoDraft) {
        self.init(
            context: context,
            title: draft.title,
            notes: draft.notes,
            dueDate: draft.dueDate,
            notifyOffsetSeconds: draft.notifyOffsetSeconds,
            repeatIntervalSeconds: draft.repeatIntervalSeconds,
            isRecurring: draft.isRecurring,
            recurringPattern: draft.recurringPattern,
            priority: draft.priority,
            tags: draft.tags,
            iconName: draft.iconName
        )
    }
}

// MARK: - 取数请求（显式 entityName，避开程序化模型下 .entity() 的歧义）

extension Todo {
    static func makeFetchRequest() -> NSFetchRequest<Todo> {
        NSFetchRequest<Todo>(entityName: "Todo")
    }

    /// 未完成，按截止时间升序
    static func activeFetchRequest() -> NSFetchRequest<Todo> {
        let r = makeFetchRequest()
        r.predicate = NSPredicate(format: "isCompleted == NO")
        r.sortDescriptors = [NSSortDescriptor(keyPath: \Todo.dueDate, ascending: true)]
        return r
    }

    /// 已完成，按完成时间倒序
    static func completedFetchRequest() -> NSFetchRequest<Todo> {
        let r = makeFetchRequest()
        r.predicate = NSPredicate(format: "isCompleted == YES")
        r.sortDescriptors = [NSSortDescriptor(keyPath: \Todo.completedAt, ascending: false)]
        return r
    }

    /// 全部，按创建时间倒序
    static func allByCreatedDescRequest() -> NSFetchRequest<Todo> {
        let r = makeFetchRequest()
        r.sortDescriptors = [NSSortDescriptor(keyPath: \Todo.createdAt, ascending: false)]
        return r
    }
}

// MARK: - 业务派生属性 / 行为

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
