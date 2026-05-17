//
//  ReminderScheduler.swift
//  喵咚
//
//  应用内提醒调度器：管理首次触发 + 间隔重复
//

import Foundation
import SwiftData

@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    private var container: ModelContainer?
    private var initialTimers: [UUID: Timer] = [:]
    private var repeatTimers: [UUID: Timer] = [:]

    var onFire: ((Todo) -> Void)?

    private init() {}

    func attach(container: ModelContainer) {
        self.container = container
    }

    /// 根据当前 SwiftData 中的未完成 Todo 重新安排所有定时器。
    func reload() {
        cancelAll()
        guard let container else { return }
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<Todo>(
            predicate: #Predicate<Todo> { !$0.isCompleted }
        )
        let todos = (try? ctx.fetch(descriptor)) ?? []

        let now = Date()
        for todo in todos {
            guard let fire = todo.notifyDate else { continue }

            if fire > now {
                // 还没到，安排首次触发
                schedule(todo: todo, fireAt: fire)
            } else if let interval = todo.repeatIntervalSeconds, interval > 0 {
                // 已过时但有重复间隔，立刻进入重复循环（按下一个 interval 触发）
                scheduleRepeat(todo: todo, interval: TimeInterval(interval))
            }
        }
    }

    /// 单独取消某个 Todo 的所有定时器（删除/完成时调用）
    func cancel(todoId: UUID) {
        initialTimers[todoId]?.invalidate()
        initialTimers.removeValue(forKey: todoId)
        repeatTimers[todoId]?.invalidate()
        repeatTimers.removeValue(forKey: todoId)
    }

    func cancelAll() {
        initialTimers.values.forEach { $0.invalidate() }
        initialTimers.removeAll()
        repeatTimers.values.forEach { $0.invalidate() }
        repeatTimers.removeAll()
    }

    // MARK: - 内部

    private func schedule(todo: Todo, fireAt date: Date) {
        let id = todo.id
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fire(todoId: id)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        initialTimers[id] = timer
    }

    private func scheduleRepeat(todo: Todo, interval: TimeInterval) {
        let id = todo.id
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fire(todoId: id)
            }
        }
        repeatTimers[id] = timer
    }

    private func fire(todoId: UUID) {
        guard let container else { return }
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<Todo>(
            predicate: #Predicate<Todo> { $0.id == todoId }
        )
        guard let todo = (try? ctx.fetch(descriptor))?.first, !todo.isCompleted else {
            cancel(todoId: todoId)
            return
        }

        // 若由 snoozeUntil 触发，触发后清空它（避免重复 fire）
        if let snooze = todo.snoozeUntil, snooze <= Date() {
            todo.clearSnooze()
            try? ctx.save()
        }

        onFire?(todo)

        // 触发后清理首次定时器；如果有间隔重复且尚未启动，启动它
        initialTimers[todoId]?.invalidate()
        initialTimers.removeValue(forKey: todoId)

        if let interval = todo.repeatIntervalSeconds, interval > 0, repeatTimers[todoId] == nil {
            scheduleRepeat(todo: todo, interval: TimeInterval(interval))
        }
    }
}
