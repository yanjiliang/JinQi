// HistoryView.swift
// 养生八段锦 iPad App - 练习历史记录页

import SwiftUI
import SwiftData

/// 练习历史记录页
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedSession: PracticeSession?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("练习记录")
            .onAppear { viewModel.loadSessions(context: modelContext) }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
    }

    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 70))
                .foregroundColor(.secondary.opacity(0.5))
            Text("还没有练习记录")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.secondary)
            Text("完成一次练习后，记录将显示在这里")
                .font(.system(size: 16))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }

    // MARK: - 记录列表（按日期分组）
    private var sessionListView: some View {
        List {
            ForEach(viewModel.sessionsByDate, id: \.key) { dateKey, sessions in
                Section(header: Text(dateKey).font(.system(size: 15, weight: .medium))) {
                    ForEach(sessions) { session in
                        SessionRowView(session: session)
                            .onTapGesture { selectedSession = session }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.deleteSession(session, context: modelContext)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - 记录行视图
struct SessionRowView: View {
    let session: PracticeSession

    var body: some View {
        HStack {
            // 左侧：时间
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startTime.timeString)
                    .font(.system(size: 17, weight: .medium))
                Text(session.formattedDuration)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 右侧：评分
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(session.totalScore.scoreString)分")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: session.gradeColorHex))

                Text(session.grade)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(hex: session.gradeColorHex).opacity(0.15))
                    .foregroundColor(Color(hex: session.gradeColorHex))
                    .cornerRadius(8)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 单次练习详情（Sheet）
struct SessionDetailView: View {
    let session: PracticeSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 评分头部
                    VStack(spacing: 12) {
                        Text(session.totalScore.scoreString)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: session.gradeColorHex))

                        Text(session.grade)
                            .font(.system(size: 18, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(hex: session.gradeColorHex).opacity(0.15))
                            .foregroundColor(Color(hex: session.gradeColorHex))
                            .cornerRadius(10)

                        HStack(spacing: 20) {
                            Label(session.startTime.shortDateString, systemImage: "calendar")
                            Label(session.formattedDuration, systemImage: "clock")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .cardStyle()

                    // 各动作评分
                    if !session.movementResults.isEmpty {
                        let sorted = session.movementResults.sorted { $0.movementIndex < $1.movementIndex }
                        VStack(alignment: .leading, spacing: 14) {
                            Text("各动作评分")
                                .font(.system(size: 18, weight: .bold))

                            ForEach(sorted, id: \.id) { result in
                                MovementResultRow(result: result)
                            }
                        }
                        .padding(20)
                        .cardStyle()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("练习详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 动作结果行
struct MovementResultRow: View {
    let result: MovementResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("第\(result.movementIndex + 1)式 \(result.movementName)")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Text("\(result.score.scoreString)分")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: ScoringEngine.movementScoreColorHex(for: result.score)))
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: ScoringEngine.movementScoreColorHex(for: result.score)))
                        .frame(width: geo.size.width * result.score / 100)
                }
            }
            .frame(height: 6)

            if !result.feedback.isEmpty {
                Text(result.feedback)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [PracticeSession.self, MovementResult.self, UserStats.self], inMemory: true)
}
