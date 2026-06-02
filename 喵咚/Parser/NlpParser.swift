//
//  NlpParser.swift
//  喵咚
//
//  自然语言提醒事项解析器（规则版，移植自 TodoApp，剥离计时器相关逻辑）
//  流水线：提前提醒 → 间隔提醒 → 重复 → 日期锚点 → 时间点 → 优先级 → 标签 → 任务名 → 组合
//

import Foundation

struct TodoParseResult {
    let title: String
    let dueDate: Date?
    let notifyOffsetSeconds: Int      // 提前 N 秒提醒（0 = 准时）
    let repeatIntervalSeconds: Int?   // 间隔 N 秒重复提醒（nil = 不重复）
    let priority: Priority
    let tags: [Tag]
    let isRecurring: Bool
    let recurringPattern: String?
    let confidence: Double
}

enum NlpParser {

    // MARK: - 公开 API

    /// 解析自然语言为结构化提醒。
    /// - Parameters:
    ///   - input: 用户输入
    ///   - referenceDate: 解析参照时间（默认现在），测试时可注入固定时间避免漂移
    nonisolated static func parse(_ input: String, referenceDate: Date = Date()) -> TodoParseResult {
        let ctx = ParseContext(referenceDate: referenceDate)
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var matched: [String] = []

        // 关键顺序：提前/间隔在最前，避免 N 分钟被"时间锚点"或重复模式吃掉
        let notifyOffset = extractNotifyOffset(from: &text, matched: &matched)
        let repeatInterval = extractRepeatInterval(from: &text, matched: &matched)

        let recurring = extractRecurring(from: &text, matched: &matched)
        let dateAnchor = extractDateAnchor(from: &text, ctx: ctx, matched: &matched)
        let timeOfDay = extractTimeOfDay(from: &text, matched: &matched)
        let priority = extractPriority(from: &text, matched: &matched)
        let tags = extractTags(from: text)
        let title = extractName(residual: text)

        let dueDate = composeDueDate(dateAnchor: dateAnchor, timeOfDay: timeOfDay, ctx: ctx)

        let confidence = calculateConfidence(
            title: title,
            hasDate: dateAnchor != nil,
            hasTime: timeOfDay != nil,
            hasNotifyOffset: notifyOffset > 0,
            hasRepeatInterval: repeatInterval != nil,
            hasPriority: priority != .medium,
            hasRecurring: recurring.isRecurring
        )

        return TodoParseResult(
            title: title,
            dueDate: dueDate,
            notifyOffsetSeconds: notifyOffset,
            repeatIntervalSeconds: repeatInterval,
            priority: priority,
            tags: tags,
            isRecurring: recurring.isRecurring,
            recurringPattern: recurring.pattern,
            confidence: confidence
        )
    }
}

// MARK: - 上下文 & 辅助结构

private struct ParseContext {
    let referenceDate: Date
    let calendar: Calendar
    init(referenceDate: Date) {
        self.referenceDate = referenceDate
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        self.calendar = cal
    }
}

private struct TimeOfDay {
    let hour: Int
    let minute: Int
}

/// 日期锚点。`isExactTime=true` 表示已精确到时分秒（如"5 分钟后"），
/// 此时 composeDueDate 不再叠加 TimeOfDay 默认值。
private struct DateAnchor {
    let date: Date
    let isExactTime: Bool
}

// MARK: - 正则辅助

private struct RegexMatch {
    let fullRange: Range<String.Index>
    let fullString: String
    private let captures: [Range<String.Index>?]

    init?(_ result: NSTextCheckingResult, in text: String) {
        guard let full = Range(result.range, in: text) else { return nil }
        self.fullRange = full
        self.fullString = String(text[full])
        var caps: [Range<String.Index>?] = []
        if result.numberOfRanges > 1 {
            for i in 1..<result.numberOfRanges {
                caps.append(Range(result.range(at: i), in: text))
            }
        }
        self.captures = caps
    }

    func captured(_ idx: Int, in text: String) -> String {
        guard idx >= 1, idx <= captures.count, let r = captures[idx - 1] else { return "" }
        return String(text[r])
    }

