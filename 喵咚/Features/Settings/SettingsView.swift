//
//  SettingsView.swift
//  喵咚
//
//  独立窗口设置面板（设计图 #6）：左 tab + 右内容
//

import SwiftUI
import ServiceManagement
import AppKit
import Combine

enum AppSettingsKeys {
    static let defaultNotifyOffsetMinutes = "defaultNotifyOffsetMinutes"
    static let defaultRepeatIntervalMinutes = "defaultRepeatIntervalMinutes"
    static let launchAtLogin = "launchAtLogin"
    static let showInMenuBar = "showInMenuBar"
    static let soundEnabled = "soundEnabled"
    static let pixelAlertEnabled = "pixelAlertEnabled"
    static let alertSound = "alertSound"
    static let themeMode = "themeMode"
    /// 图标显示模式（菜单栏 / 灵动岛 / 悬浮窗）
    static let iconDisplayMode = "iconDisplayMode"
    static let accentColor = "accentColor"
    /// 悬浮图标坐标
    static let floatingIconX = "floatingIconX"
    static let floatingIconY = "floatingIconY"
    /// ⌥Space 全局快速捕获开关
    static let quickCaptureEnabled = "quickCaptureEnabled"
    /// 全局快速捕获快捷键 keyCode（kVK_*）
    static let quickCaptureKeyCode = "quickCaptureKeyCode"
    /// 全局快速捕获快捷键修饰键（Carbon 位掩码）
    static let quickCaptureModifiers = "quickCaptureModifiers"
    /// Pomodoro 单次专注分钟数（默认 25）
    static let pomodoroFocusMinutes = "pomodoroFocusMinutes"
    /// Pomodoro 累计专注分钟数
    static let pomodoroTotalMinutes = "pomodoroTotalMinutes"
    /// Pomodoro 今日 🍅 数
    static let pomodoroTodayCount = "pomodoroTodayCount"
    /// Pomodoro 上次记录日期（用于跨日清零 todayCount）
    static let pomodoroLastDate = "pomodoroLastDate"
    /// iCloud 同步开关（默认关闭，要重启 App 生效）
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
}

enum SettingsTab: String, CaseIterable {
    case general, reminder, appearance, about

    var label: String {
        switch self {
        case .general:    return "通用"
        case .reminder:   return "提醒"
        case .appearance: return "外观"
        case .about:      return "关于"
        }
    }
    var icon: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .reminder:   return "bell.fill"
        case .appearance: return "paintbrush.fill"
        case .about:      return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    /// 退出二次确认 —— 菜单栏类 App 退出后要从启动台再启动，按错就麻烦
    private func confirmQuit() {
        let alert = NSAlert()
        alert.messageText = "退出喵咚？"
        alert.informativeText = "退出后小猫将停止陪伴；再次启动需要从启动台或 Spotlight 重新打开。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            content
        }
        .frame(width: 580, height: 420)
        .background(AppPalette.mainBg)
        .preferredColorScheme(.light)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabRow(tab)
            }
            Spacer()

            // 退出按钮
            Button {
                confirmQuit()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                    Text("退出")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color(red: 0.85, green: 0.30, blue: 0.25))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.85, green: 0.30, blue: 0.25).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.bottom, 12)

            // 底部像素猫
            PixelCatMiniView()
                .frame(width: 64, height: 64)
                .padding(.leading, 16)
                .padding(.bottom, 20)
        }
        .padding(.top, 50)
        .padding(.horizontal, 10)
        .frame(width: 150, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(AppPalette.mainBg)
        // 右侧细线分隔
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppPalette.separator.opacity(0.6))
                .frame(width: 0.5)
        }
    }

    private func tabRow(_ tab: SettingsTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: selectedTab == tab ? .bold : .regular))
                    .frame(width: 16, alignment: .center)
                    .foregroundStyle(selectedTab == tab ? AppPalette.accent : AppPalette.secondary)
                Text(tab.label)
                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? AppPalette.accent : AppPalette.primary.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selectedTab == tab ? AppPalette.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppPalette.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 6)
                
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .general:    GeneralSettingsTab()
                    case .reminder:   ReminderSettingsTab()
                    case .appearance: AppearanceSettingsTab()
                    case .about:      AboutSettingsTab()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 通用设置页

