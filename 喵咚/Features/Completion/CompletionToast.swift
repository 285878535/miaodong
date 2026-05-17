//
//  CompletionToast.swift
//  喵咚
//
//  任务完成提示卡片（按设计图"通知样式示例"）
//
//  - 左侧：绿色圆形对勾
//  - 中间：标题"任务完成！" + 任务名
//  - 右侧：像素猫占位图（"completion_cat" 资源缺省时回退到 SF Symbol）
//  - 顶部右上角：关闭按钮
//  - 入场：scale + opacity 弹性
//

import SwiftUI

struct CompletionToast: View {
    enum Style {
        /// 单个任务完成 —— "任务完成！" + 标题
        case single(title: String)
        /// 全部完成 —— "太棒了！" + "今日所有任务已完成"
        case allDone
        /// 自定义文案
        case custom(title: String, subtitle: String)
    }

    let style: Style
    let onClose: () -> Void

    @State private var visible: Bool = false

    private var titleText: String {
        switch style {
        case .single:   return "任务完成！"
        case .allDone:  return "太棒了！"
        case .custom(let t, _): return t
        }
    }

    private var subtitleText: String {
        switch style {
        case .single(let title): return title
        case .allDone:           return "今日所有任务已完成"
        case .custom(_, let s):  return s
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            checkmarkCircle

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppPalette.primary)
                Text(subtitleText)
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            CompletionCatPlaceholder()
                .frame(width: 48, height: 48)
                .padding(.trailing, 4)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(width: 320)
        .background(AppPalette.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: AppPalette.primary.opacity(0.16), radius: 14, x: 0, y: 6)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppPalette.secondary.opacity(0.55))
                    .padding(7)
            }
            .buttonStyle(.plain)
        }
        .scaleEffect(visible ? 1.0 : 0.85)
        .opacity(visible ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.7)) {
                visible = true
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - 左侧绿色对勾

    private var checkmarkCircle: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.36, green: 0.78, blue: 0.45))
                .frame(width: 22, height: 22)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 占位像素猫（用户提供 Image("completion_cat") 后会自动用真图）

private struct CompletionCatPlaceholder: View {
    @State private var jumping: Bool = false

    var body: some View {
        ZStack {
            // 优先用 Asset 中的 "completion_cat"，找不到则回退到 SF Symbol
            if NSImage(named: "completion_cat") != nil {
                Image("completion_cat")
                    .resizable()
                    .interpolation(.none) // 像素风：禁用插值
                    .scaledToFit()
                    .offset(y: jumping ? -3 : 0)
            } else {
                Image(systemName: "cat.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(AppPalette.primary.opacity(0.9))
                    .offset(y: jumping ? -3 : 0)
            }

            // 星星点缀（与设计图氛围一致）
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
                .offset(x: 18, y: -16)
            Image(systemName: "sparkle")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.pink.opacity(0.85))
                .offset(x: -18, y: 10)
            Image(systemName: "sparkle")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(.yellow)
                .offset(x: 16, y: 14)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                jumping = true
            }
        }
    }
}

#Preview("Single") {
    CompletionToast(style: .single(title: "写周报"), onClose: {})
        .padding()
        .background(Color.gray.opacity(0.1))
}

#Preview("All done") {
    CompletionToast(style: .allDone, onClose: {})
        .padding()
        .background(Color.gray.opacity(0.1))
}
