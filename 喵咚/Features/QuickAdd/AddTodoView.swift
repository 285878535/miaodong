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

    // 可手动调整的时间（初始来自自然语言解析，用户可用时间选择器覆盖）
    @State private var dueDate: Date?
    @State private var notifyDate: Date?
    /// 上一次「文本解析」得到的截止时间——只有当文本里的时间变化时才重新覆盖手动选择，
    /// 这样用户改标题文字不会冲掉已经手选的时间。
    @State private var lastParsedDue: Date?
    /// 用户在面板里临时关闭"间隔提醒"开关 —— 关掉后提交不写入 repeatIntervalSeconds。
    /// 文本里再次出现间隔关键词 / 用户改文本时会被重新置 true。
    @State private var intervalEnabledOverride: Bool = true

    let isEditing: Bool
    let onSubmit: (TodoDraft) -> Void
    let onCancel: () -> Void

    init(initialText: String = "",
         isEditing: Bool = false,
         onSubmit: @escaping (TodoDraft) -> Void,
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
                detailsArea
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
        .onChange(of: text) { _ in
            updateParseResult()
        }
    }

    // MARK: - 字段化回显

    @ViewBuilder
    private var detailsArea: some View {
        VStack(spacing: 0) {
            if dueDate != nil {
                timeRow
                fieldDivider()
                notifyRow
            } else {
                addTimeRow
            }
            if let r = parseResult, r.repeatIntervalSeconds != nil {
                fieldDivider()
                intervalSection(r)
            }
        }
        .background(AppPalette.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: AppPalette.primary.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    /// 时间（截止时间）—— 可用时间选择器手动调整
    private var timeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppPalette.primary.opacity(0.7))
            Text("时间")
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.primary)
            Spacer()
            DatePicker("", selection: dueBinding, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AppPalette.accent)
            Button { clearTime() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
            .help("清除时间")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 下次提醒 —— 可手动选具体提醒时间；其与截止时间之差即“提前量”
    private var notifyRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.accent.opacity(0.8))
                Text("下次提醒")
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.primary)
                Spacer()
                DatePicker("", selection: notifyBinding, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(AppPalette.accent)
            }
            if let hint = offsetHint {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.secondary)
                    .padding(.leading, 19)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 未设置时间时：一键添加一个默认时间，随后即可用选择器调整
    private var addTimeRow: some View {
        Button { addDefaultTime() } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.accent)
                Text("添加时间")
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.accent)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 时间绑定 / 辅助

    private var dueBinding: Binding<Date> {
        Binding(
            get: { dueDate ?? Date() },
            set: { newDue in
                // 调整截止时间时，保持原有提前量（下次提醒随之平移）
                let old = dueDate ?? newDue
                let delta = newDue.timeIntervalSince(old)
                dueDate = newDue
                if let n = notifyDate { notifyDate = n.addingTimeInterval(delta) }
            }
        )
    }

    private var notifyBinding: Binding<Date> {
        Binding(
            get: { notifyDate ?? dueDate ?? Date() },
            set: { notifyDate = $0 }
        )
    }

    /// “提前 X 提醒 / 准时提醒”的副标题
    private var offsetHint: String? {
        guard let due = dueDate, let n = notifyDate else { return nil }
        let off = Int(due.timeIntervalSince(n).rounded())
        if off <= 0 { return "准时提醒" }
        return "提前 \(humanDuration(off)) 提醒"
    }

    private func clearTime() {
        dueDate = nil
        notifyDate = nil
        // 钉住当前解析结果，避免随后的文本解析又把时间塞回来
        lastParsedDue = parseResult?.dueDate
    }

    private func addDefaultTime() {
        let cal = Calendar.current
        let now = Date()
        // 默认「下一个整点」：显式用当前年/月/日/时构造，绝不跨年。
        // （不用 Calendar.date(bySetting:)，它行为不可靠，曾导致默认跳到下一年。）
        var comps = cal.dateComponents([.year, .month, .day, .hour], from: now)
        comps.minute = 0
        comps.second = 0
        let topOfHour = cal.date(from: comps) ?? now
        let base = cal.date(byAdding: .hour, value: 1, to: topOfHour) ?? now.addingTimeInterval(3600)
        dueDate = base
        let off = defaultNotifyOffsetSeconds()
        notifyDate = base.addingTimeInterval(-Double(off))
        lastParsedDue = parseResult?.dueDate
    }

    private func defaultNotifyOffsetSeconds() -> Int {
        UserDefaults.standard.integer(forKey: AppSettingsKeys.defaultNotifyOffsetMinutes) * 60
    }

    private func fieldDivider() -> some View {
        Rectangle()
            .fill(AppPalette.separator.opacity(0.5))
            .frame(height: 0.5)
            .padding(.horizontal, 14)
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
                    .toggleStyle(AccentSwitchToggleStyle())
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

        // 仅当「文本里的时间」发生变化时，才用解析结果覆盖手动选择的时间，
        // 这样用户单纯改标题文字不会冲掉已手选的时间。
        let parsedDue = new?.dueDate
        if parsedDue != lastParsedDue {
            lastParsedDue = parsedDue
            if let due = parsedDue, let r = new {
                dueDate = due
                let off = r.notifyOffsetSeconds > 0 ? r.notifyOffsetSeconds : defaultNotifyOffsetSeconds()
                notifyDate = due.addingTimeInterval(-Double(off))
            } else {
                dueDate = nil
                notifyDate = nil
            }
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let r = NlpParser.parse(trimmed)

        let defaults = UserDefaults.standard
        let defaultNotifyMin = defaults.integer(forKey: AppSettingsKeys.defaultNotifyOffsetMinutes)
        let defaultIntervalMin = defaults.integer(forKey: AppSettingsKeys.defaultRepeatIntervalMinutes)

        // 以用户在面板里（可能手选过）的时间为准；提前量 = 截止时间 − 下次提醒时间
        let finalDue = dueDate
        let finalNotifyOffset: Int
        if let due = finalDue, let n = notifyDate {
            finalNotifyOffset = max(0, Int(due.timeIntervalSince(n).rounded()))
        } else {
            finalNotifyOffset = r.notifyOffsetSeconds > 0 ? r.notifyOffsetSeconds : defaultNotifyMin * 60
        }

        // 用户在面板里关掉间隔开关时强制丢弃间隔信息（包含解析结果和设置项默认值）
        let parsedInterval: Int? = r.repeatIntervalSeconds ?? (defaultIntervalMin > 0 ? defaultIntervalMin * 60 : nil)
        let repeatIntervalSeconds: Int? = intervalEnabledOverride ? parsedInterval : nil

        let draft = TodoDraft(
            title: r.title,
            dueDate: finalDue,
            notifyOffsetSeconds: finalNotifyOffset,
            repeatIntervalSeconds: repeatIntervalSeconds,
            isRecurring: r.isRecurring,
            recurringPattern: r.recurringPattern,
            priority: r.priority,
            tags: r.tags
        )
        onSubmit(draft)
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

