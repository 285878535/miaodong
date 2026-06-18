//
//  TodoStore.swift
//  喵咚
//

import Foundation
import CoreData

@MainActor
final class TodoStore {
    let container: NSPersistentContainer

    var context: NSManagedObjectContext { container.viewContext }

    init(container: NSPersistentContainer) {
        self.container = container
    }

    // MARK: - 程序化数据模型
    //
    // 不使用 .xcdatamodeld 资源文件，直接用代码构建 NSManagedObjectModel，
    // 这样无需改动 Xcode 工程的资源编译设置，且属性的 optional / default 由代码精确控制。
    // 为兼容 CloudKit：所有属性 optional 或带默认值、无唯一约束。

    static func makeManagedObjectModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "Todo"
        entity.managedObjectClassName = NSStringFromClass(Todo.self)  // @objc(Todo) → "Todo"

        func attr(_ name: String,
                  _ type: NSAttributeType,
                  optional: Bool = true,
                  defaultValue: Any? = nil) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            if let defaultValue { a.defaultValue = defaultValue }
            return a
        }

        // 时间默认值用固定常量（不可用"当前时间"，模型构建是一次性的），仅为防止 CloudKit 同步缺字段时崩溃。
        let epoch = Date(timeIntervalSinceReferenceDate: 0)

        entity.properties = [
            attr("id", .UUIDAttributeType),
            attr("title", .stringAttributeType, defaultValue: ""),
            attr("notes", .stringAttributeType),
            attr("dueDate", .dateAttributeType),
            attr("notifyOffsetSeconds", .integer64AttributeType, defaultValue: 0),
            attr("repeatIntervalRaw", .integer64AttributeType),
            attr("isRecurring", .booleanAttributeType, defaultValue: false),
            attr("recurringPattern", .stringAttributeType),
            attr("isCompleted", .booleanAttributeType, defaultValue: false),
            attr("completedAt", .dateAttributeType),
            attr("snoozeUntil", .dateAttributeType),
            attr("priorityRaw", .stringAttributeType, defaultValue: Priority.medium.rawValue),
            attr("tagsStorage", .stringAttributeType, defaultValue: ""),
            attr("iconName", .stringAttributeType),
            attr("createdAt", .dateAttributeType, defaultValue: epoch),
            attr("updatedAt", .dateAttributeType, defaultValue: epoch),
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }

    /// 默认 container —— 按用户的 iCloud 同步设置选择 local-only 或 CloudKit private DB。
    /// 启用 iCloud 要求：
    ///   1. App 已配置 CloudKit container (iCloud.com.justinxing.miaodong)
    ///   2. 用户已登录 iCloud 且该 App 在 iCloud Drive 中启用
    ///   3. Todo 模型不能用唯一约束 / required relationships
    static func makeDefaultContainer(inMemory: Bool = false) throws -> NSPersistentContainer {
        let model = makeManagedObjectModel()

        let useCloudKit = !inMemory
            && (UserDefaults.standard.object(forKey: AppSettingsKeys.iCloudSyncEnabled) as? Bool ?? false)

        if useCloudKit {
            do {
                return try makeContainer(model: model, inMemory: false, cloudKit: true)
            } catch {
                // CloudKit 容器拿不到（未登录 iCloud / 没开发者权限等）时降级到本地，
                // 用户至少不会因为打开 iCloud 开关导致 App 启动失败。
                NSLog("[TodoStore] CloudKit container init failed (\(error)), 回退本地 store")
                return try makeContainer(model: model, inMemory: false, cloudKit: false)
            }
        }
        return try makeContainer(model: model, inMemory: inMemory, cloudKit: false)
    }

    private static func makeContainer(model: NSManagedObjectModel,
                                      inMemory: Bool,
                                      cloudKit: Bool) throws -> NSPersistentContainer {
        let name = "Miaodong"
        let container: NSPersistentContainer = cloudKit
            ? NSPersistentCloudKitContainer(name: name, managedObjectModel: model)
            : NSPersistentContainer(name: name, managedObjectModel: model)

        guard let description = container.persistentStoreDescriptions.first else {
            throw NSError(domain: "TodoStore", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "缺少 persistentStoreDescription"])
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // 显式开启自动轻量迁移：将来数据模型若有小改动（加/删字段），
        // 旧数据库能平滑升级而不丢数据（默认即为 true，这里写明以防被无意改动）。
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // 历史追踪始终开启：一旦某个 store 文件启用过 history tracking，再次以"未启用"的
        // 配置打开它就会加载失败。用户开/关 iCloud 同步是在同一个 store 文件上来回切，
        // 所以这里无论本地还是云端都开，避免关掉同步后重启 App 直接崩在 loadPersistentStores。
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if cloudKit {
            description.cloudKitContainerOptions =
                NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.justinxing.miaodong")
        } else {
            description.cloudKitContainerOptions = nil
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    // MARK: - CRUD

    func delete(_ todo: Todo) {
        context.delete(todo)
        save()
    }

    func fetchAll(includeCompleted: Bool = true,
                  sortBy: [NSSortDescriptor] = [NSSortDescriptor(keyPath: \Todo.dueDate, ascending: true)]) -> [Todo] {
        let request = Todo.makeFetchRequest()
        if !includeCompleted {
            request.predicate = NSPredicate(format: "isCompleted == NO")
        }
        request.sortDescriptors = sortBy
        return (try? context.fetch(request)) ?? []
    }

    func fetchActive() -> [Todo] {
        fetchAll(includeCompleted: false)
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            assertionFailure("TodoStore save failed: \(error)")
        }
    }
}
