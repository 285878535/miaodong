//
//  TodoStore.swift
//  喵咚
//

import Foundation
import SwiftData

@MainActor
final class TodoStore {
    let container: ModelContainer

    var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
    }

    /// 默认 container —— 按用户的 iCloud 同步设置选择 local-only 或 CloudKit private DB。
    /// 启用 iCloud 要求：
    ///   1. App 已配置 CloudKit container (iCloud.com.justinxing.miaodong)
    ///   2. 用户已登录 iCloud 且该 App 在 iCloud Drive 中启用
    ///   3. Todo 模型不能用 @Attribute(.unique) / required relationships
    static func makeDefaultContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Todo.self])

        let useCloudKit = !inMemory
            && (UserDefaults.standard.object(forKey: AppSettingsKeys.iCloudSyncEnabled) as? Bool ?? false)

        let config: ModelConfiguration
        if useCloudKit {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.justinxing.miaodong")
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // CloudKit 容器拿不到（未登录 iCloud / 没开发者权限等）时降级到本地，
            // 用户至少不会因为打开 iCloud 开关导致 App 启动失败。
            if useCloudKit {
                NSLog("[TodoStore] CloudKit container init failed (\(error)), 回退本地 store")
                let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [local])
            }
            throw error
        }
    }

    // MARK: - CRUD

    @discardableResult
    func add(_ todo: Todo) -> Todo {
        context.insert(todo)
        save()
        return todo
    }

    func delete(_ todo: Todo) {
        context.delete(todo)
        save()
    }

    func fetchAll(includeCompleted: Bool = true,
                  sortBy: [SortDescriptor<Todo>] = [SortDescriptor(\Todo.dueDate)]) -> [Todo] {
        let predicate: Predicate<Todo>? = includeCompleted
            ? nil
            : #Predicate<Todo> { !$0.isCompleted }
        var descriptor = FetchDescriptor<Todo>(predicate: predicate, sortBy: sortBy)
        descriptor.includePendingChanges = true
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchActive() -> [Todo] {
        fetchAll(includeCompleted: false)
    }

    func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("TodoStore save failed: \(error)")
        }
    }
}