    func capturedRange(_ idx: Int) -> Range<String.Index>? {
        guard idx >= 1, idx <= captures.count else { return nil }
        return captures[idx - 1]
    }
}

extension NlpParser {

    fileprivate static func firstMatch(in text: String,
                                       pattern: String,
                                       options: NSRegularExpression.Options = .caseInsensitive) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let nsrange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, options: [], range: nsrange) else { return nil }
        return RegexMatch(result, in: text)
    }

    fileprivate static func removeFirstMatch(from text: inout String,
                                             pattern: String,
                                             options: NSRegularExpression.Options = .caseInsensitive) -> String? {
        guard let m = firstMatch(in: text, pattern: pattern, options: options) else { return nil }
        let s = m.fullString
        text.removeSubrange(m.fullRange)
        return s
    }

    fileprivate static let unitToSeconds: [String: Int] = [
        "秒": 1, "秒钟": 1,
        "分钟": 60,
        "小时": 3600, "时": 3600, "钟头": 3600,
        "天": 86400, "日": 86400
    ]
}

// MARK: - 1. 提前提醒（"提前 30 分钟"）

extension NlpParser {

    fileprivate static func extractNotifyOffset(from text: inout String,
                                                matched: inout [String]) -> Int {
        // 半小时 / 一刻钟（带"提前"）
        if let m = firstMatch(in: text, pattern: "提前\\s*(半小时|半钟头)\\s*(?:提醒)?") {
            text.removeSubrange(m.fullRange)
            matched.append(m.fullString)
            return 30 * 60
        }
        if let m = firstMatch(in: text, pattern: "提前\\s*一刻钟\\s*(?:提醒)?") {
            text.removeSubrange(m.fullRange)
            matched.append(m.fullString)
            return 15 * 60
        }
        // 阿拉伯数字 + 单位
        if let m = firstMatch(in: text, pattern: "提前\\s*(\\d+)\\s*(分钟|小时|时|钟头|秒钟|秒|天|日)\\s*(?:提醒)?") {
            if let n = Int(m.captured(1, in: text)),
               let unit = unitToSeconds[m.captured(2, in: text)] {
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return n * unit
            }
        }
        // 中文数字 + 单位
        if let m = firstMatch(in: text, pattern: "提前\\s*([零一二两三四五六七八九十百]{1,3})\\s*(分钟|小时|时|钟头|秒钟|秒|天|日)\\s*(?:提醒)?") {
            if let n = parseChineseNumber(m.captured(1, in: text)),
               let unit = unitToSeconds[m.captured(2, in: text)] {
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return n * unit
            }
        }
        return 0
    }
}

// MARK: - 2. 间隔提醒（"间隔 5 分钟"/"每隔 5 分钟"）

extension NlpParser {

    fileprivate static func extractRepeatInterval(from text: inout String,
                                                  matched: inout [String]) -> Int? {
        let trigger = "(?:间隔|每隔)"
        let tail = "\\s*(?:提醒(?:一次)?)?"

        if let m = firstMatch(in: text, pattern: "\(trigger)\\s*(半小时|半钟头)\(tail)") {
            text.removeSubrange(m.fullRange)
            matched.append(m.fullString)
            return 30 * 60
        }
        if let m = firstMatch(in: text, pattern: "\(trigger)\\s*一刻钟\(tail)") {
            text.removeSubrange(m.fullRange)
            matched.append(m.fullString)
            return 15 * 60
        }
        if let m = firstMatch(in: text, pattern: "\(trigger)\\s*(\\d+)\\s*(分钟|小时|时|钟头|秒钟|秒|天|日)\(tail)") {
            if let n = Int(m.captured(1, in: text)),
               let unit = unitToSeconds[m.captured(2, in: text)] {
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return n * unit
            }
        }
        if let m = firstMatch(in: text, pattern: "\(trigger)\\s*([零一二两三四五六七八九十百]{1,3})\\s*(分钟|小时|时|钟头|秒钟|秒|天|日)\(tail)") {
            if let n = parseChineseNumber(m.captured(1, in: text)),
               let unit = unitToSeconds[m.captured(2, in: text)] {
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return n * unit
            }
        }
        return nil
    }
}

// MARK: - 3. 重复模式

extension NlpParser {

