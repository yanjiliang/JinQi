// ReportView.swift
// 养生八段锦 iPad App - 练习报告视图

import SwiftUI
import SwiftData

/// 单次练习完整报告（可从历史记录导航进入）
struct ReportView: View {
    let session: PracticeSession
    @Environment(\.dismiss) private var dismiss

    // 按动作序号排序的结果
    private var sortedResults: [MovementResult] {
        session.movementResults.sorted { $0.movementIndex < $1.movementIndex }
    }

    // 得分最高的动作
    private var bestMovement: MovementResult? {
        session.movementResults.max(by: { $0.score < $1.score })
    }

    // 改进建议（得分最低的2个有反馈的动作）
    private var improvements: [MovementResult] {
        session.movementResults
            .filter { !$0.feedback.isEmpty }
            .sorted { $0.score < $1.score }
            .prefix(2)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 总评分头部
                    reportHeader

                    // 各动作评分
                    movementScoresSection

                    // 本次亮点
                    if let best = bestMovement {
                        highlightSection(best: best)
                    }

                    // 改进建议
                    if !improvements.isEmpty {
                        improvementsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("练习报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    // MARK: - 报告头部
    private var reportHeader: some View {
        VStack(spacing: 14) {
            Text("本次练习报告")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            Text(session.totalScore.scoreString)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: session.gradeColorHex))

            Text(session.grade)
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(hex: session.gradeColorHex).opacity(0.15))
                .foregroundColor(Color(hex: session.gradeColorHex))
                .cornerRadius(12)

            Text(ScoringEngine.comment(for: session.grade))
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                Label(session.startTime.fullDateString, systemImage: "calendar")
                Label(session.formattedDuration, systemImage: "clock")
            }
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
    }

    // MARK: - 各动作评分区
    private var movementScoresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("各动作评分")
                .font(.system(size: 20, weight: .bold))

            ForEach(sortedResults, id: \.id) { result in
                HStack(spacing: 12) {
                    Text("第\(result.movementIndex + 1)式")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(width: 40)

                    Text(result.movementName)
                        .font(.system(size: 15))
                        .frame(width: 120, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: ScoringEngine.movementScoreColorHex(for: result.score)))
                                .frame(width: geo.size.width * result.score / 100)
                        }
                    }
                    .frame(height: 10)

                    Text("\(result.score.scoreString)分")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: ScoringEngine.movementScoreColorHex(for: result.score)))
                        .frame(width: 48, alignment: .trailing)
                }
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - 亮点区
    private func highlightSection(best: MovementResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本次亮点")
                .font(.system(size: 20, weight: .bold))

            HStack(spacing: 14) {
                Text("🌟")
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 4) {
                    Text("最佳动作：第\(best.movementIndex + 1)式 \(best.movementName)")
                        .font(.system(size: 16, weight: .medium))
                    Text("\(best.score.scoreString)分")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: ScoringEngine.movementScoreColorHex(for: best.score)))
                }
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - 改进建议区
    private var improvementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("改进建议")
                .font(.system(size: 20, weight: .bold))

            ForEach(Array(improvements.enumerated()), id: \.offset) { index, result in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.orange)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("第\(result.movementIndex + 1)式 \(result.movementName)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(result.feedback)
                            .font(.system(size: 16))
                        Text("努力提升到 \(min(100, result.score + 15).scoreString) 分 💪")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(20)
        .cardStyle()
    }
}