private struct GeneralSettingsTab: View {
    @AppStorage(AppSettingsKeys.launchAtLogin) private var launchAtLogin: Bool = false
    @AppStorage(AppSettingsKeys.showInMenuBar) private var showInMenuBar: Bool = true
    @AppStorage(AppSettingsKeys.soundEnabled) private var soundEnabled: Bool = true
    @AppStorage(AppSettingsKeys.alertSound) private var alertSound: String = "default"
    @AppStorage(AppSettingsKeys.themeMode) private var themeMode: String = "system"
    @AppStorage(AppSettingsKeys.iconDisplayMode) private var iconDisplayMode: String = IconDisplayMode.notch.rawValue
    @AppStorage(AppSettingsKeys.quickCaptureEnabled) private var quickCaptureEnabled: Bool = true
    @AppStorage(AppSettingsKeys.iCloudSyncEnabled) private var iCloudSyncEnabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                ToggleRow(title: "开机自动启动", on: launchAtLoginBinding)
                Divider().background(AppPalette.separator.opacity(0.4)).padding(.horizontal, 20)
                ToggleRow(title: "在菜单栏显示图标", on: $showInMenuBar)
                Divider().background(AppPalette.separator.opacity(0.4)).padding(.horizontal, 20)
                ToggleRow(title: "播放提示音", on: $soundEnabled)
                Divider().background(AppPalette.separator.opacity(0.4)).padding(.horizontal, 20)
                quickCaptureRow
                Divider().background(AppPalette.separator.opacity(0.4)).padding(.horizontal, 20)
                ToggleRow(title: "iCloud 同步（重启生效）", on: iCloudSyncBinding)
            }

            VStack(spacing: 12) {
                PickerRow(title: "图标显示", value: iconModeBinding, options: [
                    (IconDisplayMode.menuBar.label,  IconDisplayMode.menuBar.rawValue),
                    (IconDisplayMode.notch.label,    IconDisplayMode.notch.rawValue),
                    (IconDisplayMode.floating.label, IconDisplayMode.floating.rawValue)
                ])
                PickerRow(title: "提示音", value: $alertSound, options: [
                    ("可爱铃声", "default"), ("叮咚", "ding"), ("猫叫", "meow")
                ])
                PickerRow(title: "主题模式", value: $themeMode, options: [
                    ("跟随系统", "system"), ("浅色", "light"), ("深色", "dark")
                ])
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { launchAtLogin }, set: { newValue in
            launchAtLogin = newValue
            applyLaunchAtLogin(newValue)
        })
    }

    /// 写入值的同时发通知，让 AppDelegate 实时切换图标显示模式
    private var iconModeBinding: Binding<String> {
        Binding(
            get: { iconDisplayMode },
            set: { newValue in
                iconDisplayMode = newValue
                NotificationCenter.default.post(name: .iconDisplayModeDidChange, object: nil)
            }
        )
    }

    /// 切换 iCloud 时显式提示"需要重启"，避免用户开了 Toggle 以为立刻生效
    private var iCloudSyncBinding: Binding<Bool> {
        Binding(
            get: { iCloudSyncEnabled },
            set: { newValue in
                iCloudSyncEnabled = newValue
                let alert = NSAlert()
                alert.messageText = newValue ? "已开启 iCloud 同步" : "已关闭 iCloud 同步"
                alert.informativeText = "需要重启喵咚后生效。"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "好的")
                alert.runModal()
            }
        )
    }

    /// 即时启停全局快捷键
    private var quickCaptureBinding: Binding<Bool> {
        Binding(
            get: { quickCaptureEnabled },
            set: { newValue in
                quickCaptureEnabled = newValue
                if newValue {
                    GlobalHotkeyManager.shared.onTriggered = {
                        QuickCaptureController.shared.toggle()
                    }
                    GlobalHotkeyManager.shared.registerFromUserDefaults()
                } else {
                    GlobalHotkeyManager.shared.unregister()
                }
            }
        )
    }

    /// 全局快速添加：开关 + 自定义快捷键录入器同行
    private var quickCaptureRow: some View {
        HStack(spacing: 12) {
            Text("全局快速添加")
                .font(.system(size: 13))
                .foregroundStyle(AppPalette.primary)
            Spacer()
            if quickCaptureEnabled {
                ShortcutRecorderView()
            }
            Toggle("", isOn: quickCaptureBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .tint(AppPalette.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func applyLaunchAtLogin(_ enable: Bool) {
        let service = SMAppService.mainApp
        do {
            if enable { if service.status != .enabled { try service.register() } }
            else { if service.status == .enabled { try service.unregister() } }
        } catch { launchAtLogin = service.status == .enabled }
    }
}

// MARK: - 提醒设置页

private struct ReminderSettingsTab: View {
    @AppStorage(AppSettingsKeys.defaultNotifyOffsetMinutes) private var defaultNotifyOffsetMinutes: Int = 0
    @AppStorage(AppSettingsKeys.defaultRepeatIntervalMinutes) private var defaultRepeatIntervalMinutes: Int = 0
    @AppStorage(AppSettingsKeys.pixelAlertEnabled) private var pixelAlertEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ToggleRow(title: "像素猫弹窗提醒", on: $pixelAlertEnabled)
            Divider().background(AppPalette.separator.opacity(0.4)).padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                IntPickerRow(title: "默认提前时间", value: $defaultNotifyOffsetMinutes, options: [
                    ("准时", 0), ("5 分钟", 5), ("15 分钟", 15), ("30 分钟", 30)
                ])
                IntPickerRow(title: "默认重复间隔", value: $defaultRepeatIntervalMinutes, options: [
                    ("不重复", 0), ("5 分钟", 5), ("10 分钟", 10), ("30 分钟", 30)
                ])
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 其他页面简述

private struct AppearanceSettingsTab: View {
    @AppStorage(AppSettingsKeys.accentColor) private var accentColorId: String = ThemeColor.purple.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("主题色")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppPalette.primary)
                Spacer()
                HStack(spacing: 10) {
                    ForEach(ThemeColor.allCases, id: \.rawValue) { theme in
                        colorSwatch(theme)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().background(AppPalette.separator.opacity(0.4)).padding(.horizontal, 20)

            HStack {
                Text("当前")
                    .font(.system(size: 11))
                    .foregroundStyle(AppPalette.secondary)
                Text(ThemeColor(rawValue: accentColorId)?.label ?? "紫色")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppPalette.accent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func colorSwatch(_ theme: ThemeColor) -> some View {
        let selected = accentColorId == theme.rawValue
        return Button {
            accentColorId = theme.rawValue
            NotificationCenter.default.post(name: .accentColorDidChange, object: nil)
        } label: {
            ZStack {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 28, height: 28)
                if selected {
                    Circle()
                        .strokeBorder(theme.accent, lineWidth: 2)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: selected)
    }
}

private struct AboutSettingsTab: View {
    @State private var checkState: CheckState = .idle

    private enum CheckState: Equatable {
        case idle, checking, upToDate, newVersion(String), failed

        var buttonLabel: String {
            if case .checking = self { return "检查中..." }
            return "检查更新"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            AboutCatAnimationView()
                .frame(width: 96, height: 96)

            VStack(spacing: 4) {
                Text("喵咚")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppPalette.primary)
                    .padding(.top, 8)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .font(.system(size: 13))
                    .foregroundStyle(AppPalette.secondary)
            }

            // 检查更新按钮 + 状态
            VStack(spacing: 8) {
                Button {
                    runCheck()
                } label: {
                    HStack(spacing: 6) {
                        if case .checking = checkState {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(checkState.buttonLabel)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(AppPalette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(checkState == .checking)
                .padding(.top, 16)

                // 状态提示
                Group {
                    switch checkState {
                    case .idle:
                        EmptyView()
                    case .checking:
                        Text("正在检查...")
                            .foregroundStyle(AppPalette.secondary)
                    case .upToDate:
                        Label("已是最新版本", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color(red: 0.22, green: 0.68, blue: 0.42))
                    case .newVersion(let tag):
                        HStack(spacing: 6) {
                            Label("发现新版本 \(tag)", systemImage: "arrow.down.circle.fill")
                                .foregroundStyle(AppPalette.accent)
                            Button("前往下载") {
                                UpdateChecker.shared.openReleasesPage()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppPalette.accent)
                            .underline()
                        }
                    case .failed:
                        Label("检查失败，请稍后重试", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(red: 0.85, green: 0.38, blue: 0.22))
                    }
                }
                .font(.system(size: 11))
                .frame(height: 20)
            }

            Spacer()

            Text("© 2025 Justin Xing. All rights reserved.")
                .font(.system(size: 11))
                .foregroundStyle(AppPalette.secondary.opacity(0.7))
                .padding(.bottom, 20)
        }
    }

    private func runCheck() {
        checkState = .checking
        Task {
            let result = await UpdateChecker.shared.check()
            switch result {
            case .upToDate:
                checkState = .upToDate
            case .newVersion(let tag, _):
                checkState = .newVersion(tag)
            case .error:
                checkState = .failed
            }
        }
    }
}

// MARK: - 通用组件修复

private struct ToggleRow: View {
    let title: String
    @Binding var on: Bool
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppPalette.primary)
            Spacer()
            Toggle("", isOn: $on)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(AppPalette.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct PickerRow: View {
    let title: String
    @Binding var value: String
    let options: [(label: String, value: String)]
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppPalette.primary)
            Spacer()
            Menu {
                ForEach(options, id: \.value) { opt in
                    Button(opt.label) { value = opt.value }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(options.first(where: { $0.value == value })?.label ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppPalette.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppPalette.secondary)
                }
                .frame(width: 110)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppPalette.mainBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppPalette.separator, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
        }
    }
}

private struct IntPickerRow: View {
    let title: String
    @Binding var value: Int
    let options: [(label: String, value: Int)]
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppPalette.primary)
            Spacer()
            Menu {
                ForEach(options, id: \.label) { opt in
                    Button(opt.label) { value = opt.value }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(options.first(where: { $0.value == value })?.label ?? "")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppPalette.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AppPalette.secondary)
                }
                .frame(width: 110)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppPalette.mainBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppPalette.separator, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
        }
    }
}

// MARK: - 迷你像素猫

private struct PixelCatMiniView: View {
    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.64, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let image = loadFrame(named: "complete\(frameIndex + 1)") {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            }
        }
        .onReceive(timer) { _ in
            frameIndex = (frameIndex + 1) % 8
        }
    }

    private func loadFrame(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(name).png")
        if let image = NSImage(contentsOf: sourceURL) {
            return image
        }

        let imageSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("images")
            .appendingPathComponent("output_transparent")
            .appendingPathComponent("\(name).png")
        return NSImage(contentsOf: imageSourceURL)
    }
}

// MARK: - 关于页打招呼猫咪（第五组前2帧，双倍速度）
private struct AboutCatAnimationView: View {
    @State private var frameIndex = 0
    private let timer = Timer.publish(every: 0.32, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let image = loadFrame(named: "wave\(frameIndex + 1)") {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            }
        }
        .onReceive(timer) { _ in
            frameIndex = (frameIndex + 1) % 2
        }
    }

    private func loadFrame(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
            return NSImage(contentsOf: url)
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(name).png")
        if let image = NSImage(contentsOf: sourceURL) {
            return image
        }

        let imageSourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("images")
            .appendingPathComponent("output_transparent")
            .appendingPathComponent("\(name).png")
        return NSImage(contentsOf: imageSourceURL)
    }
}

