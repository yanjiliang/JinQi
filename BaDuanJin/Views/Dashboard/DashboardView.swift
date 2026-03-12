// DashboardView.swift
// 养生八段锦 iPad App - 首页仪表盘

import SwiftUI
import SwiftData

/// 首页仪表盘
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showingPractice = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 快速开始区
                    quickStartSection

                    // 今日统计
                    todayStatsSection

                    // 打卡日历
                    calendarSection

                    // 最近练习记录
                    if !viewModel.recentSessions.isEmpty {
                        recentSessionsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("锦气")
            .onAppear { viewModel.loadData(context: modelContext) }
        }
    }

    // MARK: - 快速开始区
    private var quickStartSection: some View {
        ZStack(alignment: .leading) {
            LinearGradient(
                colors: [Color(hex: "#1B5E20"), Color(hex: "#4CAF50")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.isPracticedToday ? "今日已完成练习 ✓" : "今日尚未练习")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.85))

                    Text("开始练习")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Button(action: { showingPractice = true }) {
                        Label("立即开始", systemImage: "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .foregroundColor(Color(hex: "#1B5E20"))
                            .cornerRadius(20)
                    }
                }

                Spacer()

                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(24)
        }
        .cornerRadius(20)
        .frame(height: 160)
    }

    // MARK: - 今日统计
    private var todayStatsSection: some View {
        HStack(spacing: 16) {
            StatCard(title: "总练习", value: viewModel.totalSessionsText, icon: "trophy.fill", color: .orange)
            StatCard(title: "连续打卡", value: viewModel.currentStreakText, icon: "flame.fill", color: .red)
            StatCard(title: "累计时长", value: viewModel.totalDurationText, icon: "clock.fill", color: .blue)
        }
    }

    // MARK: - 打卡日历
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("打卡日历")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                // 月份切换
                HStack(spacing: 8) {
                    Button(action: { changeMonth(-1) }) {
                        Image(systemName: "chevron.left")
                    }
                    Text(calendarMonthText)
                        .font(.system(size: 15, weight: .medium))
                    Button(action: { changeMonth(1) }) {
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundColor(.secondary)
            }

            CalendarGridView(
                month: viewModel.calendarMonth,
                practicedDates: viewModel.practicedDatesThisMonth
            )
        }
        .padding(20)
        .cardStyle()
    }

    private var calendarMonthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: viewModel.calendarMonth)
    }

    private func changeMonth(_ delta: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: viewModel.calendarMonth) {
            viewModel.calendarMonth = newMonth
            viewModel.loadMonthPracticeDates(context: modelContext, month: newMonth)
        }
    }

    // MARK: - 最近练习记录
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近练习")
                .font(.system(size: 20, weight: .bold))

            ForEach(viewModel.recentSessions) { session in
                RecentSessionRow(session: session)
            }
        }
        .padding(20)
        .cardStyle()
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .cardStyle()
    }
}

// MARK: - 打卡日历网格
struct CalendarGridView: View {
    let month: Date
    let practicedDates: Set<Date>

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            // 星期标题
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // 空白填充
            ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                Color.clear.frame(height: 36)
            }

            // 日期格子
            ForEach(1...daysInMonth, id: \.self) { day in
                let date = dateFor(day: day)
                let isPracticed = practicedDates.contains(date)
                let isToday = calendar.isDateInToday(date)

                ZStack {
                    if isPracticed {
                        Circle().fill(Color.green)
                    } else if isToday {
                        Circle().stroke(Color.green, lineWidth: 2)
                    }

                    Text("\(day)")
                        .font(.system(size: 14, weight: isPracticed || isToday ? .bold : .regular))
                        .foregroundColor(isPracticed ? .white : (isToday ? .green : .primary))
                }
                .frame(height: 36)
            }
        }
    }

    private var firstWeekdayOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private var daysInMonth: Int {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return 30 }
        return range.count
    }

    private func dateFor(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = day
        return calendar.startOfDay(for: calendar.date(from: components) ?? Date())
    }
}

// MARK: - 最近练习行
struct RecentSessionRow: View {
    let session: PracticeSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startTime.shortDateString + " " + session.startTime.timeString)
                    .font(.system(size: 15, weight: .medium))
                Text(session.formattedDuration)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.totalScore.scoreString)分")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: session.gradeColorHex))
                Text(session.grade)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: session.gradeColorHex))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [PracticeSession.self, MovementResult.self, UserStats.self], inMemory: true)
}
