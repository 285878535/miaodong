//
//  CompletedTodoView.swift
//  喵咚
//
//  已完成任务的「只读详情」面板：查看完整内容（不可编辑），
//  可一键「设为新任务」复制成一条相同内容的新待办。
//

import SwiftUI

struct CompletedTodoView: View {
    @ObservedObject var todo: Todo
    let onDuplicate: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(todo.title.isEmpty ? "（无标题）" : todo.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !metaItems.isEmpty {
                        Divider().background(AppPalette.separator.opacity(0.5))
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(metaItems, id: \.0) { item in
                                metaRow(icon: item.1, text: item.0)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppPalette.separator, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(20)
        .frame(width: 400, height: 420)
        .background(AppPalette.mainBg)
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppPalette.accent)
            Text("任务详情")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppPalette.primary)
            Text("已完成")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.24, green: 0.62, blue: 0.34))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color(red: 0.36, green: 0.78, blue: 0.45).opacity(0.18))
                .clipShape(Capsule())
            Spacer()
        }
    }

    // MARK: - 元信息

    /// (文本, SF Symbol)
    private var metaItems: [(String, String)] {
        var items: [(String, String)] = []
        if let done = todo.completedAt {
            items.append(("完成于 \(formatDate(done))", "checkmark.circle"))
        }
        if let due = todo.dueDate {
            items.append(("计划 \(formatDate(due))", "clock"))
        }
        if todo.notifyOffsetSeconds > 0 {
            items.append(("提前 \(humanDuration(todo.notifyOffsetSeconds)) 提醒", "bell"))
        }
        if let interval = todo.repeatIntervalSeconds, interval > 0 {
            items.append(("每 \(humanDuration(interval)) 重复", "timer"))
        }
        let tags = todo.tags
        if !tags.isEmpty {
            items.append((tags.map { $0.label }.joined(separator: "、"), "tag"))
        }
        items.append(("创建于 \(formatDate(todo.createdAt))", "calendar"))
        return items
    }

    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.accent.opacity(0.85))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(AppPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 底部按钮

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button(action: onClose) {
                Text("关闭")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.primary)
                    .frame(minWidth: 56)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(AppPalette.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(AppPalette.separator, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Button(action: onDuplicate) {
                HStack(spacing: 5) {
                    Image(systemName: "plus.square.on.square")
                        .font(.system(size: 12, weight: .semibold))
                    Text("设为新任务")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppPalette.accent)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .help("用相同内容创建一条新的未完成待办")
        }
    }

    // MARK: - 格式化

    private func formatDate(_ d: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        if cal.isDateInToday(d) {
            f.dateFormat = "今天 HH:mm"
        } else if cal.isDateInTomorrow(d) {
            f.dateFormat = "明天 HH:mm"
        } else {
            f.dateFormat = "M月d日 HH:mm"
        }
        return f.string(from: d)
    }

    private func humanDuration(_ seconds: Int) -> String {
        if seconds >= 86_400, seconds % 86_400 == 0 { return "\(seconds / 86_400) 天" }
        if seconds >= 3600, seconds % 3600 == 0 { return "\(seconds / 3600) 小时" }
        if seconds >= 60, seconds % 60 == 0 { return "\(seconds / 60) 分钟" }
        return "\(seconds) 秒"
    }
}
