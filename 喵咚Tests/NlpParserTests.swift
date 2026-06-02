//
//  NlpParserTests.swift
//  喵咚Tests
//

import Testing
import Foundation
@testable import 喵咚

struct NlpParserTests {

    /// 固定参照时间：2026-05-16 周六 10:00，避免时间漂移
    private static let refDate: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 16
        comps.hour = 10
        comps.minute = 0
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal.date(from: comps)!
    }()

    private var ref: Date { Self.refDate }

    // MARK: 提前提醒

    @Test func 提前提醒_阿拉伯数字() {
        let r = NlpParser.parse("明天下午3点开会，提前30分钟提醒", referenceDate: ref)
        #expect(r.notifyOffsetSeconds == 30 * 60)
    }

    @Test func 提前提醒_中文数字() {
        let r = NlpParser.parse("提醒我开会，提前十分钟", referenceDate: ref)
        #expect(r.notifyOffsetSeconds == 10 * 60)
    }

    @Test func 提前提醒_半小时() {
        let r = NlpParser.parse("会议，提前半小时", referenceDate: ref)
        #expect(r.notifyOffsetSeconds == 30 * 60)
    }

    @Test func 提前提醒_无() {
        let r = NlpParser.parse("喝水", referenceDate: ref)
        #expect(r.notifyOffsetSeconds == 0)
    }

    // MARK: 间隔提醒

    @Test func 间隔提醒_数字() {
        let r = NlpParser.parse("开会，间隔5分钟提醒一次", referenceDate: ref)
        #expect(r.repeatIntervalSeconds == 5 * 60)
    }

    @Test func 间隔提醒_每隔() {
        let r = NlpParser.parse("吃药，每隔2小时", referenceDate: ref)
        #expect(r.repeatIntervalSeconds == 2 * 3600)
    }

    @Test func 间隔提醒_无() {
        let r = NlpParser.parse("提前10分钟提醒", referenceDate: ref)
        #expect(r.repeatIntervalSeconds == nil)
    }

    // MARK: 日期 + 时间

    @Test func 日期时间_明天下午三点() {
        let r = NlpParser.parse("明天下午3点开会", referenceDate: ref)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: r.dueDate!)
        #expect(comps.year == 2026)
        #expect(comps.month == 5)
        #expect(comps.day == 17)
        #expect(comps.hour == 15)
        #expect(comps.minute == 0)
    }

    @Test func 相对偏移_5分钟后() {
        let r = NlpParser.parse("5分钟后喝水", referenceDate: ref)
        let expected = ref.addingTimeInterval(5 * 60)
        #expect(abs(r.dueDate!.timeIntervalSince(expected)) < 1)
    }

    // MARK: 重复

    @Test func 重复_每天() {
        let r = NlpParser.parse("每天8点起床", referenceDate: ref)
        #expect(r.isRecurring)
        #expect(r.recurringPattern == "daily")
    }

    @Test func 重复_工作日() {
        let r = NlpParser.parse("每个工作日打卡", referenceDate: ref)
        #expect(r.isRecurring)
        #expect(r.recurringPattern == "weekdays")
    }

    // MARK: 优先级

    @Test func 优先级_紧急() {
        let r = NlpParser.parse("紧急 提交报告", referenceDate: ref)
        #expect(r.priority == .urgent)
    }

    // MARK: 任务名清理

    @Test func 任务名_去掉提醒我前缀() {
        let r = NlpParser.parse("提醒我喝水", referenceDate: ref)
        #expect(r.title == "喝水")
    }

    @Test func 任务名_空输入返回新提醒() {
        let r = NlpParser.parse("明天", referenceDate: ref)
        #expect(r.title == "新提醒")
    }

    // MARK: 综合场景（用户最关心的）

    @Test func 任务名_去掉如果子句() {
        let r = NlpParser.parse("明天下午3点开会，提前20分钟提醒，如果我没开始，间隔10分钟再提醒我一次", referenceDate: ref)
        #expect(r.title == "开会")
        #expect(r.notifyOffsetSeconds == 20 * 60)
        #expect(r.repeatIntervalSeconds == 10 * 60)
    }

    @Test func 综合_明天下午3点开会提前30分钟间隔5分钟() {
        let r = NlpParser.parse("明天下午3点开会，提前30分钟提醒，间隔5分钟提醒一次", referenceDate: ref)
        #expect(r.title == "开会")
        #expect(r.notifyOffsetSeconds == 30 * 60)
        #expect(r.repeatIntervalSeconds == 5 * 60)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.day, .hour, .minute], from: r.dueDate!)
        #expect(comps.day == 17)
        #expect(comps.hour == 15)
        #expect(comps.minute == 0)
    }

    // MARK: 下周X —— 这是历史上算错"多算一周"的分支，单独锁住

    /// refDate 是 2026-05-16 周六，下周一应该是 5-18（2 天后），不是 5-25
    @Test func 下周一_周六说() {
        let r = NlpParser.parse("下周一开会", referenceDate: ref)
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day], from: r.dueDate!)
        #expect(comps.year == 2026)
        #expect(comps.month == 5)
        #expect(comps.day == 18)
    }

    /// 2026-05-20 周三，下周一应该是 5-25（5 天后），不是 6-1
    @Test func 下周一_周三说() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 20; comps.hour = 10
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
        let wedRef = cal.date(from: comps)!

        let r = NlpParser.parse("下周一开会", referenceDate: wedRef)
        let c = cal.dateComponents([.month, .day], from: r.dueDate!)
        #expect(c.month == 5)
        #expect(c.day == 25)
    }

    /// 2026-05-18 周一，下周一应该是 5-25（7 天后）
    @Test func 下周一_周一说() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 18; comps.hour = 10
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
        let monRef = cal.date(from: comps)!

        let r = NlpParser.parse("下周一开会", referenceDate: monRef)
        let c = cal.dateComponents([.month, .day], from: r.dueDate!)
        #expect(c.month == 5)
        #expect(c.day == 25)
    }

    /// 不带具体星期的"下周" = 下周一
    @Test func 下周无星期() {
        let r = NlpParser.parse("下周交报告", referenceDate: ref)
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.month, .day], from: r.dueDate!)
        #expect(c.month == 5)
        #expect(c.day == 18)
    }

    // MARK: 周末 —— 历史上当天周六会被算成 0 天后但语义不清晰

    /// refDate 周六说"周末" → 应当返回今天
    @Test func 周末_周六说() {
        let r = NlpParser.parse("周末聚会", referenceDate: ref)
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.month, .day], from: r.dueDate!)
        #expect(c.month == 5)
        #expect(c.day == 16)
    }

    /// 周三说"周末" → 周六（3 天后 = 5-19 周六）
    @Test func 周末_周三说() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 5; comps.day = 20; comps.hour = 10
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
        let wedRef = cal.date(from: comps)!

        let r = NlpParser.parse("周末聚会", referenceDate: wedRef)
        let c = cal.dateComponents([.month, .day], from: r.dueDate!)
        #expect(c.month == 5)
        #expect(c.day == 23)
    }

    // MARK: 中文数字两位 + 百

    @Test func 中文数字_二十五分钟后() {
        let r = NlpParser.parse("二十五分钟后喝水", referenceDate: ref)
        let expected = ref.addingTimeInterval(25 * 60)
        #expect(abs(r.dueDate!.timeIntervalSince(expected)) < 1)
    }

    @Test func 中文数字_提前二十分钟() {
        let r = NlpParser.parse("开会，提前二十分钟提醒", referenceDate: ref)
        #expect(r.notifyOffsetSeconds == 20 * 60)
    }

    @Test func 中文数字_提前一百秒() {
        let r = NlpParser.parse("拍照，提前一百秒提醒", referenceDate: ref)
        #expect(r.notifyOffsetSeconds == 100)
    }

    // MARK: 跨年 —— 12 月底说 1 月 X 日应当落到明年

    @Test func 跨年_12月说1月() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 12; comps.day = 30; comps.hour = 10
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
        let decRef = cal.date(from: comps)!

        let r = NlpParser.parse("1月5日提交", referenceDate: decRef)
        let c = cal.dateComponents([.year, .month, .day], from: r.dueDate!)
        #expect(c.year == 2027)
        #expect(c.month == 1)
        #expect(c.day == 5)
    }
}
