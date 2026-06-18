//
//  CatActivityState.swift
//  喵咚
//
//  三处图标（状态栏 / 灵动岛 / 悬浮）共享的「是否有未完成任务」状态。
//  判断标准集中在这里：只要存在任何未完成任务就视为活跃（小猫挥手），否则睡觉。
//  监听 Core Data 上下文变化自动刷新，三处订阅同一来源，形象始终一致。
//

import Foundation
import CoreData
import Combine

@MainActor
final class CatActivityState: ObservableObject {
    static let shared = CatActivityState()

    /// 是否存在未完成任务（isCompleted == NO）
    @Published private(set) var hasActiveTodos: Bool = false
    /// 未完成任务数量
    @Published private(set) var activeCount: Int = 0

    private var context: NSManagedObjectContext?
    private var observer: NSObjectProtocol?

    private init() {}

    /// AppDelegate 启动后调用一次，绑定主上下文并开始监听
    func attach(context: NSManagedObjectContext) {
        self.context = context
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard let context else { hasActiveTodos = false; return }
        let request = Todo.makeFetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == NO")
        let count = (try? context.count(for: request)) ?? 0
        if count != activeCount { activeCount = count }
        let next = count > 0
        if next != hasActiveTodos { hasActiveTodos = next }
    }
}
