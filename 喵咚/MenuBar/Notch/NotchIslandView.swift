//
//  NotchIslandView.swift
//  喵咚
//
//  灵动岛 SwiftUI 视图：闭合时一个黑色"刘海"+ 像素小猫；展开时一个圆角面板承载待办 ContentView。
//

import SwiftUI
import AppKit
import Combine
import SwiftData

struct NotchIslandView<Content: View>: View {
    @Query(filter: #Predicate<Todo> { !$0.isCompleted })
    private var activeTodos: [Todo]

    @ObservedObject var viewModel: NotchIslandViewModel
    let content: Content

    init(viewModel: NotchIslandViewModel, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.content = content()
    }

    private var isOpen: Bool { viewModel.status == .opened }
    private var hasTodayTodos: Bool {
        activeTodos.contains { todo in
            guard let dueDate = todo.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            island
                .frame(
                    width: isOpen ? viewModel.openedSize.width : viewModel.closedWidth,
                    height: isOpen ? viewModel.openedSize.height : viewModel.closedHeight,
                    alignment: .top
                )
                .animation(
                    .spring(response: 0.84, dampingFraction: 0.86, blendDuration: 0.4),
                    value: viewModel.status
                )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var island: some View {
        ZStack(alignment: .top) {
            // 闭合态：完整的黑色刘海药丸（与系统刘海融合，所以左右底全是黑的）
            if !isOpen {
                NotchShape(topCornerRadius: 0, bottomCornerRadius: 14)
                    .fill(Color.black)
                    .clipShape(NotchShape(topCornerRadius: 0, bottomCornerRadius: 14))
                    .transition(.opacity)
                // 跑马灯边框（参考 codexisland LoadingSweep）
                NotchSweep()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if isOpen {
                openedContent
                    // 内容上移到 NSPanel 顶部，让 header 自己从屏幕顶边连续绘制。
                    .offset(y: -viewModel.openedSafeTopInset - 28)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                closedDecoration
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 闭合态：黑色常驻状态栏 + 左侧睡眠动画

    private var closedDecoration: some View {
        HStack(spacing: 0) {
            StatusCatFrameAnimation(
                frameNames: hasTodayTodos
                    ? (3...6).map { "wave\($0)" }
                    : (5...8).map { "sleep\($0)" }
            )
                .frame(width: 42, height: 32)
                .padding(.leading, 4)
                .padding(.bottom, 1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.36), value: hasTodayTodos)
    }

    // MARK: - 展开态：内嵌 ContentView
    //
    // ContentView 自己已经做了 topRadius 28 / bottomRadius 18 的非对称圆角剪裁，
    // 这里只需提供尺寸；外层 NotchShape 的黑色填充会与 ContentView 顶部的
    // 深色 header 自然融合，看起来就是"刘海下吊一只小猫窝"。
    private var openedContent: some View {
        content
            .frame(
                width: viewModel.openedContentSize.width,
                height: viewModel.openedContentSize.height
            )
    }
}

// MARK: - 刘海跑马灯边框（参考 codexisland LoadingSweep）
//
// TimelineView 30Hz，AngularGradient 以 100°/s 旋转，形成彗星尾巴扫过刘海轮廓的效果。
private struct NotchSweep: View {
    // @AppStorage 驱动主题色变更时重渲染
    @AppStorage(AppSettingsKeys.accentColor) private var _accentId: String = ThemeColor.purple.rawValue

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let rotation = (t * 100).truncatingRemainder(dividingBy: 360)
            NotchShape(topCornerRadius: 0, bottomCornerRadius: 14)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear,               location: 0.00),
                            .init(color: AppPalette.accent.opacity(0.0),  location: 0.55),
                            .init(color: AppPalette.accent,               location: 0.78),
                            .init(color: .white.opacity(0.95), location: 0.92),
                            .init(color: AppPalette.accent.opacity(0.0),  location: 1.00),
                        ]),
                        center: .center,
                        angle: .degrees(rotation)
                    ),
                    lineWidth: 1.5
                )
                .blur(radius: 2)
        }
    }
}

private struct StatusCatFrameAnimation: View {
    let frameNames: [String]

    @State private var frameIndex = 0

    private let timer = Timer.publish(every: 0.64, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let image = loadFrame(named: frameNames[frameIndex % frameNames.count]) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            }
        }
        .onReceive(timer) { _ in
            frameIndex = (frameIndex + 1) % frameNames.count
        }
        .onChange(of: frameNames) { _, _ in
            frameIndex = 0
        }
    }

    private func loadFrame(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "SleepCat") {
            return NSImage(contentsOf: url)
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("SleepCat")
            .appendingPathComponent("\(name).png")
        return NSImage(contentsOf: sourceURL)
    }
}
