//
//  ReminderScheduler.swift
//  喵咚
//
//  应用内提醒调度器：管理首次触发 + 间隔重复
//  同时是 NotificationManager（系统通知）的唯一调用方，
//  保证两条提醒链路（应用内 AlertWindow 与系统横幅）始终同步。
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

    /// 根据当前 SwiftData 中的未完成 Todo 重新安排所有定时器，
    /// 并同步重排系统通知请求（每次都是全量重置，幂等）。
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
                // 还没到，安排首次触发 + 系统通知兜底
                schedule(todo: todo, fireAt: fire)
                NotificationManager.shared.schedule(for: todo)
            } else if let interval = todo.repeatIntervalSeconds, interval > 0 {
                // 已过时但有重复间隔，立刻进入重复循环（按下一个 interval 触发）
                scheduleRepeat(todo: todo, interval: TimeInterval(interval))
            }
        }
    }

    /// 单独取消某个 Todo 的所有定时器（删除/完成时调用），同时取消同 id 的系统通知。
    func cancel(todoId: UUID) {
        initialTimers[todoId]?.invalidate()
        initialTimers.removeValue(forKey: todoId)
        repeatTimers[todoId]?.invalidate()
        repeatTimers.removeValue(forKey: todoId)
        NotificationManager.shared.cancel(todoId: todoId)
    }

    func cancelAll() {
        // 收集所有定时器 id，一并撤掉系统通知
        let ids = Set(initialTimers.keys).union(repeatTimers.keys)
        initialTimers.values.forEach { $0.invalidate() }
        initialTimers.removeAll()
        repeatTimers.values.forEach { $0.invalidate() }
        repeatTimers.removeAll()
        for id in ids {
            NotificationManager.shared.cancel(todoId: id)
        }
    }

    /// 通知中心点击横幅时被调用：找到对应 todo 并触发 AlertWindow。
    /// 不重置定时器（横幅本身已经把首次提醒消耗掉了，间隔重复继续由 Timer 驱动）。
    func triggerAlert(for todoId: UUID) {
        guard let container else { return }
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<Todo>(
            predicate: #Predicate<Todo> { $0.id == todoId }
        )
        guard let todo = (try? ctx.fetch(descriptor))?.first, !todo.isCompleted else { return }
        onFire?(todo)
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

        onFire?(todo)

        // 触发后清理首次定时器；如果有间隔重复且尚未启动，启动它
        initialTimers[todoId]?.invalidate()
        initialTimers.removeValue(forKey: todoId)

        if let interval = todo.repeatIntervalSeconds, interval > 0, repeatTimers[todoId] == nil {
            scheduleRepeat(todo: todo, interval: TimeInterval(interval))
        }
    }
}