    fileprivate static func extractRecurring(from text: inout String,
                                             matched: inout [String])
    -> (isRecurring: Bool, pattern: String?) {

        if let s = removeFirstMatch(from: &text, pattern: "每个?工作日") {
            matched.append(s)
            return (true, "weekdays")
        }
        if let m = firstMatch(in: text, pattern: "每月(\\d+)[号日]") {
            let num = m.captured(1, in: text)
            text.removeSubrange(m.fullRange)
            matched.append(m.fullString)
            return (true, "monthly:\(num)")
        }
        if let m = firstMatch(in: text, pattern: "每周([一二三四五六日天1234567]+)") {
            let daysStr = m.captured(1, in: text)
            let mapping: [Character: Int] = [
                "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "日": 7, "天": 7,
                "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7
            ]
            let days = Array(Set(daysStr.compactMap { mapping[$0] })).sorted()
            if !days.isEmpty {
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return (true, "weekly:\(days.map(String.init).joined(separator: ","))")
            }
        }
        if let s = removeFirstMatch(from: &text, pattern: "每天|每日") {
            matched.append(s)
            return (true, "daily")
        }
        return (false, nil)
    }
}

// MARK: - 4. 日期锚点

extension NlpParser {

    fileprivate static func extractDateAnchor(from text: inout String,
                                              ctx: ParseContext,
                                              matched: inout [String]) -> DateAnchor? {
        let cal = ctx.calendar
        let now = ctx.referenceDate
        let startOfToday = cal.startOfDay(for: now)

        // 优先级 0：相对时长偏移（"5 分钟后" / "半小时后"）
        if let anchor = extractRelativeOffset(from: &text, ctx: ctx, matched: &matched) {
            return anchor
        }

        // 优先级 1：相对日期
        let relative: [(String, Int)] = [
            ("大后天", 3),
            ("后天", 2),
            ("明天", 1), ("明儿", 1), ("tomorrow", 1),
            ("今天", 0), ("today", 0)
        ]
        for (kw, offset) in relative {
            if let r = text.range(of: kw, options: .caseInsensitive) {
                text.removeSubrange(r)
                matched.append(kw)
                let d = cal.date(byAdding: .day, value: offset, to: startOfToday)!
                return DateAnchor(date: d, isExactTime: false)
            }
        }

        // 优先级 2：下周 X
        // 语义：本周以周一为起点（firstWeekday=2），"下周X" = 下个周一开始的那一周的 X。
        // 旧实现 `(weekdayNum - today + 7) % 7` 后再 +7 会多算一周，
        // 例如周三说"下周一" → 应是 5 天后，旧代码会得到 12 天。
        if let m = firstMatch(in: text, pattern: "下周([一二三四五六日天])?") {
            let dayChar = m.captured(1, in: text).first
            text.removeSubrange(m.fullRange)
            matched.append(m.fullString)

            // Apple weekday: 周日=1, 周一=2, ..., 周六=7
            // 转 ISO weekday: 周一=1, ..., 周日=7
            let appleToday = cal.component(.weekday, from: now)
            let isoToday = appleToday == 1 ? 7 : appleToday - 1
            // 本周一距今的天数（≤ 0）
            let daysToThisMonday = -(isoToday - 1)
            // 下周一距今的天数
            let daysToNextMonday = daysToThisMonday + 7

            // 目标 weekday（ISO，缺省取下周一）
            let isoTarget: Int = {
                guard let ch = dayChar, let apple = chineseWeekdayToCalendar(ch) else { return 1 }
                return apple == 1 ? 7 : apple - 1
            }()

            let daysUntil = daysToNextMonday + (isoTarget - 1)
            let d = cal.date(byAdding: .day, value: daysUntil, to: startOfToday)!
            return DateAnchor(date: d, isExactTime: false)
        }

        // 优先级 3：周 X / 星期 X
        if let m = firstMatch(in: text, pattern: "(?:周|星期)([一二三四五六日天])") {
            let ch = m.captured(1, in: text).first!
            if let weekdayNum = chineseWeekdayToCalendar(ch) {
                let today = cal.component(.weekday, from: now)
                let daysUntil = (weekdayNum - today + 7) % 7
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                let d = cal.date(byAdding: .day, value: daysUntil, to: startOfToday)!
                return DateAnchor(date: d, isExactTime: false)
            }
        }

        // 优先级 4：M 月 D 日 / M 月 D 号
        if let m = firstMatch(in: text, pattern: "(\\d{1,2})月(\\d{1,2})[日号]") {
            if let month = Int(m.captured(1, in: text)),
               let day = Int(m.captured(2, in: text)),
               (1...12).contains(month), (1...31).contains(day) {
                let date = composeYearMonthDay(month: month, day: day, ctx: ctx)
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return DateAnchor(date: date, isExactTime: false)
            }
        }

        // 优先级 5：M/D 或 M-D
        if let m = firstMatch(in: text, pattern: "(?:^|[^\\d])(\\d{1,2})[/\\-](\\d{1,2})(?!\\d|:)") {
            if let month = Int(m.captured(1, in: text)),
               let day = Int(m.captured(2, in: text)),
               (1...12).contains(month), (1...31).contains(day) {
                let date = composeYearMonthDay(month: month, day: day, ctx: ctx)
                if let r1 = m.capturedRange(1), let r2 = m.capturedRange(2) {
                    text.removeSubrange(r1.lowerBound..<r2.upperBound)
                }
                matched.append("\(month)/\(day)")
                return DateAnchor(date: date, isExactTime: false)
            }
        }

        // 优先级 6：模糊时间
        if let r = text.range(of: "周末", options: .caseInsensitive) {
            text.removeSubrange(r)
            matched.append("周末")
            // Apple weekday: 周日=1, 周六=7
            // "周末" = 即将到来的周六；如果今天就是周六或周日则取今天
            let today = cal.component(.weekday, from: now)
            if today == 7 || today == 1 {
                return DateAnchor(date: startOfToday, isExactTime: false)
            }
            let daysUntil = 7 - today          // 周一~周五到周六的天数：5,4,3,2,1
            let d = cal.date(byAdding: .day, value: daysUntil, to: startOfToday)!
            return DateAnchor(date: d, isExactTime: false)
        }
        if let r = text.range(of: "月底", options: .caseInsensitive) {
            text.removeSubrange(r)
            matched.append("月底")
            let interval = cal.dateInterval(of: .month, for: now)!
            let lastDay = cal.date(byAdding: .day, value: -1, to: interval.end)!
            return DateAnchor(date: cal.startOfDay(for: lastDay), isExactTime: false)
        }
        if let r = text.range(of: "月初", options: .caseInsensitive) {
            text.removeSubrange(r)
            matched.append("月初")
            return DateAnchor(date: firstDayOfMonth(forNowReferringTo: now, cal: cal), isExactTime: false)
        }
        if let r = text.range(of: "下个月", options: .caseInsensitive) {
            text.removeSubrange(r)
            matched.append("下个月")
            let nextMonth = cal.date(byAdding: .month, value: 1, to: now)!
            var comps = cal.dateComponents([.year, .month], from: nextMonth)
            comps.day = 1
            return DateAnchor(date: cal.date(from: comps)!, isExactTime: false)
        }
        if let r = text.range(of: "本周", options: .caseInsensitive) {
            text.removeSubrange(r)
            matched.append("本周")
            return DateAnchor(date: startOfToday, isExactTime: false)
        }

        return nil
    }

