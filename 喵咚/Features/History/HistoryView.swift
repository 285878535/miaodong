//
//  HistoryView.swift
//  喵咚
//
//  历史任务窗口：显示所有任务（含已完成/未完成），支持多选 / 全选 / 删除选中
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: [SortDescriptor(\Todo.createdAt, order: .reverse)])
    private var todos: [Todo]

    @Environment(\.modelContext) private var context

    @State private var selection: Set<UUID> = []
    @State private var showConfirmDelete: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            toolbar
            content
        }
        .frame(width: 520, height: 480)
        .background(AppPalette.mainBg)
        .preferredColorScheme(.light)
        .alert("确定删除选中的 \(selection.count) 个任务吗？",
               isPresented: $showConfirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteSelected() }
        } message: {
            Text("此操作不可撤销")
        }
    }

    // MARK: - 顶部标题栏

    private var titleBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(AppPalette.accent)
                .font(.system(size: 14, weight: .bold))
            Text("历史任务")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppPalette.primary)
            Spacer()
            Text("共 \(todos.count) 条")
                .font(.system(size: 11))
                .foregroundStyle(AppPalette.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: - 工具栏（全选 / 已选数 / 删除）

    private var toolbar: some View {
        HStack(spacing: 12) {
            selectAllButton

            Spacer()

            if !selection.isEmpty {
                Text("已选 \(selection.count) 条")
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.secondary)
            }

            deleteButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var selectAllButton: some View {
        Button {
            toggleSelectAll()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(allSelected ? AppPalette.accent : Color.clear)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(allSelected ? AppPalette.accent : AppPalette.primary.opacity(0.3), lineWidth: 1.4)
                    if allSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 14, height: 14)
                Text(allSelected ? "取消全选" : "全选")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppPalette.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(todos.isEmpty)
    }

    private var deleteButton: some View {
        Button {
            showConfirmDelete = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
                Text("删除选中")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selection.isEmpty ? Color.white.opacity(0.6) : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selection.isEmpty ? Color(red: 0.92, green: 0.42, blue: 0.42).opacity(0.4)
                                          : Color(red: 0.92, green: 0.42, blue: 0.42))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(selection.isEmpty)
    }

    // MARK: - 内容区

    @ViewBuilder
    private var content: some View {
        if todos.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(todos.enumerated()), id: \.element.id) { idx, todo in
                    HistoryRow(
                        todo: todo,
                        isSelected: selection.contains(todo.id),
                        onToggleSelect: { toggleSelect(todo.id) }
                    )
                    if idx < todos.count - 1 {
                        Divider()
                            .background(AppPalette.separator.opacity(0.5))
                            .padding(.leading, 50)
                    }
                }
            }
        }
        .background(AppPalette.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: AppPalette.primary.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(AppPalette.accent.opacity(0.3))
            Text("暂无历史任务")
                .font(.system(size: 12))
                .foregroundStyle(AppPalette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 30)
    }

    // MARK: - 行为

    private var allSelected: Bool {
        !todos.isEmpty && selection.count == todos.count
    }

    private func toggleSelectAll() {
        if allSelected {
            selection.removeAll()
        } else {
            selection = Set(todos.map { $0.id })
        }
    }

    private func toggleSelect(_ id: UUID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private func deleteSelected() {
        let toDelete = todos.filter { selection.contains($0.id) }
        for t in toDelete {
            let id = t.id
            NotificationManager.shared.cancel(todoId: id)
            AlertWindowController.shared.dismiss(id: id)
            context.delete(t)
        }
        try? context.save()
        ReminderScheduler.shared.reload()
        selection.removeAll()
    }
}

// MARK: - 单行（独立 View 减少父视图重渲染）

private struct HistoryRow: View {
    @Bindable var todo: Todo
    let isSelected: Bool
    let onToggleSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            checkbox
            statusBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(todo.isCompleted ? AppPalette.secondary : AppPalette.primary)
                    .strikethrough(todo.isCompleted, color: AppPalette.secondary.opacity(0.5))
                    .lineLimit(1)
                Text(metaText)
                    .font(.system(size: 10))
                    .foregroundStyle(AppPalette.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isSelected ? AppPalette.accentSoft.opacity(0.55) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onToggleSelect() }
    }

    private var checkbox: some View {
        Button(action: onToggleSelect) {
            ZStack {
                Color.clear.frame(width: 24, height: 24).contentShape(Rectangle())
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? AppPalette.accent : Color.clear)
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? AppPalette.accent : AppPalette.primary.opacity(0.3), lineWidth: 1.4)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 14, height: 14)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if todo.isCompleted {
            badge(text: "已完成",
                  fg: Color(red: 0.24, green: 0.62, blue: 0.34),
                  bg: Color(red: 0.36, green: 0.78, blue: 0.45).opacity(0.18))
        } else {
            badge(text: "待办",
                  fg: AppPalette.accent,
                  bg: AppPalette.accentSoft)
        }
    }

    private func badge(text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(Capsule())
    }

    private var metaText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        if todo.isCompleted, let completedAt = todo.completedAt {
            return "完成于 \(f.string(from: completedAt))"
        }
        if let due = todo.dueDate {
            return "计划 \(f.string(from: due))"
        }
        return "创建于 \(f.string(from: todo.createdAt))"
    }
}
