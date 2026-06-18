//
//  ReminderSound.swift
//  喵咚
//
//  提示音的唯一出口：把设置页的「播放提示音」开关 + 「提示音」选择器真正接上线。
//
//  —— 占位音频约定 ——
//  把音频文件（caf / aiff / wav / mp3 任一）放进 App bundle，文件名按下表命名即自动生效；
//  没放对应文件时退回系统内置音，保证当前就有声音反馈，方便先跑通、之后再替换。
//
//    提示音选项（alertSound）   文件名（不含扩展名）
//    可爱铃声  "default"   →   alert_default
//    叮咚      "ding"      →   alert_ding
//    猫叫      "meow"      →   alert_meow
//

import AppKit
import UserNotifications

enum ReminderSound {
    /// 「播放提示音」总开关，默认开
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKeys.soundEnabled) as? Bool ?? true
    }

    /// 当前选中的提示音 key（default / ding / meow）
    static var selectedKey: String {
        UserDefaults.standard.string(forKey: AppSettingsKeys.alertSound) ?? "default"
    }

    /// 选项 key → 占位音频资源名
    static func resourceName(for key: String) -> String {
        switch key {
        case "ding": return "alert_ding"
        case "meow": return "alert_meow"
        default:     return "alert_default"
        }
    }

    private static let candidateExtensions = ["caf", "aiff", "aif", "wav", "mp3", "m4a"]

    /// bundle 里是否打包了该选项对应的占位音频
    private static func bundledURL(for key: String) -> URL? {
        let name = resourceName(for: key)
        for ext in candidateExtensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    /// 系统通知用的声音；关闭提示音时返回 nil（横幅静默）。
    /// 找得到打包的占位音频就用它，否则退回系统默认音，保证当前有声。
    static func notificationSound() -> UNNotificationSound? {
        guard isEnabled else { return nil }
        if let url = bundledURL(for: selectedKey) {
            return UNNotificationSound(named: UNNotificationSoundName(url.lastPathComponent))
        }
        return .default
    }

    /// 应用内提醒弹窗出现时播放；关闭提示音时不发声。
    /// 没放自定义文件时退回系统内置音（Glass），保证有反馈。
    static func playInAppAlert() {
        guard isEnabled else { return }
        play(key: selectedKey)
    }

    /// 试听指定提示音：忽略「播放提示音」总开关，用于设置页切换选项时即时播放，
    /// 让用户能直接听到每个选项的声音。
    static func playPreview(for key: String) {
        play(key: key)
    }

    private static func play(key: String) {
        if let url = bundledURL(for: key), let sound = NSSound(contentsOf: url, byReference: true) {
            sound.play()
            return
        }
        // 没放自定义文件时退回系统内置音，保证有反馈
        NSSound(named: "Glass")?.play()
    }
}