    fileprivate static func extractRelativeOffset(from text: inout String,
                                                  ctx: ParseContext,
                                                  matched: inout [String]) -> DateAnchor? {
        if let s = removeFirstMatch(from: &text, pattern: "半小时后|半钟头后") {
            matched.append(s)
            return DateAnchor(date: ctx.referenceDate.addingTimeInterval(30 * 60), isExactTime: true)
        }
        if let s = removeFirstMatch(from: &text, pattern: "一刻钟后") {
            matched.append(s)
            return DateAnchor(date: ctx.referenceDate.addingTimeInterval(15 * 60), isExactTime: true)
        }

        if let m = firstMatch(in: text, pattern: "(\\d+)\\s*(分钟|小时|时|钟头|秒钟|秒|天|日)\\s*后") {
            if let num = Double(m.captured(1, in: text)),
               let mult = unitToSeconds[m.captured(2, in: text)] {
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return DateAnchor(date: ctx.referenceDate.addingTimeInterval(num * Double(mult)), isExactTime: true)
            }
        }

        if let m = firstMatch(in: text, pattern: "([零一二两三四五六七八九十百]{1,3})(分钟|小时|时|钟头|秒钟|秒|天|日)\\s*后") {
            if let n = parseChineseNumber(m.captured(1, in: text)),
               let mult = unitToSeconds[m.captured(2, in: text)] {
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return DateAnchor(date: ctx.referenceDate.addingTimeInterval(Double(n) * Double(mult)), isExactTime: true)
            }
        }

        return nil
    }

