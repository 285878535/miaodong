//
//  AddTodoView.swift
//  喵咚
//
//  独立"添加待办"面板（设计图 #3）：自然语言输入 + 字段化回显
//

import SwiftUI

struct AddTodoView: View {
    @State private var text: String = ""
    @State private var parseResult: TodoParseResult?
    @FocusState private var textFocused: Bool
    /// 用户在面板里临时关闭"间隔提醒"开关 —— 关掉后提交不写入 repeatIntervalSeconds。
    /// 文本里再次出现间隔关键词 / 用户改文本时会被重新置 true。
    @State private var intervalEnabledOverride: Bool = true

    let isEditing: Bool
    let onSubmit: (Todo) -> Void
    let onCancel: () -> Void

    init(initialText: String = "",
         isEditing: Bool = false,
         onSubmit: @escaping (Todo) -> Void,
         onCancel: @escaping () -> Void) {
        self._text = State(initialValue: initialText)
        self.isEditing = isEditing
        self.onSubmit = onSubmit
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 14) {
                inputArea
                if let r = parseResult, hasMeaningfulFields(r) {
                    fieldsArea(r)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            Spacer(minLength: 0)

            // 分割线 + 按钮行
            Rectangle()
                .fill(AppPalette.separator.opacity(0.6))
                .frame(height: 0.5)
            buttonRow
        }
        .frame(width: 400)
        .background(AppPalette.mainBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 8)
        .preferredColorScheme(.light)
        .onAppear {
            textFocused = true
            updateParseResult()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil")
                .foregroundStyle(AppPalette.accent)
                .font(.system(size: 14, weight: .bold))
            Text(isEditing ? "编辑待办" : "添加待办")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppPalette.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - 输入框

    private var inputArea: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($textFocused)
                .font(.system(size: 14))
                .foregroundColor(AppPalette.primary)
                .tint(AppPalette.accent)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(minHeight: 96, maxHeight: 120)
                .background(AppPalette.white)

            if text.isEmpty {
                // 与 TextEditor 内部 NSTextView 文本起点严格对齐
                Text("明天下午 3 点开会，提前 20 分钟提醒，\n如果我没开始，间隔 10 分钟再提醒我一次")
                    .font(.system(size: 14))
                    .foregroundStyle(AppPalette.primary.opacity(0.3))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.accent.opacity(0.55))
                        .padding(10)
                }
            }
        }
        .background(AppPalette.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppPalette.accent, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: text) { _, _ in
            updateParseResult()
        }
    }

    // MARK: - 字段化回显

    @ViewBuilder
    private func fieldsArea(_ r: TodoParseResult) -> some View {
        VStack(spacing: 0) {
            if let due = r.dueDate {
                fieldRow(label: "时间",
                         value: formatDate(due),
                         trailingIcon: "calendar")
            }
            if r.notifyOffsetSeconds > 0 {
                fieldDivider()
                fieldRow(label: "提前提醒",
                         value: humanDuration(r.notifyOffsetSeconds) + "前",
                         trailingIcon: "chevron.down")
            }
            if r.repeatIntervalSeconds != nil {
                fieldDivider()
                intervalSection(r)
            }
            if let due = r.dueDate {
                let fireDate = due.addingTimeInterval(-Double(r.notifyOffsetSeconds))
                if fireDate > Date() {
                    fieldDivider()
                    nextReminderRow(fireDate)
                }
            }
        }
        .background(AppPalette.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: AppPalette.primary.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func nextReminderRow(_ fireDate: Date) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.fill")
                .font(.system(size: 11))
                .foregroundStyle(AppPalette.accent.opacity(0.8))
            Text("下次提醒")
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.primary)
            Spacer()
            Text(formatDate(fireDate))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppPalette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func fieldDivider() -> some View {
        Rectangle()
            .fill(AppPalette.separator.opacity(0.5))
            .frame(height: 0.5)
            .padding(.horizontal, 14)
    }

    private func fieldRow(label: String, value: String, trailingIcon: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.primary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppPalette.primary)
            Image(systemName: trailingIcon)
                .foregroundStyle(AppPalette.secondary.opacity(0.75))
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func intervalSection(_ r: TodoParseResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("间隔提醒")
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.primary)
                Spacer()
                Toggle("", isOn: $intervalEnabledOverride)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(AppPalette.accent)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if let interval = r.repeatIntervalSeconds, intervalEnabledOverride {
                HStack {
                    Text("间隔 \(humanDuration(interval))，到点后持续提醒")
                        .font(.system(size: 11))
                        .foregroundStyle(AppPalette.secondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 10)
            } else if !intervalEnabledOverride {
                HStack {
                    Text("已关闭，提交后不再循环提醒")
                        .font(.system(size: 11))
                        .foregroundStyle(AppPalette.secondary.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 10)
            } else {
                Spacer().frame(height: 10)
            }
        }
    }


    // MARK: - 底部按钮

    private var buttonRow: some View {
        HStack(spacing: 10) {
            Spacer()
            Button(action: onCancel) {
                Text("取消")
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

            Button(action: submit) {
                Text(isEditing ? "保存" : "添加")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 56)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(canSubmit ? AppPalette.accent : AppPalette.accent.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canSubmit)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 行为

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateParseResult() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldHadInterval = parseResult?.repeatIntervalSeconds != nil
        let new = trimmed.isEmpty ? nil : NlpParser.parse(trimmed)
        // 用户每次重新输入出现间隔关键词时，把 override 重置为 ON，
        // 避免之前关掉过又添了新文本却怎么改都打不开的"卡死"体验。
        if let r = new, r.repeatIntervalSeconds != nil, !oldHadInterval {
            intervalEnabledOverride = true
        }
        parseResult = new
    }

    private func hasMeaningfulFields(_ r: TodoParseResult) -> Bool {
        r.dueDate != nil || r.notifyOffsetSeconds > 0 || r.repeatIntervalSeconds != nil
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let r = NlpParser.parse(trimmed)

        let defaults = UserDefaults.standard
        let defaultNotifyMin = defaults.integer(forKey: AppSettingsKeys.defaultNotifyOffsetMinutes)
        let defaultIntervalMin = defaults.integer(forKey: AppSettingsKeys.defaultRepeatIntervalMinutes)
        let notifyOffsetSeconds = r.notifyOffsetSeconds > 0 ? r.notifyOffsetSeconds : defaultNotifyMin * 60
        // 用户在面板里关掉间隔开关时强制丢弃间隔信息（包含解析结果和设置项默认值）
        let parsedInterval: Int? = r.repeatIntervalSeconds ?? (defaultIntervalMin > 0 ? defaultIntervalMin * 60 : nil)
        let repeatIntervalSeconds: Int? = intervalEnabledOverride ? parsedInterval : nil

        let todo = Todo(
            title: r.title,
            dueDate: r.dueDate,
            notifyOffsetSeconds: notifyOffsetSeconds,
            repeatIntervalSeconds: repeatIntervalSeconds,
            isRecurring: r.isRecurring,
            recurringPattern: r.recurringPattern,
            priority: r.priority,
            tags: r.tags
        )
        onSubmit(todo)
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
        if seconds >= 3600, seconds % 3600 == 0 { return "\(seconds / 3600) 小时" }
        if seconds >= 60, seconds % 60 == 0 { return "\(seconds / 60) 分钟" }
        return "\(seconds) 秒"
    }
}

