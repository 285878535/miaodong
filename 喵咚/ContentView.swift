//
//  ContentView.swift
//  喵咚
//
//  桌宠待办主面板 —— "状态栏里住着一只安静陪伴你的像素猫"
//
//   Header   ── 多层夜空：渐变 + 云雾 + 噪点 + 多大小呼吸星 + 中心紫色辉光
//   猫窝     ── 半圆窝垫 + 多层蓝紫 halo + 小猫坐进窝里（下半身被窝沿遮住）
//   Body     ── 头部 → 主体柔和过渡 + 陪伴 stats + 半透明浮层卡片
//   生命感   ── 30s 无操作 → 睡觉 + Zzz；完成任务 → 跳跃 + 欢呼；hover header → 唤醒
//

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Query(
        filter: #Predicate<Todo> { !$0.isCompleted },
        sort: [SortDescriptor(\Todo.dueDate, order: .forward)]
    )
    private var todos: [Todo]

    @Query(
        filter: #Predicate<Todo> { $0.isCompleted },
        sort: [SortDescriptor(\Todo.completedAt, order: .reverse)]
    )
    private var completedTodos: [Todo]

    @Environment(\.modelContext) private var context

    @State private var showCompleted: Bool = false
    @State private var hoveredHistoryButton: Bool = false
    @State private var hoveredSettingsButton: Bool = false
    @State private var hoveredAllDone: Bool = false
    @State private var hoveredHeader: Bool = false
    @State private var nowTick: Date = .init()

    /// 完成事件触发器：header 小猫跳起来
    @State private var catBounce: CGFloat = 0
    /// 短暂切换 cheer 心情（完成时的欢呼）
    @State private var cheerUntil: Date? = nil
    /// 最近一次用户互动时间（hover / click），用来判定 idle
    @State private var lastInteraction: Date = .init()

    /// 多久没动 = 进入睡觉态
    private let idleThreshold: TimeInterval = 30

    /// 设计常量
    private let headerHeight: CGFloat = 128
    private let topCornerRadius: CGFloat = 0
    private let bottomCornerRadius: CGFloat = 20

    var body: some View {
        mainView
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { tick in
                nowTick = tick
            }
    }

    private var mainView: some View {
        let bodyTop = headerHeight - 18

        return ZStack(alignment: .top) {
            body_
                .frame(width: 360, height: 560 - bodyTop)
                .offset(y: bodyTop)
            header
        }
        .frame(width: 360, height: 560)
        .clipShape(
            .rect(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: bottomCornerRadius,
                bottomTrailingRadius: bottomCornerRadius,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            )
        )
        // popup 外缘多层阴影 + 紫色光晕 —— 让弹窗"漂浮在屏幕里"
        .shadow(color: .black.opacity(0.32), radius: 16, x: 0, y: 8)
        .shadow(color: .black.opacity(0.18), radius: 3,  x: 0, y: 1)
        .shadow(color: AppPalette.headerCenterGlow.opacity(0.36), radius: 34, x: 0, y: 1)
        .preferredColorScheme(.light)
    }

    // MARK: - Header（夜空多层）

    private var header: some View {
        ZStack(alignment: .top) {
            headerBackground
            CloudLayer()
            HeaderStarsAndNoise()
            screenAttachmentBand

            // 中央：小猫窝 + 小猫
            VStack(spacing: 0) {
                catInBowl
                    .padding(.top, 16)
                Spacer(minLength: 0)
            }

            // 左右两栏内容
            HStack(alignment: .top, spacing: 8) {
                greetingBlock
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Spacer().frame(height: 2)
                    HStack(spacing: 6) {
                        historyButton
                        settingsButton
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 38)
        }
        .frame(height: headerHeight)
        .background(.ultraThinMaterial.opacity(0.38))
        .mask(headerFusionMask)
        .overlay(alignment: .bottom) {
            HeaderToBodyFade(height: 42, color: AppPalette.headerToBodyFade)
                .offset(y: 22)
                .blur(radius: 1.5)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredHeader = hovering
            if hovering { recordInteraction() }
        }
    }

    // MARK: - Header 背景（渐变 + 中心辉光 + 顶部柔白）

    private var headerBackground: some View {
        ZStack {
            AppPalette.headerGradient
                .opacity(0.92)

            RadialGradient(
                colors: [
                    AppPalette.headerCenterGlow.opacity(0.70),
                    AppPalette.headerCenterGlow.opacity(0.0)
                ],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 8,
                endRadius: 150
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    private var screenAttachmentBand: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black, location: 0.0),
                .init(color: Color.black, location: 0.38),
                .init(color: Color(red: 0.018, green: 0.014, blue: 0.028), location: 0.52),
                .init(color: AppPalette.headerGradient1.opacity(0.96), location: 0.72),
                .init(color: AppPalette.headerGradient2.opacity(0.48), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private var headerFusionMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0.0),
                .init(color: .black, location: 0.20),
                .init(color: .black, location: 0.74),
                .init(color: .black.opacity(0.72), location: 0.88),
                .init(color: .clear, location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - 小猫窝 + 小猫（猫真正陷进窝里）

    private var catInBowl: some View {
        ZStack(alignment: .bottom) {
            // 多层 halo（背景虚化，营造"猫窝里有柔光"的氛围）
            ZStack {
                Ellipse()
                    .fill(AppPalette.bowlHalo.opacity(0.70))
                    .frame(width: 196, height: 94)
                    .blur(radius: 22)
                Ellipse()
                    .fill(AppPalette.cloudPurple.opacity(0.46))
                    .frame(width: 142, height: 64)
                    .blur(radius: 16)
                Ellipse()
                    .fill(AppPalette.cloudPink.opacity(0.24))
                    .frame(width: 102, height: 42)
                    .blur(radius: 12)
            }
            .offset(y: 20)

            Ellipse()
                .fill(Color.black.opacity(0.26))
                .frame(width: 92, height: 18)
                .blur(radius: 8)
                .offset(y: 30)

            // 猫窝主体（更大、更深）
            CatBowlView(width: 138, height: 45)
                .offset(y: 20)

            // 小猫本体：pixel=3，下方近 1/2 被 mask 遮掉 —— 真正"坐进窝里"
            PixelCatView(pixel: 3, mood: catMoodResolved, glow: true)
                .mask(catMask)
                .shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 5)
                .offset(y: catBounce + 16)
                .animation(.spring(response: 0.32, dampingFraction: 0.55), value: catBounce)
                .overlay(alignment: .top) {
                    if catMoodResolved == .sleep && (isIdle || (todos.isEmpty && !completedTodos.isEmpty)) {
                        ZzzFloater()
                            .offset(x: 22, y: -24)
                    }
                }
        }
        .frame(width: 206, height: 82)
    }

    /// 猫剪裁 mask —— 让底部约 1/3 像素隐入窝沿，猫真正"陷"进去
    private var catMask: some View {
        // 像素猫尺寸：18 cols * 3px = 54w, 16 rows * 3px = 48h
        // 顶部 32pt 可见，底部 16pt 被 mask 遮（占猫 1/3）
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black)
                .frame(height: 32)
            Rectangle()
                .fill(Color.clear)
                .frame(height: 16)
        }
        .frame(width: 54, height: 48)
    }

    // MARK: - 问候

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.accent.opacity(0.9))
                Text(greeting)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppPalette.headerTitle)
                Text("👋")
                    .font(.system(size: 12))
            }
            Text(subGreeting)
                .font(.system(size: 11))
                .foregroundStyle(AppPalette.headerSecondary)
        }
    }

    private var historyButton: some View {
        bubbleButton(
            systemName: "clock.arrow.circlepath",
            iconSize: 12,
            hovered: hoveredHistoryButton,
            onHover: { hoveredHistoryButton = $0; if $0 { recordInteraction() } },
            help: "历史任务"
        ) {
            HistoryWindowController.shared.show(modelContainer: context.container)
        }
    }

    private var settingsButton: some View {
        bubbleButton(
            systemName: "gearshape.fill",
            iconSize: 13,
            hovered: hoveredSettingsButton,
            onHover: { hoveredSettingsButton = $0; if $0 { recordInteraction() } },
            help: "设置"
        ) {
            SettingsWindowController.shared.show()
        }
    }

    private func bubbleButton(
        systemName: String,
        iconSize: CGFloat,
        hovered: Bool,
        onHover: @escaping (Bool) -> Void,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(AppPalette.headerTitle.opacity(0.95))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(hovered ? AppPalette.headerIconBubbleHover : AppPalette.headerIconBubble)
                        .overlay(
                            Circle()
                                .stroke(
                                    hovered ? AppPalette.headerIconStrokeHover : AppPalette.headerIconStroke,
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: .black.opacity(hovered ? 0.30 : 0.18), radius: 3, x: 0, y: 1)
                )
                .scaleEffect(hovered ? 1.06 : 1.0)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .animation(.easeOut(duration: 0.15), value: hovered)
        .help(help)
    }

    private var greeting: String {
        _ = nowTick
        return AppPalette.timeGreeting()
    }

    private var subGreeting: String {
        if todos.isEmpty {
            return completedTodos.isEmpty ? "今天还没有待办喵～" : "今天也是元气满满的一天呢！"
        }
        return "今天也是元气满满的一天呢！"
    }

    // MARK: - Idle 判定 + 唤醒 + 心情

    private var isIdle: Bool {
        _ = nowTick
        return Date().timeIntervalSince(lastInteraction) > idleThreshold
    }

    private func recordInteraction() {
        lastInteraction = Date()
    }

    /// 心情优先级：欢呼 > 长时无操作睡觉 > 全部完成睡觉 > 进行中摇尾 > 空闲发呆
    private var catMoodResolved: CatMood {
        if let until = cheerUntil, until > Date() { return .cheer }
        if isIdle { return .sleep }
        if todos.isEmpty && !completedTodos.isEmpty { return .sleep }
        if todos.isEmpty { return .idle }
        return .wag
    }

    // MARK: - 主体（奶油色）

    private var body_: some View {
        ZStack(alignment: .top) {
            AppPalette.mainBg
            LinearGradient(
                colors: [
                    AppPalette.headerToBodyFade.opacity(0.18),
                    AppPalette.mainBg.opacity(0.92),
                    AppPalette.mainBg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 96)
            VStack(spacing: 0) {
                companionZone
                if todos.isEmpty && completedTodos.isEmpty {
                    emptyState
                } else {
                    listSection
                }
            }
            .padding(.bottom, 76)
            addTrigger
                .frame(maxHeight: .infinity, alignment: .bottom)
            // 头部 → 主体的柔和过渡（紫色阴影渐隐到透明）
            HeaderToBodyFade(height: 72)
                .offset(y: -36)
                .blur(radius: 2)
        }
    }

    // MARK: - 陪伴 stats

    private var companionZone: some View {
        CompanionZone(
            openCount: todos.count,
            doneCount: completedTodos.filter { isToday($0.completedAt) }.count,
            companionDays: CompanionDays.days()
        )
        .padding(.top, 14)
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            PixelCatView(pixel: 4, mood: .sleep, glow: false)
                .opacity(0.75)
            Text("还没有待办喵～")
                .font(.system(size: 12))
                .foregroundStyle(AppPalette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 列表 + 区段头 + 卡片

    private var listSection: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !todos.isEmpty {
                    sectionHeader
                    LazyVStack(spacing: 10) {
                        ForEach(todos) { todo in
                            todoCard(for: todo)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                } else if !completedTodos.isEmpty {
                    allDoneCheer
                }

                if !completedTodos.isEmpty {
                    completedHeader
                    if showCompleted {
                        LazyVStack(spacing: 8) {
                            ForEach(completedTodos) { todo in
                                todoCard(for: todo)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentShape(Rectangle())
        .onHover { if $0 { recordInteraction() } }
    }

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Text("今日待办")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppPalette.primary)
            Text("\(todos.count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.secondary.opacity(0.85))
                .monospacedDigit()
            Spacer()
            Button {
                markAllComplete()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                    Text("全部已完成")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(AppPalette.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(hoveredAllDone ? AppPalette.accentSoft : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hoveredAllDone = $0 }
            .help("把所有待办标记为完成")
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private func todoCard(for todo: Todo) -> some View {
        TodoCardWrapper {
            TodoRowView(
                todo: todo,
                onToggle: { toggleCompleted(todo) },
                onEdit:   { openEditPanel(for: todo) },
                trailingMood: catMood(for: todo)
            )
        }
    }

    private var completedHeader: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { showCompleted.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppPalette.secondary)
                    .frame(width: 10)
                Text("已完成")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.primary.opacity(0.85))
                Text("\(completedTodos.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppPalette.secondary.opacity(0.75))
                    .monospacedDigit()
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var allDoneCheer: some View {
        VStack(spacing: 10) {
            PixelCatView(pixel: 3, mood: .sleep, glow: false)
            Text("今天的任务都完成啦～")
                .font(.system(size: 12))
                .foregroundStyle(AppPalette.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - 底部添加触发器

    private var addTrigger: some View {
        Button {
            openAddPanel()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppPalette.accent)
                Text("添加待办（自然语言）")
                    .font(.system(size: 12))
                    .foregroundStyle(AppPalette.secondary.opacity(0.85))
                Spacer()
                Text("⌘N")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppPalette.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppPalette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppPalette.rowCardBase)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppPalette.rowCard)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.rowCardStroke, lineWidth: 0.5)
            )
            .shadow(color: AppPalette.rowCardShadowTight, radius: 2, x: 0, y: 1)
            .shadow(color: AppPalette.rowCardShadowSoft, radius: 12, x: 0, y: 5)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .padding(.top, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
    }


    private func openAddPanel() {
        recordInteraction()
        AddTodoWindowController.shared.show(modelContainer: context.container)
    }

    private func openEditPanel(for todo: Todo) {
        recordInteraction()
        AddTodoWindowController.shared.show(modelContainer: context.container, editing: todo)
    }

    // MARK: - 行为

    private func toggleCompleted(_ todo: Todo) {
        recordInteraction()
        let wasUndone = !todo.isCompleted
        let id = todo.id
        if todo.isCompleted {
            todo.markUncompleted()
        } else {
            todo.markCompleted()
            todo.clearSnooze()
            NotificationManager.shared.cancel(todoId: id)
            AlertWindowController.shared.dismiss(id: id)
            CompletionToastController.shared.show(for: todo)
            if todos.count <= 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    CompletionToastController.shared.showAllDone()
                }
            }
        }
        try? context.save()
        ReminderScheduler.shared.reload()

        if wasUndone {
            triggerCatCelebration()
        }
    }

    private func triggerCatCelebration() {
        catBounce = -14
        cheerUntil = Date().addingTimeInterval(0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            catBounce = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            cheerUntil = nil
        }
    }

    private func markAllComplete() {
        recordInteraction()
        guard !todos.isEmpty else { return }
        for t in todos {
            let id = t.id
            t.markCompleted()
            t.clearSnooze()
            NotificationManager.shared.cancel(todoId: id)
            AlertWindowController.shared.dismiss(id: id)
        }
        try? context.save()
        ReminderScheduler.shared.reload()
        triggerCatCelebration()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            CompletionToastController.shared.showAllDone()
        }
    }

    private func delete(_ todo: Todo) {
        let id = todo.id
        NotificationManager.shared.cancel(todoId: id)
        AlertWindowController.shared.dismiss(id: id)
        context.delete(todo)
        try? context.save()
        ReminderScheduler.shared.reload()
    }

    private func catMood(for todo: Todo) -> CatMood {
        if todo.isCompleted { return .sleep }
        guard let tag = todo.tags.first else { return .idle }
        switch tag {
        case .exercise:           return .exercise
        case .work, .study, .learning, .creative, .planning:
                                  return .sparkle
        case .social, .family:    return .bell
        case .health, .rest:      return .sleep
        default:                  return .wag
        }
    }
}

// MARK: - Header 装饰组合（噪点 + 闪烁星）

private struct HeaderStarsAndNoise: View {
    var body: some View {
        ZStack {
            NoiseTexture(count: 220, maxOpacity: 0.10)
                .blendMode(.overlay)
            TwinklingStars()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 任务卡片浮层包装（半透白 + hover 紫色辉光 + 双层阴影 + 顶部高光）

private struct TodoCardWrapper<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var hovered: Bool = false

    var body: some View {
        ZStack {
            content()
        }
        .background(
            ZStack {
                // 底层暖白（保证文字可读）
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppPalette.rowCardBase)
                // 半透白浮层（rgba(255,255,255,0.65) 的精神）
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppPalette.rowCard)
                // 顶部高光带
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppPalette.rowCardTopHighlight.opacity(0.75),
                                AppPalette.rowCardTopHighlight.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.plusLighter)
                    .opacity(0.55)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    hovered ? AppPalette.rowCardHoverStroke : AppPalette.rowCardStroke,
                    lineWidth: hovered ? 1.0 : 0.5
                )
        )
        .shadow(color: AppPalette.rowCardShadowTight, radius: 2, x: 0, y: 1)
        .shadow(color: AppPalette.rowCardShadowSoft, radius: 14, x: 0, y: 6)
        .shadow(color: hovered ? AppPalette.rowCardHoverGlow : .clear, radius: 16, x: 0, y: 0)
        .scaleEffect(hovered ? 1.012 : 1.0)
        .offset(y: hovered ? -1 : 0)
        .animation(.easeOut(duration: 0.18), value: hovered)
        .onHover { hovered = $0 }
    }
}

#Preview {
    do {
        let container = try ModelContainer(
            for: Todo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext
        ctx.insert(Todo(
            title: "开会",
            dueDate: Date().addingTimeInterval(3600 * 2),
            notifyOffsetSeconds: 15 * 60,
            tags: [.social]
        ))
        ctx.insert(Todo(
            title: "写周报",
            dueDate: Date().addingTimeInterval(3600 * 7),
            notifyOffsetSeconds: 10 * 60,
            priority: .high,
            tags: [.work]
        ))
        ctx.insert(Todo(
            title: "健身",
            dueDate: Date().addingTimeInterval(3600 * 10),
            tags: [.exercise]
        ))
        return ContentView()
            .modelContainer(container)
    } catch {
        return Text("Preview error: \(error.localizedDescription)")
    }
}
