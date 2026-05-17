//
//  NotchIslandView.swift
//  喵咚
//
//  灵动岛 SwiftUI 视图：闭合时一个黑色"刘海"+ 像素小猫；展开时一个圆角面板承载待办 ContentView。
//

import SwiftUI

struct NotchIslandView<Content: View>: View {
    @ObservedObject var viewModel: NotchIslandViewModel
    let content: Content

    init(viewModel: NotchIslandViewModel, @ViewBuilder content: () -> Content) {
        self.viewModel = viewModel
        self.content = content()
    }

    private var isOpen: Bool { viewModel.status == .opened }

    var body: some View {
        VStack(spacing: 0) {
            island
                .frame(
                    width: isOpen ? viewModel.openedSize.width : viewModel.closedWidth,
                    height: isOpen ? viewModel.openedSize.height : viewModel.closedHeight,
                    alignment: .top
                )
                .animation(
                    .spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.2),
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
                NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
                    .fill(Color.black)
                    .clipShape(NotchShape(topCornerRadius: 6, bottomCornerRadius: 14))
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

    // MARK: - 闭合态：黑色刘海中央一只像素小白猫

    private var closedDecoration: some View {
        // 仅在「物理无刘海」的屏幕上画出一个小猫提示用户位置；
        // 在真刘海上则与系统刘海融为一体，不放视觉元素，避免遮挡 FaceTime 摄像头
        Group {
            if !viewModel.hasPhysicalNotch {
                Text("🐱")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
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
