// PracticeSessionTests.swift
// 养生八段锦 iPad App - PracticeSession 和 UserStats 数据模型单元测试

import XCTest
import SwiftData
@testable import BaDuanJin

final class PracticeSessionTests: XCTestCase {

    // MARK: - SwiftData 内存容器

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: PracticeSession.self, MovementResult.self, UserStats.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - PracticeSession 初始化测试

    /// 测试：使用完整参数初始化时，所有字段正确存储
    func test_init_withValidParams_storesAllFields() {
        let id = UUID()
        let start = Date(timeIntervalSinceNow: -300)
        let end = Date()

        let session = PracticeSession(
            id: id,
            startTime: start,
            endTime: end,
            duration: 300,
            totalScore: 85.5,
            grade: "良好"
        )

        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.startTime, start)
        XCTAssertEqual(session.endTime, end)
        XCTAssertEqual(session.duration, 300)
        XCTAssertEqual(session.totalScore, 85.5)
        XCTAssertEqual(session.grade, "良好")
        XCTAssertTrue(session.movementResults.isEmpty)
    }

    /// 测试：省略 id 参数时，自动生成唯一 UUID
    func test_init_withoutId_generatesUniqueIds() {
        let s1 = PracticeSession(startTime: Date(), endTime: Date(), duration: 60, totalScore: 80, grade: "良好")
        let s2 = PracticeSession(startTime: Date(), endTime: Date(), duration: 60, totalScore: 80, grade: "良好")
        XCTAssertNotEqual(s1.id, s2.id)
    }

    // MARK: - formattedDuration 测试

    /// 测试：时长不足1分钟时，显示"0分X秒"
    func test_formattedDuration_lessThanOneMinute_showsZeroMinutes() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 45, totalScore: 80, grade: "良好")
        XCTAssertEqual(session.formattedDuration, "0分45秒")
    }

    /// 测试：整分钟时长，秒数显示为0
    func test_formattedDuration_exactMinutes_showsZeroSeconds() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 120, totalScore: 80, grade: "良好")
        XCTAssertEqual(session.formattedDuration, "2分0秒")
    }

    /// 测试：混合分钟和秒数的时长
    func test_formattedDuration_mixedMinutesAndSeconds_correctFormat() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 375, totalScore: 80, grade: "良好")
        XCTAssertEqual(session.formattedDuration, "6分15秒")
    }

    /// 测试：边界值0秒时长
    func test_formattedDuration_zeroDuration_returnsZeroMinZeroSec() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 0, totalScore: 80, grade: "良好")
        XCTAssertEqual(session.formattedDuration, "0分0秒")
    }

    // MARK: - gradeColorHex 测试

    /// 测试：优秀等级对应金色
    func test_gradeColorHex_excellent_returnsGold() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 60, totalScore: 95, grade: "优秀")
        XCTAssertEqual(session.gradeColorHex, "#FFD700")
    }

    /// 测试：良好等级对应绿色
    func test_gradeColorHex_good_returnsGreen() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 60, totalScore: 80, grade: "良好")
        XCTAssertEqual(session.gradeColorHex, "#4CAF50")
    }

    /// 测试：及格等级对应蓝色
    func test_gradeColorHex_pass_returnsBlue() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 60, totalScore: 65, grade: "及格")
        XCTAssertEqual(session.gradeColorHex, "#2196F3")
    }

    /// 测试：需加强等级对应橙色
    func test_gradeColorHex_needsWork_returnsOrange() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 60, totalScore: 40, grade: "需加强")
        XCTAssertEqual(session.gradeColorHex, "#FF9800")
    }

    /// 测试：未知等级返回默认橙色
    func test_gradeColorHex_unknownGrade_returnsOrange() {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 60, totalScore: 40, grade: "未知")
        XCTAssertEqual(session.gradeColorHex, "#FF9800")
    }

    // MARK: - dateOnly 测试

    /// 测试：dateOnly 返回当天零时
    func test_dateOnly_returnsStartOfDay() {
        let now = Date()
        let session = PracticeSession(startTime: now, endTime: now, duration: 60, totalScore: 80, grade: "良好")
        XCTAssertEqual(session.dateOnly, Calendar.current.startOfDay(for: now))
    }

    // MARK: - SwiftData 持久化测试

    /// 测试：插入后可以从内存容器中查询到记录
    func test_insertAndFetch_sessionPersistsInMemoryContainer() throws {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 300, totalScore: 90, grade: "优秀")
        context.insert(session)
        try context.save()

        let descriptor = FetchDescriptor<PracticeSession>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.grade, "优秀")
    }

    /// 测试：插入多条记录后全部可查询
    func test_insertMultiple_allFetched() throws {
        for i in 0..<5 {
            let s = PracticeSession(startTime: Date(), endTime: Date(), duration: Double(i * 60), totalScore: Double(i * 10), grade: "良好")
            context.insert(s)
        }
        try context.save()

        let descriptor = FetchDescriptor<PracticeSession>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 5)
    }

    // MARK: - UserStats 初始化测试

    /// 测试：默认初始化时所有统计字段为零
    func test_userStats_init_allFieldsAreZero() {
        let stats = UserStats()
        XCTAssertEqual(stats.totalSessionCount, 0)
        XCTAssertEqual(stats.totalDuration, 0)
        XCTAssertEqual(stats.currentStreak, 0)
        XCTAssertEqual(stats.longestStreak, 0)
        XCTAssertNil(stats.lastPracticeDate)
    }

    // MARK: - UserStats.updateAfterSession 测试

    /// 测试：首次练习后，次数+1、时长增加、连续打卡=1
    func test_updateAfterSession_firstSession_setsStreakToOne() {
        let stats = UserStats()
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 300, totalScore: 80, grade: "良好")
        stats.updateAfterSession(session)

        XCTAssertEqual(stats.totalSessionCount, 1)
        XCTAssertEqual(stats.totalDuration, 300)
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.longestStreak, 1)
        XCTAssertNotNil(stats.lastPracticeDate)
    }

    /// 测试：同一天第二次练习，连续打卡不重复计数
    func test_updateAfterSession_sameDay_streakNotIncremented() {
        let stats = UserStats()
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 300, totalScore: 80, grade: "良好")

        // 第一次练习
        stats.updateAfterSession(session)
        XCTAssertEqual(stats.currentStreak, 1)

        // 同天第二次练习
        stats.updateAfterSession(session)
        XCTAssertEqual(stats.currentStreak, 1, "同天重复练习不应增加连续打卡数")
        XCTAssertEqual(stats.totalSessionCount, 2, "次数应累加")
    }

    /// 测试：连续两天练习，连续打卡递增
    func test_updateAfterSession_consecutiveDays_streakIncremented() {
        let stats = UserStats()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // 模拟昨天练习过
        stats.lastPracticeDate = yesterday
        stats.currentStreak = 1
        stats.longestStreak = 1

        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 200, totalScore: 75, grade: "良好")
        stats.updateAfterSession(session)

        XCTAssertEqual(stats.currentStreak, 2, "连续第二天练习，连续打卡应+1")
        XCTAssertEqual(stats.longestStreak, 2)
    }

    /// 测试：中断后重新开始，连续打卡重置为1
    func test_updateAfterSession_afterBreak_streakResetsToOne() {
        let stats = UserStats()
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!

        // 模拟3天前练习过
        stats.lastPracticeDate = calendar.startOfDay(for: threeDaysAgo)
        stats.currentStreak = 5
        stats.longestStreak = 5

        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 300, totalScore: 80, grade: "良好")
        stats.updateAfterSession(session)

        XCTAssertEqual(stats.currentStreak, 1, "中断后重新开始，连续打卡应重置为1")
        XCTAssertEqual(stats.longestStreak, 5, "历史最长记录不应减少")
    }

    /// 测试：longestStreak 始终跟踪历史最大值
    func test_updateAfterSession_longestStreak_tracksMaximum() {
        let stats = UserStats()
        let calendar = Calendar.current

        // 模拟打了3天后断了，重新开始
        stats.lastPracticeDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        stats.currentStreak = 3
        stats.longestStreak = 3

        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 300, totalScore: 80, grade: "良好")
        stats.updateAfterSession(session)

        XCTAssertEqual(stats.currentStreak, 4)
        XCTAssertEqual(stats.longestStreak, 4, "新的最长记录应更新")
    }

    // MARK: - UserStats.formattedTotalDuration 测试

    /// 测试：不足1小时时显示分钟
    func test_formattedTotalDuration_lessThanOneHour_showsMinutes() {
        let stats = UserStats()
        stats.totalDuration = 45 * 60  // 45分钟

        XCTAssertEqual(stats.formattedTotalDuration, "45分钟")
    }

    /// 测试：超过1小时时显示小时和分钟
    func test_formattedTotalDuration_moreThanOneHour_showsHoursAndMinutes() {
        let stats = UserStats()
        stats.totalDuration = 90 * 60  // 1小时30分

        XCTAssertEqual(stats.formattedTotalDuration, "1小时30分")
    }

    /// 测试：整小时时分钟显示为0
    func test_formattedTotalDuration_exactHours_showsZeroMinutes() {
        let stats = UserStats()
        stats.totalDuration = 2 * 3600  // 2小时

        XCTAssertEqual(stats.formattedTotalDuration, "2小时0分")
    }
}
