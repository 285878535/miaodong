//
//  CatGrowth.swift
//  喵咚
//
//  猫的成长系统：经验、等级、连续天数（streak）。
//  纯 UserDefaults 持久化，跨设备同步等以后通过 NSUbiquitousKeyValueStore 升级。
//
//  XP 来源：
//    - 完成一条 todo：+10
//    - 完成一个 pomodoro 番茄钟：+25
//
//  等级曲线：lv N 所需累计 XP = 100 * N^1.5（粗略：lv2 需要 ~283, lv3 ~520, lv10 ~3162）
//

import Foundation
import Combine

@MainActor
final class CatGrowth: ObservableObject {
    static let shared = CatGrowth()

    // MARK: - Published 状态

    @Published private(set) var totalXP: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    /// 升级事件：UI 订阅后播放庆祝动画
    @Published var pendingLevelUp: Int? = nil  // 升到的新等级

    // MARK: - XP 计算

    /// 完成一条 todo 给的经验
    static let xpPerTodo: Int = 10
    /// 完成一个 pomodoro 给的经验
    static let xpPerPomodoro: Int = 25

    private init() {
        load()
        // 启动时先校准一次 streak（用户可能跨日打开，需要判断是否中断）
        recalculateStreakOnLaunch()
    }

    // MARK: - 公开 API

    /// 完成一条 todo：加 XP + 推进 streak
    func awardTodoCompletion() {
        addXP(Self.xpPerTodo)
        recordActivityDay()
    }

    /// 完成一个 pomodoro
    func awardPomodoro() {
        addXP(Self.xpPerPomodoro)
        recordActivityDay()
    }

    /// 当前等级所在区间 [当前等级阈值, 下一级阈值)
    var levelRange: (lower: Int, upper: Int) {
        let lower = xpForLevel(level)
        let upper = xpForLevel(level + 1)
        return (lower, upper)
    }

    /// 当前等级内进度 [0, 1]
    var levelProgress: Double {
        let (lo, hi) = levelRange
        guard hi > lo else { return 0 }
        return min(1.0, max(0.0, Double(totalXP - lo) / Double(hi - lo)))
    }

    // MARK: - 内部：XP + 升级

    private func addXP(_ amount: Int) {
        let oldLevel = level
        totalXP += amount
        let newLevel = computeLevel(for: totalXP)
        if newLevel > oldLevel {
            level = newLevel
            pendingLevelUp = newLevel
        }
        save()
    }

    /// 累计 xp 所对应的等级（最低 1 级）
    private func computeLevel(for xp: Int) -> Int {
        var lv = 1
        while xpForLevel(lv + 1) <= xp { lv += 1 }
        return lv
    }

    /// 升到 level 需要的累计 XP
    /// level=1 → 0；level=2 → 100；level=3 → 283；level=10 → 3162
    private func xpForLevel(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        let n = Double(level - 1)
        return Int(100.0 * pow(n, 1.5))
    }

    // MARK: - Streak

    /// 记录今天有活动；如果离上次活动 > 1 天，streak 中断重置为 1
    private func recordActivityDay() {
        let ud = UserDefaults.standard
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if let last = ud.object(forKey: Keys.streakLastActiveDate) as? Date {
            let lastDay = cal.startOfDay(for: last)
            if lastDay == today {
                return  // 今天已经记过了，streak 不变
            }
            let dayGap = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if dayGap == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        ud.set(today, forKey: Keys.streakLastActiveDate)
        save()
    }

    /// 启动时调一次：如果今天没活动且距上次活动 > 1 天，把 currentStreak 标记为已中断
    /// （不直接清零，等用户今天完成第一条 todo 时由 recordActivityDay() 重置）
    private func recalculateStreakOnLaunch() {
        guard currentStreak > 0 else { return }
        let ud = UserDefaults.standard
        guard let last = ud.object(forKey: Keys.streakLastActiveDate) as? Date else {
            currentStreak = 0
            return
        }
        let cal = Calendar.current
        let lastDay = cal.startOfDay(for: last)
        let today = cal.startOfDay(for: Date())
        let dayGap = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if dayGap > 1 {
            // 中间空过了，streak 算断
            currentStreak = 0
            save()
        }
    }

    // MARK: - 持久化

    private enum Keys {
        static let totalXP = "growth_total_xp"
        static let level = "growth_level"
        static let currentStreak = "growth_current_streak"
        static let longestStreak = "growth_longest_streak"
        static let streakLastActiveDate = "growth_streak_last_active_date"
    }

    private func load() {
        let ud = UserDefaults.standard
        totalXP = ud.integer(forKey: Keys.totalXP)
        // 等级始终从 XP 重算，避免脏数据
        level = max(1, computeLevel(for: totalXP))
        currentStreak = ud.integer(forKey: Keys.currentStreak)
        longestStreak = ud.integer(forKey: Keys.longestStreak)
    }

    private func save() {
        let ud = UserDefaults.standard
        ud.set(totalXP, forKey: Keys.totalXP)
        ud.set(level, forKey: Keys.level)
        ud.set(currentStreak, forKey: Keys.currentStreak)
        ud.set(longestStreak, forKey: Keys.longestStreak)
    }

    /// 调试 / 设置里"重置"用
    func resetAll() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: Keys.totalXP)
        ud.removeObject(forKey: Keys.level)
        ud.removeObject(forKey: Keys.currentStreak)
        ud.removeObject(forKey: Keys.longestStreak)
        ud.removeObject(forKey: Keys.streakLastActiveDate)
        totalXP = 0
        level = 1
        currentStreak = 0
        longestStreak = 0
        pendingLevelUp = nil
    }
}
