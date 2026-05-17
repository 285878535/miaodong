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

    static func makeDefaultContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Todo.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
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
