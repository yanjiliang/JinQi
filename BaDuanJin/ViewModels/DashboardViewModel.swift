// DashboardViewModel.swift
// 养生八段锦 iPad App - 首页仪表盘 ViewModel

import SwiftUI
import SwiftData

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - 发布属性
    @Published var stats: UserStats?
    @Published var recentSessions: [PracticeSession] = []
    @Published var practicedDatesThisMonth: Set<Date> = []

    // MARK: - 当前月份（打卡日历）
    @Published var calendarMonth: Date = Date()

    // MARK: - 加载数据
    func loadData(context: ModelContext) {
        loadStats(context: context)
        loadRecentSessions(context: context)
        loadMonthPracticeDates(context: context, month: calendarMonth)
    }

    // MARK: - 加载用户统计
    private func loadStats(context: ModelContext) {
        let descriptor = FetchDescriptor<UserStats>()
        stats = try? context.fetch(descriptor).first
    }

    // MARK: - 加载最近3次练习记录
    private func loadRecentSessions(context: ModelContext) {
        var descriptor = FetchDescriptor<PracticeSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        recentSessions = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 加载本月打卡日期
    func loadMonthPracticeDates(context: ModelContext, month: Date) {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return
        }

        let descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate { session in
                session.startTime >= startOfMonth && session.startTime < endOfMonth
            }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        practicedDatesThisMonth = Set(sessions.map { calendar.startOfDay(for: $0.startTime) })
    }

    // MARK: - 今日是否已练习
    var isPracticedToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return practicedDatesThisMonth.contains(today)
    }

    // MARK: - 格式化统计数据
    var totalSessionsText: String {
        "\(stats?.totalSessionCount ?? 0)次"
    }

    var currentStreakText: String {
        "\(stats?.currentStreak ?? 0)天"
    }

    var totalDurationText: String {
        stats?.formattedTotalDuration ?? "0分钟"
    }
}
