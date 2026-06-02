//
//  GlobalHotkeyManager.swift
//  喵咚
//
//  全局快捷键管理 —— 用 Carbon RegisterEventHotKey 注册系统级热键，
//  在任何 App 前台时按下都会触发（且事件被消费，不会泄露到当前 App）。
//
//  注：NSEvent.addGlobalMonitorForEvents 只能"观察"按键，无法吞掉事件，
//  所以会和 ⌥Space 已有绑定冲突（比如 Spotlight 部分场景）；
//  必须用 Carbon API 才能像 Alfred / 1Password 那样独占快捷键。
//

import AppKit
import Carbon
import Carbon.HIToolbox

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handlerInstalled = false

    /// 快捷键触发回调（在 MainActor 上执行）
    var onTriggered: () -> Void = {}

    /// 默认快捷键 ⌥Space
    static let defaultKeyCode: UInt32 = UInt32(kVK_Space)
    static let defaultCarbonModifiers: UInt32 = UInt32(optionKey)

    private init() {}

    // MARK: - 公开 API

    /// 用 UserDefaults 里保存的自定义快捷键去注册；没保存就用默认 ⌥Space
    func registerFromUserDefaults() {
        let ud = UserDefaults.standard
        let keyCode = UInt32(ud.integer(forKey: AppSettingsKeys.quickCaptureKeyCode))
        let mods    = UInt32(ud.integer(forKey: AppSettingsKeys.quickCaptureModifiers))
        let kc = keyCode == 0 ? Self.defaultKeyCode : keyCode
        let mm = mods    == 0 ? Self.defaultCarbonModifiers : mods
        register(keyCode: kc, carbonModifiers: mm)
    }

    /// 注册任意快捷键。先撤销旧的，幂等。
    /// - Parameters:
    ///   - keyCode: kVK_* 常量
    ///   - carbonModifiers: Carbon 修饰键位掩码（cmdKey / shiftKey / optionKey / controlKey 的按位或）
    func register(keyCode: UInt32, carbonModifiers: UInt32) {
        unregister()
        installHandlerIfNeeded()

        let signature = Self.fourCharCode("MIAO")
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        } else {
            NSLog("[GlobalHotkey] RegisterEventHotKey failed: keyCode=\(keyCode) mods=\(carbonModifiers) status=\(status)")
        }
    }

    /// 撤销当前注册的快捷键（事件 handler 仍保留，方便后续重注）
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    // MARK: - 修饰键转换 + 显示

    /// NSEvent.modifierFlags → Carbon 位掩码
    static func carbonModifiers(from cocoaFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if cocoaFlags.contains(.command) { carbon |= UInt32(cmdKey) }
        if cocoaFlags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if cocoaFlags.contains(.option)  { carbon |= UInt32(optionKey) }
        if cocoaFlags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }

    /// 把 Carbon 修饰键位掩码格式化成 "⌃⌥⇧⌘" 这种字符串
    static func displayString(carbonModifiers: UInt32) -> String {
        var parts: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if carbonModifiers & UInt32(optionKey)  != 0 { parts.append("⌥") }
        if carbonModifiers & UInt32(shiftKey)   != 0 { parts.append("⇧") }
        if carbonModifiers & UInt32(cmdKey)     != 0 { parts.append("⌘") }
        return parts.joined()
    }

    /// kVK_* → 可读字符（"A", "Space", "↩" 等）
    static func displayString(keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            // 字母 / 数字 / 标点：用 UCKeyTranslate 取出无修饰键时的字符
            return letterFor(keyCode: keyCode) ?? "key\(keyCode)"
        }
    }

    /// 完整快捷键展示，如 "⌥Space" / "⇧⌘A"
    static func displayString(keyCode: UInt32, carbonModifiers: UInt32) -> String {
        displayString(carbonModifiers: carbonModifiers) + displayString(keyCode: keyCode)
    }

    /// 用 UCKeyTranslate 查 keyCode 对应的字符（仅字母 / 数字 / 标点会落到这里）
    private static func letterFor(keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status = layoutData.withUnsafeBytes { rawPtr -> OSStatus in
            guard let layoutPtr = rawPtr.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(-1)
            }
            return UCKeyTranslate(
                layoutPtr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }

    // MARK: - Carbon event handler

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // C 回调没法捕获 Swift 上下文，通过 userData 把 self 指针传进去
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(noErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                // 回到 MainActor 上跑业务逻辑
                Task { @MainActor in
                    manager.onTriggered()
                }
                return OSStatus(noErr)
            },
            1,
            &eventType,
            selfPtr,
            &handler
        )
        if status == noErr {
            eventHandler = handler
            handlerInstalled = true
        } else {
            NSLog("[GlobalHotkey] InstallEventHandler failed: status=\(status)")
        }
    }

    /// 四字符 OSType（Carbon 历史遗留：每个 hotkey 需要一个 application-unique signature）
    private static func fourCharCode(_ str: String) -> OSType {
        var result: OSType = 0
        for byte in str.utf8.prefix(4) {
            result = (result << 8) | OSType(byte)
        }
        return result
    }
}