    private static func chineseWeekdayToCalendar(_ ch: Character) -> Int? {
        switch ch {
        case "一": return 2
        case "二": return 3
        case "三": return 4
        case "四": return 5
        case "五": return 6
        case "六": return 7
        case "日", "天": return 1
        default: return nil
        }
    }

    private static func composeYearMonthDay(month: Int, day: Int, ctx: ParseContext) -> Date {
        let cal = ctx.calendar
        let now = ctx.referenceDate
        let startOfToday = cal.startOfDay(for: now)
        let currentYear = cal.component(.year, from: now)
        var comps = DateComponents()
        comps.year = currentYear
        comps.month = month
        comps.day = day
        var date = cal.date(from: comps)!
        if date < startOfToday {
            comps.year = currentYear + 1
            date = cal.date(from: comps)!
        }
        return date
    }

    private static func firstDayOfMonth(forNowReferringTo now: Date, cal: Calendar) -> Date {
        let day = cal.component(.day, from: now)
        let base: Date
        if day <= 5 {
            base = now
        } else {
            base = cal.date(byAdding: .month, value: 1, to: now)!
        }
        var comps = cal.dateComponents([.year, .month], from: base)
        comps.day = 1
        return cal.date(from: comps)!
    }
}

// MARK: - 5. 时间点

extension NlpParser {

    fileprivate static func extractTimeOfDay(from text: inout String,
                                             matched: inout [String]) -> TimeOfDay? {

        // 1) H:M
        if let m = firstMatch(in: text, pattern: "(\\d{1,2}):(\\d{2})") {
            if let h = Int(m.captured(1, in: text)),
               let mm = Int(m.captured(2, in: text)),
               (0...23).contains(h), (0...59).contains(mm) {
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return TimeOfDay(hour: h, minute: mm)
            }
        }

        // 2) （时段）? N 点（半 | N 分）?
        let periodPattern = "(凌晨|早上|上午|中午|下午|傍晚|晚上|深夜)?\\s*([零一二两三四五六七八九十百]{1,3}|\\d{1,2})\\s*[点时]\\s*(半|\\d{1,2}\\s*分?)?"
        if let m = firstMatch(in: text, pattern: periodPattern) {
            let periodStr = m.captured(1, in: text)
            let hourStr = m.captured(2, in: text)
            let minStr = m.captured(3, in: text)
            let parsedHour: Int? = Int(hourStr) ?? parseChineseNumber(hourStr)
            if let baseHour = parsedHour, (0...23).contains(baseHour) {
                var h = baseHour
                switch periodStr {
                case "中午":
                    if h < 12 { h = 12 }
                case "下午", "傍晚":
                    if h < 12 { h += 12 }
                case "晚上", "深夜":
                    if h < 12 { h += 12 }
                case "凌晨", "早上", "上午":
                    break
                default:
                    break
                }
                var minute = 0
                if !minStr.isEmpty {
                    if minStr == "半" {
                        minute = 30
                    } else {
                        let digits = minStr.replacingOccurrences(of: "分", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        if let mm = Int(digits), (0...59).contains(mm) { minute = mm }
                    }
                }
                text.removeSubrange(m.fullRange)
                matched.append(m.fullString)
                return TimeOfDay(hour: h, minute: minute)
            }
        }

        // 3) 仅时间段
        let periodDefaults: [(String, Int)] = [
            ("一早", 6),
            ("早上", 8), ("morning", 8),
            ("上午", 10),
            ("中午", 12), ("noon", 12),
            ("下午", 14), ("afternoon", 14),
            ("傍晚", 18),
            ("晚上", 20), ("evening", 20),
            ("深夜", 22), ("night", 22)
        ]
        for (kw, h) in periodDefaults {
            if let r = text.range(of: kw, options: .caseInsensitive) {
                text.removeSubrange(r)
                matched.append(kw)
                return TimeOfDay(hour: h, minute: 0)
            }
        }

        return nil
    }

    fileprivate static func parseChineseNumber(_ s: String) -> Int? {
        let single: [Character: Int] = [
            "零": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]
        let chars = Array(s)
        switch chars.count {
        case 1:
            if chars[0] == "十" { return 10 }
            if chars[0] == "百" { return 100 }
            return single[chars[0]]
        case 2:
            // 十X：1X
            if chars[0] == "十" {
                guard let v = single[chars[1]] else { return nil }
                return 10 + v
            }
            // X十：X0
            if chars[1] == "十" {
                guard let v = single[chars[0]] else { return nil }
                return v * 10
            }
            // X百：X00
            if chars[1] == "百" {
                guard let v = single[chars[0]] else { return nil }
                return v * 100
            }
            return nil
        case 3:
            // X十Y：XY
            if chars[1] == "十", let x = single[chars[0]], let y = single[chars[2]] {
                return x * 10 + y
            }
            // X百：X00
            if chars[1] == "百", let x = single[chars[0]] {
                return x * 100
            }
            // 一百Y → 10Y 这种简写不支持（语义模糊）
            return nil
        default:
            return nil
        }
    }
}

// MARK: - 6. 优先级

extension NlpParser {

