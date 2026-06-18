//
//  QuickCaptureView.swift
//  喵咚
//
//  ⌥Space 全局快速捕获的迷你输入条 —— 只有一行 TextField，
//  自然语言进去 → NlpParser 解析 → 直接落库，零干扰。
//

import SwiftUI

struct QuickCaptureView: View {
    @State private var text: String = ""
    @State private var parseResult: TodoParseResult?
    @FocusState private var focused: Bool

    let onSubmit: (TodoDraft) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.accent)

                TextField("快速添加待办（例：今晚 8 点写周报 提前 10 分钟提醒）", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($focused)
                    .onSubmit { submit() }
                    .onChange(of: text) { _ in updateParse() }

                if !text.isEmpty {
                    Button {
                        text = ""
                        parseResult = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppPalette.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, parseResult != nil ? 0 : 14)

            // 解析预览（有日期 / 标签 / 优先级时展示）
            if let r = parseResult, hasMeaningfulPreview(r) {
                Divider()
                    .background(AppPalette.separator.opacity(0.5))
                previewRow(r)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
            }

            // 底部提示行 —— 快捷键是用户自定义的，不再硬编码展示
            HStack(spacing: 0) {
                Text("回车保存")
                    .foregroundStyle(AppPalette.accent.opacity(0.9))
                Text("  ·  ")
                    .foregroundStyle(AppPalette.secondary.opacity(0.4))
                Text("ESC 关闭")
                    .foregroundStyle(AppPalette.secondary.opacity(0.75))
                Spacer()
            }
            .font(.system(size: 11))
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
            .padding(.top, 2)
        }
        .frame(width: 560)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppPalette.mainBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.accent.opacity(0.20), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.28), radius: 28, x: 0, y: 12)
        .shadow(color: AppPalette.accent.opacity(0.18), radius: 22, x: 0, y: 0)
        .padding(20)  // 给阴影留绘制空间
        .preferredColorScheme(.light)
        .onAppear {
            focused = true
            updateParse()
        }
        .onExitCommand { onCancel() }
    }

    // MARK: - 解析预览

    private func hasMeaningfulPreview(_ r: TodoParseResult) -> Bool {
        r.dueDate != nil
            || r.notifyOffsetSeconds > 0
            || r.repeatIntervalSeconds != nil
            || r.priority != .medium
            || !r.tags.isEmpty
            || r.isRecurring
    }

    @ViewBuilder
    private func previewRow(_ r: TodoParseResult) -> some View {
        HStack(spacing: 8) {
            if let due = r.dueDate {
                previewChip(icon: "clock", text: formatDate(due, isRecurring: r.isRecurring))
            }
            if r.notifyOffsetSeconds > 0 {
                previewChip(icon: "bell", text: "提前 \(humanDuration(r.notifyOffsetSeconds))")
            }
            if let interval = r.repeatIntervalSeconds, interval > 0 {
                previewChip(icon: "repeat", text: "间隔 \(humanDuration(interval))")
            }
            if r.priority != .medium {
                previewChip(icon: "flag.fill", text: r.priority == .high ? "高优先级" : "低优先级")
            }
            ForEach(r.tags, id: \.self) { tag in
                previewChip(icon: "tag.fill", text: tag.label)
            }
            Spacer()
        }
    }

    private func previewChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 11))
        }
        .foregroundStyle(AppPalette.accent)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(AppPalette.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func formatDate(_ d: Date, isRecurring: Bool) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        let cal = Calendar.current
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

    // MARK: - Action

    private func updateParse() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parseResult = nil
            return
        }
        parseResult = NlpParser.parse(trimmed)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onCancel()
            return
        }
        let r = NlpParser.parse(trimmed)
        let draft = TodoDraft(
            title: r.title.isEmpty ? trimmed : r.title,
            dueDate: r.dueDate,
            notifyOffsetSeconds: r.notifyOffsetSeconds,
            repeatIntervalSeconds: r.repeatIntervalSeconds,
            isRecurring: r.isRecurring,
            recurringPattern: r.recurringPattern,
            priority: r.priority,
            tags: r.tags
        )
        onSubmit(draft)
    }
}
