// HistoryViewModel.swift
// 养生八段锦 iPad App - 练习记录 ViewModel

import SwiftUI
import SwiftData

@MainActor
class HistoryViewModel: ObservableObject {
    // MARK: - 发布属性
    @Published var sessions: [PracticeSession] = []
    @Published var selectedSession: PracticeSession?
    @Published var showDeleteAlert: Bool = false

    // MARK: - 加载所有历史记录（按时间倒序）
    func loadSessions(context: ModelContext) {
        let descriptor = FetchDescriptor<PracticeSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        sessions = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 删除记录
    func deleteSession(_ session: PracticeSession, context: ModelContext) {
        // MovementResult 因 cascade 自动删除
        context.delete(session)
        recalculateUserStats(context: context)
        try? context.save()
        loadSessions(context: context)
    }

    // MARK: - 删除后重新计算统计（连续打卡天数可能受影响）
    private func recalculateUserStats(context: ModelContext) {
        let statsDescriptor = FetchDescriptor<UserStats>()
        guard let stats = try? context.fetch(statsDescriptor).first else { return }

        let sessionDescriptor = FetchDescriptor<PracticeSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let allSessions = (try? context.fetch(sessionDescriptor)) ?? []

        // 重置统计
        stats.totalSessionCount = allSessions.count
        stats.totalDuration = allSessions.reduce(0) { $0 + $1.duration }

        // 重新计算连续打卡天数
        let calendar = Calendar.current
        var practiceDates = Set(allSessions.map { calendar.startOfDay(for: $0.startTime) })
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while practiceDates.contains(checkDate) {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        stats.currentStreak = streak
        stats.lastPracticeDate = allSessions.first.map { calendar.startOfDay(for: $0.startTime) }
    }

    // MARK: - 按日期分组
    var sessionsByDate: [(key: String, value: [PracticeSession])] {
        let grouped = Dictionary(grouping: sessions) { session in
            session.startTime.fullDateString
        }
        return grouped.sorted { $0.key > $1.key }
    }
}