    fileprivate static func extractPriority(from text: inout String,
                                            matched: inout [String]) -> Priority {
        let keywords: [(String, Priority)] = [
            ("紧急", .urgent), ("特急", .urgent), ("urgent", .urgent),
            ("立刻", .urgent), ("马上", .urgent), ("立即", .urgent),
            ("重要", .high), ("优先", .high), ("important", .high),
            ("high priority", .high), ("priority", .high),
            ("普通", .medium), ("一般", .medium), ("medium", .medium),
            ("不急", .low), ("随便", .low), ("简单", .low),
            ("次要", .low), ("minor", .low), ("low", .low)
        ]
        for (kw, p) in keywords {
            if let r = text.range(of: kw, options: .caseInsensitive) {
                text.removeSubrange(r)
                matched.append(kw)
                return p
            }
        }
        return .medium
    }
}

// MARK: - 7. 标签

extension NlpParser {

    fileprivate static let tagMappings: [(String, Tag)] = [
        ("工作", .work), ("work", .work),
        ("学习", .study), ("study", .study),
        ("运动", .exercise), ("exercise", .exercise),
        ("健康", .health), ("health", .health),
        ("爱好", .hobby), ("hobby", .hobby),
        ("社交", .social), ("social", .social),
        ("购物", .shopping), ("shopping", .shopping),
        ("清洁", .cleaning), ("cleaning", .cleaning),
        ("财务", .finance), ("finance", .finance),
        ("计划", .planning), ("planning", .planning),
        ("创意", .creative), ("creative", .creative),
        ("休息", .rest), ("rest", .rest),
        ("家庭", .family), ("family", .family),
        ("个人", .personal), ("personal", .personal)
    ]

    fileprivate static func extractTags(from text: String) -> [Tag] {
        var tags: [Tag] = []
        for (kw, tag) in tagMappings {
            if matchesStandalone(keyword: kw, in: text) && !tags.contains(tag) {
                tags.append(tag)
            }
        }
        return tags
    }

    private static func matchesStandalone(keyword: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: keyword)
        let pattern = "(?:^|[\\s,，.。、;；:：])\(escaped)(?:$|[\\s,，.。、;；:：])"
        return firstMatch(in: text, pattern: pattern) != nil
    }
}

// MARK: - 8. 任务名清理

extension NlpParser {

