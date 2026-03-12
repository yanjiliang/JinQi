// PracticeCompletionView.swift
// 养生八段锦 iPad App - 练习完成页（评分总览）

import SwiftUI

/// 全套练习完成后的评分概览页
struct PracticeCompletionView: View {
    let result: PracticeScoreResult
    let onDismiss: () -> Void
    @State private var navigateToReport = false

    private let movementNames: [String] = MovementLibrary.shared.movements.map { $0.name }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // 总评分区
                    scoreHeaderSection

                    // 各动作评分条形图
                    movementScoreSection

                    // 改进建议
                    if !result.advice.isEmpty {
                        adviceSection
                    }

                    // 操作按钮
                    actionButtonsSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .navigationTitle("练习完成")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 总评分头部
    private var scoreHeaderSection: some View {
        VStack(spacing: 16) {
            // 大字总分
            Text(result.totalScore.scoreString)
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: result.grade == "优秀" ? "#FFD700" :
                                              result.grade == "良好" ? "#4CAF50" :
                                              result.grade == "及格" ? "#2196F3" : "#FF9800"))

            // 等级标签
            Text(result.grade)
                .font(.system(size: 22, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(Color(hex: ScoringEngine.gradeColorHex(for: result.grade)).opacity(0.2))
                .foregroundColor(Color(hex: ScoringEngine.gradeColorHex(for: result.grade)))
                .cornerRadius(12)

            // 评语
            Text(result.gradeComment)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
    }

    // MARK: - 各动作评分
    private var movementScoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("各动作评分")
                .font(.system(size: 20, weight: .bold))

            ForEach(0..<min(result.movementScores.count, 8), id: \.self) { index in
                let score = result.movementScores[index]
                let name = index < movementNames.count ? movementNames[index] : "第\(index+1)式"

                HStack(spacing: 12) {
                    // 动作名称
                    Text("第\(index+1)式 \(name)")
                        .font(.system(size: 15))
                        .frame(width: 160, alignment: .leading)
                        .lineLimit(1)

                    // 评分条
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: ScoringEngine.movementScoreColorHex(for: score)))
                                .frame(width: geo.size.width * score / 100)
                        }
                    }
                    .frame(height: 10)

                    // 分数
                    Text("\(score.scoreString)分")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 48, alignment: .trailing)
                }
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - 改进建议
    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("改进建议")
                .font(.system(size: 20, weight: .bold))

            ForEach(Array(result.advice.enumerated()), id: \.offset) { index, advice in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.green)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(advice.movementName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(advice.body)
                            .font(.system(size: 16))
                    }
                }
            }
        }
        .padding(20)
        .cardStyle()
    }

    // MARK: - 操作按钮
    private var actionButtonsSection: some View {
        VStack(spacing: 14) {
            // 主按钮：再练一次
            Button(action: { onDismiss() }) {
                Label("再练一次", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }

            // 次要按钮：返回首页
            Button(action: { onDismiss() }) {
                Text("返回首页")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    PracticeCompletionView(
        result: PracticeScoreResult(
            totalScore: 82,
            grade: "良好",
            gradeComment: "动作基本到位，细节上还可以更精准。",
            movementScores: [85, 78, 90, 70, 65, 88, 75, 92],
            advice: [
                ImprovementAdvice(movementName: "摇头摆尾去心火",
                                  body: "马步要更低，膝盖弯曲角度约90°，重心下沉",
                                  targetScore: 80)
            ]
        ),
        onDismiss: {}
    )
}
