//
//  PomodoroSession.swift
//  喵咚
//
//  Pomodoro 会话状态机 + 当日 / 累计统计（UserDefaults 持久化）。
//  纯逻辑层，不依赖任何 UI；PomodoroController 订阅它的 published 属性。
//
//  计时方式：基于 sessionStartDate 推算 remainingSeconds，
//  这样系统睡眠 / Timer 漏 tick 都能在下一次 tick 自动补正，而不是按 tick 计数衰减。
//

import Foundation
import Combine
import AppKit

@MainActor
final class PomodoroSession: ObservableObject {
    enum State: Equatable {
        case idle              // 未开始
        case running           // 倒计时进行中
        case paused            // 用户主动暂停
        case finished          // 自然结束（等用户关闭/重启）
    }

    // MARK: - 配置（受设置项控制）

    /// 单次专注分钟数，默认 25
    @Published var focusMinutes: Int = UserDefaults.standard.integer(forKey: AppSettingsKeys.pomodoroFocusMinutes).clamped(default: 25, range: 5...90)

    // MARK: - 运行时状态

    @Published private(set) var state: State = .idle
    @Published private(set) var remainingSeconds: Int = 25 * 60
    /// 当前会话的任务标签（可选）
    @Published var taskLabel: String = ""

    // MARK: - 统计

    /// 今日完成的 pomodoro 次数
    @Published private(set) var todayCount: Int = 0
    /// 累计专注分钟数
    @Published private(set) var totalMinutes: Int = 0

    /// 会话结束回调（PomodoroController 订阅后弹通知 / 切动画）
    var onFinished: () -> Void = {}

    private var timer: Timer?

    // MARK: - 时间锚点
    //
    // sessionStartDate：本会话首次 start 的真实时刻（pause 后再 resume 时会平移）。
    // sessionFocusSeconds：本会话目标专注秒数（用户中途改 focusMinutes 不影响进行中的会话）。
    // tick 时用 `now - sessionStartDate` 推算实际过去多久，避免 Timer 漏 tick 丢秒。
    private var sessionStartDate: Date?
    private var sessionFocusSeconds: Int = 25 * 60

    init() {
        sessionFocusSeconds = focusMinutes * 60
        remainingSeconds = sessionFocusSeconds
        loadStats()
    }

    // MARK: - 状态机

    func start() {
        switch state {
        case .idle, .finished:
            sessionFocusSeconds = focusMinutes * 60
            remainingSeconds = sessionFocusSeconds
            sessionStartDate = Date()
            state = .running
            installTimer()
        case .paused:
            // 从暂停恢复：把 startDate 向前平移 "已消耗的秒数"，
            // 这样 now - startDate 还是当前已消耗时间。
            let elapsed = sessionFocusSeconds - remainingSeconds
            sessionStartDate = Date().addingTimeInterval(-Double(elapsed))
            state = .running
            installTimer()
        case .running:
            break
        }
    }

    func pause() {
        guard state == .running else { return }
        // 暂停前先把 remainingSeconds 算到最新
        recalculateRemaining()
        state = .paused
        invalidateTimer()
    }

    func stop() {
        invalidateTimer()
        state = .idle
        sessionStartDate = nil
        sessionFocusSeconds = focusMinutes * 60
        remainingSeconds = sessionFocusSeconds
    }

    func reset() { stop() }

    // MARK: - Timer

    private func installTimer() {
        invalidateTimer()
        // 每秒触发一次重算，即使错过几次 tick（系统睡眠等），下一次也能立即补正
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard state == .running else { return }
        recalculateRemaining()
        if remainingSeconds <= 0 {
            finish()
        }
    }

    /// 基于 sessionStartDate 重新计算 remainingSeconds（运行态唯一真理源）。
    private func recalculateRemaining() {
        guard let start = sessionStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(start).rounded())
        remainingSeconds = max(0, sessionFocusSeconds - elapsed)
    }

    private func finish() {
        invalidateTimer()
        let minutes = sessionFocusSeconds / 60
        state = .finished
        remainingSeconds = 0
        sessionStartDate = nil
        todayCount += 1
        totalMinutes += minutes
        saveStats()
        // 给猫加经验 + 推进 streak
        CatGrowth.shared.awardPomodoro()
        onFinished()
    }

    // MARK: - 设置变更

    /// 用户在设置里改了 focusMinutes，刷新 idle 状态下的显示
    func applyFocusMinutesChange(_ minutes: Int) {
        focusMinutes = minutes.clamped(default: 25, range: 5...90)
        UserDefaults.standard.set(focusMinutes, forKey: AppSettingsKeys.pomodoroFocusMinutes)
        if state == .idle || state == .finished {
            sessionFocusSeconds = focusMinutes * 60
            remainingSeconds = sessionFocusSeconds
        }
    }

    // MARK: - 持久化

    private func loadStats() {
        let ud = UserDefaults.standard
        totalMinutes = ud.integer(forKey: AppSettingsKeys.pomodoroTotalMinutes)

        // todayCount 跨日清零：保存 lastDate，对比今天日期
        let saved = ud.integer(forKey: AppSettingsKeys.pomodoroTodayCount)
        let savedDay = ud.string(forKey: AppSettingsKeys.pomodoroLastDate) ?? ""
        let today = Self.todayKey()
        if savedDay == today {
            todayCount = saved
        } else {
            todayCount = 0
            ud.set(0, forKey: AppSettingsKeys.pomodoroTodayCount)
            ud.set(today, forKey: AppSettingsKeys.pomodoroLastDate)
        }
    }

    private func saveStats() {
        let ud = UserDefaults.standard
        ud.set(totalMinutes, forKey: AppSettingsKeys.pomodoroTotalMinutes)
        ud.set(todayCount, forKey: AppSettingsKeys.pomodoroTodayCount)
        ud.set(Self.todayKey(), forKey: AppSettingsKeys.pomodoroLastDate)
    }

    /// "yyyy-MM-dd"，锁定 en_US_POSIX + 用户当前时区，避免 ja-JP-u-ca-japanese 等 locale
    /// 把年份输出成 "令和08-05-18" 这种字符串导致比对失败。
    private static let todayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private static func todayKey() -> String {
        todayKeyFormatter.string(from: Date())
    }
}

private extension Int {
    func clamped(default def: Int, range: ClosedRange<Int>) -> Int {
        if self == 0 { return def }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
