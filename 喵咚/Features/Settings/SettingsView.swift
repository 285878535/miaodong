//
//  SettingsView.swift
//  喵咚
//
//  独立窗口设置面板（设计图 #6）：左 tab + 右内容
//

import SwiftUI
import ServiceManagement

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
    /// 悬浮图标坐标
    static let floatingIconX = "floatingIconX"
    static let floatingIconY = "floatingIconY"
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

    var body: some View {
        VStack(spacing: 0) {
            Group {
                ToggleRow(title: "开机自动启动", on: launchAtLoginBinding)
                Divider().background(AppPalette.separator.opacity(0.4)).padding(.horizontal, 20)
                ToggleRow(title: "在菜单栏显示图标", on: $showInMenuBar)
                Divider().background(AppPalette.separator.opacity(0.4)).padding(.horizontal, 20)
                ToggleRow(title: "播放提示音", on: $soundEnabled)
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
    var body: some View {
        VStack {
            Spacer()
            Text("外观设置即将上线喵～").font(.system(size: 14)).foregroundStyle(AppPalette.secondary)
            Spacer()
        }
    }
}

private struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cat.fill").font(.system(size: 48)).foregroundStyle(AppPalette.accent)
            VStack(spacing: 4) {
                Text("喵咚").font(.system(size: 20, weight: .bold))
                Text("Version 1.0.0").font(.system(size: 13)).foregroundStyle(AppPalette.secondary)
            }
            Spacer()
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
    var body: some View {
        ZStack {
            VStack(spacing: -1) {
                HStack(spacing: 28) {
                    Rectangle().fill(AppPalette.primary).frame(width: 10, height: 10)
                    Rectangle().fill(AppPalette.primary).frame(width: 10, height: 10)
                }
                Rectangle()
                    .stroke(AppPalette.primary, lineWidth: 3)
                    .background(Color.white)
                    .frame(width: 52, height: 42)
                    .cornerRadius(6)
                
                HStack(spacing: 4) {
                    Rectangle().fill(AppPalette.primary).frame(width: 12, height: 5)
                    Rectangle().fill(AppPalette.primary).frame(width: 12, height: 5)
                }
            }
            
            HStack(spacing: 16) {
                Circle().fill(AppPalette.primary).frame(width: 5, height: 5)
                Circle().fill(AppPalette.primary).frame(width: 5, height: 5)
            }
            .padding(.top, 4)
        }
    }
}


