// ScoringEngine.swift
// 养生八段锦 iPad App - 评分引擎

import Foundation

// MARK: - 整体练习评分
struct PracticeScoreResult {
    let totalScore: Double          // 总评分（0-100）
    let grade: String               // 等级
    let gradeComment: String        // 等级评语
    let movementScores: [Double]    // 各动作得分（0-7序号对应）
    let advice: [ImprovementAdvice] // 改进建议（最多2条）
}

// MARK: - 改进建议
struct ImprovementAdvice {
    let movementName: String   // 涉及的动作
    let body: String           // 建议文案
    let targetScore: Double    // 提升后的预估分数（激励性）
}

// MARK: - 评分引擎
enum ScoringEngine {
    // MARK: - 各动作权重（难度不同）
    static let movementWeights: [Double] = [0.10, 0.15, 0.12, 0.10, 0.15, 0.12, 0.13, 0.13]

    // MARK: - 计算总评分
    static func calculateTotalScore(movementScores: [Double]) -> Double {
        guard movementScores.count == 8 else {
            // 不足8个动作，按实际有的动作计算
            let available = min(movementScores.count, 8)
            guard available > 0 else { return 0 }
            return zip(movementScores.prefix(available),
                       movementWeights.prefix(available)).map(*).reduce(0, +)
        }
        let result = zip(movementScores, movementWeights).map(*).reduce(0, +)
        // 防止 NaN/Inf
        return result.isNaN || result.isInfinite ? 0 : result
    }

    // MARK: - 等级划分
    static func grade(from score: Double) -> String {
        switch score {
        case 90...100: return "优秀"
        case 75..<90:  return "良好"
        case 60..<75:  return "及格"
        default:       return "需加强"
        }
    }

    // MARK: - 等级评语
    static func comment(for grade: String) -> String {
        switch grade {
        case "优秀":  return "动作非常标准，继续保持！"
        case "良好":  return "动作基本到位，细节上还可以更精准。"
        case "及格":  return "整体框架对了，需要多加练习细节。"
        default:     return "八段锦需要慢慢体会，坚持练习会越来越好！"
        }
    }

    // MARK: - 等级颜色（十六进制字符串）
    static func gradeColorHex(for grade: String) -> String {
        switch grade {
        case "优秀":  return "#FFD700"
        case "良好":  return "#4CAF50"
        case "及格":  return "#2196F3"
        default:     return "#FF9800"
        }
    }

    // MARK: - 动作评分进度条颜色
    static func movementScoreColorHex(for score: Double) -> String {
        switch score {
        case 85...100: return "#4CAF50"
        case 70..<85:  return "#2196F3"
        case 55..<70:  return "#FFC107"
        default:       return "#F44336"
        }
    }

    // MARK: - 生成改进建议（最多2条）
    static func generateAdvice(
        movementScores: [Double],
        movementFeedbacks: [String],
        movementNames: [String]
    ) -> [ImprovementAdvice] {
        // 构建动作评分列表并按分数排序
        let indexed = movementScores.enumerated().map { (index: $0, score: $1) }
        let sorted = indexed.sorted { $0.score < $1.score }

        return sorted.prefix(2).compactMap { item in
            let feedback = item.index < movementFeedbacks.count ? movementFeedbacks[item.index] : ""
            guard !feedback.isEmpty else { return nil }

            let name = item.index < movementNames.count ? movementNames[item.index] : "第\(item.index + 1)式"
            return ImprovementAdvice(
                movementName: name,
                body: feedback,
                targetScore: min(100, item.score + 15)
            )
        }
    }

    // MARK: - 综合计算完整报告
    static func calculateResult(
        movementScores: [Double],
        movementFeedbacks: [String],
        movementNames: [String]
    ) -> PracticeScoreResult {
        let total = calculateTotalScore(movementScores: movementScores)
        let g = grade(from: total)
        let advice = generateAdvice(
            movementScores: movementScores,
            movementFeedbacks: movementFeedbacks,
            movementNames: movementNames
        )

        return PracticeScoreResult(
            totalScore: total,
            grade: g,
            gradeComment: comment(for: g),
            movementScores: movementScores,
            advice: advice
        )
    }
}
