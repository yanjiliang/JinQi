// UserStats.swift
// 养生八段锦 iPad App - 用户统计缓存模型（单例）

import SwiftData
import Foundation

/// 用户累计统计数据（单例，key="default"）
/// 用于缓存统计数据，避免每次打开首页全表扫描
@Model
final class UserStats {
    // MARK: - 单例标识
    @Attribute(.unique) var key: String = "default"

    // MARK: - 累计统计
    var totalSessionCount: Int      // 总练习次数
    var totalDuration: TimeInterval // 累计练习时长（秒）

    // MARK: - 连续打卡
    var currentStreak: Int          // 当前连续打卡天数
    var longestStreak: Int          // 历史最长连续打卡天数
    var lastPracticeDate: Date?     // 最后一次练习日期（取日期部分）

    // MARK: - 初始化
    init() {
        self.totalSessionCount = 0
        self.totalDuration = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastPracticeDate = nil
    }

    // MARK: - 更新方法（在保存 PracticeSession 后调用）
    func updateAfterSession(_ session: PracticeSession) {
        totalSessionCount += 1
        totalDuration += session.duration

        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        if let last = lastPracticeDate {
            if Calendar.current.isDate(last, inSameDayAs: yesterday) {
                // 昨天练习过，连续打卡+1
                currentStreak += 1
            } else if Calendar.current.isDate(last, inSameDayAs: today) {
                // 今日重复练习，不重复计数
            } else {
                // 中断后重新开始
                currentStreak = 1
            }
        } else {
            // 首次练习
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastPracticeDate = today
    }

    // MARK: - 格式化累计时长
    var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        } else {
            return "\(minutes)分钟"
        }
    }
}