    fileprivate static func extractName(residual: String) -> String {
        var cleaned = residual.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) 砍掉条件 / 补充子句（"如果...", "假如...", "要是..."）
        if let r = cleaned.range(of: #"[,，。;；]?\s*(?:如果|假如|要是|否则|不然).*$"#,
                                  options: .regularExpression) {
            cleaned = String(cleaned[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2) 砍掉"再提醒(我)(一次)"等尾部短语
        cleaned = cleaned.replacingOccurrences(
            of: #"[,，。;；]?\s*再?提醒我?(?:一次)?\s*$"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let leadingFillers = [
            "提醒我做", "提醒我", "请提醒我",
            "记得做", "记得",
            "帮我", "替我",
            "我要", "我得", "我需要", "需要"
        ]
        var stripped = true
        while stripped {
            stripped = false
            for f in leadingFillers {
                if cleaned.hasPrefix(f) {
                    cleaned = String(cleaned.dropFirst(f.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    stripped = true
                    break
                }
            }
        }

        for (kw, _) in tagMappings {
            cleaned = removeStandaloneKeyword(kw, from: cleaned)
        }

        let trailingFillers = ["前", "时", "里"]
        for f in trailingFillers {
            let pat = "(^|[\\s,，.。])\(NSRegularExpression.escapedPattern(for: f))(?=$|[\\s,，.。])"
            if let regex = try? NSRegularExpression(pattern: pat) {
                let nsr = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: nsr, withTemplate: "$1")
            }
        }

        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"[,，。.、;；:：]+"#, with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // 3) 如果残余仍以逗号分隔多段（标点已清除但可能仍很长），取前 12 字以内的核心动词短语
        //   注意：上面 #"[,，。.、;；:：]+"# 替换为空字符串，所以这里其实没有标点了。
        //   仅当长度过长（>20 字）时，截断到第一个常见动词附近的合理位置作 fallback。
        if cleaned.count > 20 {
            // 取前 12 字（中文）作为最终展示标题；信息字段已经由其它提取器消费
            cleaned = String(cleaned.prefix(12))
        }

        return cleaned.isEmpty ? "新提醒" : cleaned
    }

    private static func removeStandaloneKeyword(_ kw: String, from text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: kw)
        let pattern = "(^|[\\s,,，.。、;；:：])\(escaped)(?=$|[\\s,，.。、;；:：])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let nsr = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: nsr, withTemplate: "$1")
    }
}

// MARK: - 9. 组合 dueDate

extension NlpParser {

    fileprivate static func composeDueDate(dateAnchor: DateAnchor?,
                                           timeOfDay: TimeOfDay?,
                                           ctx: ParseContext) -> Date? {
        let cal = ctx.calendar
        let now = ctx.referenceDate

        if let anchor = dateAnchor, anchor.isExactTime {
            return anchor.date
        }

        if let anchor = dateAnchor, let tod = timeOfDay {
            var comps = cal.dateComponents([.year, .month, .day], from: anchor.date)
            comps.hour = tod.hour
            comps.minute = tod.minute
            return cal.date(from: comps)
        }
        if let anchor = dateAnchor {
            var comps = cal.dateComponents([.year, .month, .day], from: anchor.date)
            comps.hour = 9
            comps.minute = 0
            return cal.date(from: comps)
        }
        if let tod = timeOfDay {
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = tod.hour
            comps.minute = tod.minute
            let candidate = cal.date(from: comps)!
            if candidate < now {
                return cal.date(byAdding: .day, value: 1, to: candidate)
            }
            return candidate
        }
        return nil
    }
}

// MARK: - 10. 置信度

extension NlpParser {

    fileprivate static func calculateConfidence(title: String,
                                                hasDate: Bool,
                                                hasTime: Bool,
                                                hasNotifyOffset: Bool,
                                                hasRepeatInterval: Bool,
                                                hasPriority: Bool,
                                                hasRecurring: Bool) -> Double {
        var conf = 0.3
        if title.count >= 2 && title != "新提醒" { conf += 0.2 }
        if hasDate { conf += 0.15 }
        if hasTime { conf += 0.15 }
        if hasNotifyOffset { conf += 0.08 }
        if hasRepeatInterval { conf += 0.07 }
        if hasPriority { conf += 0.05 }
        if hasRecurring { conf += 0.1 }
        return min(1.0, max(0.0, conf))
    }
}
