//
//  ShortcutRecorderView.swift
//  喵咚
//
//  快捷键录入控件：点击进入录入态 → 显示"按下快捷键..." → 监听下一个按键组合 →
//  写回 UserDefaults，立即重新注册到 GlobalHotkeyManager。
//
//  ESC / 点外部 / 失焦 → 取消录入，恢复显示原快捷键。
//

import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutRecorderView: View {
    /// 当前已保存的 keyCode（0 = 用默认）
    @AppStorage(AppSettingsKeys.quickCaptureKeyCode) private var savedKeyCode: Int = 0
    /// 当前已保存的修饰键（0 = 用默认）
    @AppStorage(AppSettingsKeys.quickCaptureModifiers) private var savedModifiers: Int = 0

    @State private var recording: Bool = false
    @State private var hovering: Bool = false
    @State private var localKeyMonitor: Any?

    /// 用户在录入时按下的临时显示
    @State private var transientLabel: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if recording { stopRecording(cancelled: true) } else { startRecording() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: recording ? "keyboard.fill" : "keyboard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(recording ? AppPalette.accent : AppPalette.secondary)
                    Text(displayedLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(recording ? AppPalette.accent : AppPalette.primary)
                        .monospacedDigit()
                        .frame(minWidth: 64, alignment: .center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(recording ? AppPalette.accentSoft : (hovering ? Color.white.opacity(0.7) : Color.white.opacity(0.55)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(recording ? AppPalette.accent.opacity(0.6) : AppPalette.separator.opacity(0.6), lineWidth: 0.8)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }

            // 重置按钮
            if isCustomized {
                Button {
                    resetToDefault()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("恢复默认 ⌥Space")
            }
        }
        .onDisappear { stopRecording(cancelled: true) }
    }

    // MARK: - 计算属性

    private var displayedLabel: String {
        if recording {
            return transientLabel.isEmpty ? "按下快捷键…" : transientLabel
        }
        let kc = savedKeyCode == 0 ? Int(GlobalHotkeyManager.defaultKeyCode) : savedKeyCode
        let mm = savedModifiers == 0 ? Int(GlobalHotkeyManager.defaultCarbonModifiers) : savedModifiers
        return GlobalHotkeyManager.displayString(keyCode: UInt32(kc), carbonModifiers: UInt32(mm))
    }

    private var isCustomized: Bool {
        savedKeyCode != 0 || savedModifiers != 0
    }

    // MARK: - 录入流程

    private func startRecording() {
        recording = true
        transientLabel = ""

        // 录入期间先撤销已注册的快捷键，否则按到现有热键会触发原回调
        GlobalHotkeyManager.shared.unregister()

        // 临时本地 monitor 拦截按键，不让它泄露到当前界面
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            return handleKeyEvent(event) ? nil : event
        }
    }

    private func stopRecording(cancelled: Bool) {
        recording = false
        transientLabel = ""
        if let m = localKeyMonitor {
            NSEvent.removeMonitor(m)
            localKeyMonitor = nil
        }
        // 不管是确认还是取消，都按照"当前 saved 值"重新注册一次
        let enabled = UserDefaults.standard.object(forKey: AppSettingsKeys.quickCaptureEnabled) as? Bool ?? true
        if enabled {
            GlobalHotkeyManager.shared.registerFromUserDefaults()
        }
    }

    /// 处理录入期间的按键，返回 true 表示已消费（吃掉事件）
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // ESC：取消
        if event.type == .keyDown && event.keyCode == UInt16(kVK_Escape) {
            stopRecording(cancelled: true)
            return true
        }

        // .flagsChanged：用户还在按修饰键，先实时显示当前组合
        let mods = GlobalHotkeyManager.carbonModifiers(from: event.modifierFlags)
        if event.type == .flagsChanged {
            transientLabel = GlobalHotkeyManager.displayString(carbonModifiers: mods)
            return true
        }

        // .keyDown：实际触发键
        guard event.type == .keyDown else { return false }

        // 单独按修饰键不算（kVK_Command 等会作为 flagsChanged 进来，但保险起见再判一次）
        if isModifierOnlyKey(event.keyCode) { return true }

        // 至少要有一个修饰键，避免和普通输入冲突
        guard mods != 0 else {
            transientLabel = "请同时按下 ⌘/⌥/⌃/⇧"
            return true
        }

        // 拿到 keyCode + modifiers → 保存
        savedKeyCode = Int(event.keyCode)
        savedModifiers = Int(mods)
        stopRecording(cancelled: false)
        return true
    }

    private func isModifierOnlyKey(_ keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_Command, kVK_RightCommand,
             kVK_Shift, kVK_RightShift,
             kVK_Option, kVK_RightOption,
             kVK_Control, kVK_RightControl,
             kVK_CapsLock, kVK_Function:
            return true
        default:
            return false
        }
    }

    private func resetToDefault() {
        savedKeyCode = 0
        savedModifiers = 0
        let enabled = UserDefaults.standard.object(forKey: AppSettingsKeys.quickCaptureEnabled) as? Bool ?? true
        if enabled {
            GlobalHotkeyManager.shared.registerFromUserDefaults()
        }
    }
}
