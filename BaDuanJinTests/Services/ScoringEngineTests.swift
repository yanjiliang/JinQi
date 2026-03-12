// ScoringEngineTests.swift
// 养生八段锦 iPad App - ScoringEngine 评分引擎单元测试

import XCTest
@testable import BaDuanJin

final class ScoringEngineTests: XCTestCase {

    // MARK: - movementWeights 常量测试

    /// 测试：8个动作的权重数组长度为8
    func test_movementWeights_countIsEight() {
        XCTAssertEqual(ScoringEngine.movementWeights.count, 8)
    }

    /// 测试：所有动作权重之和等于1.0
    func test_movementWeights_sumToOne() {
        let sum = ScoringEngine.movementWeights.reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }

    /// 测试：每个动作权重均为正数
    func test_movementWeights_allPositive() {
        for (i, w) in ScoringEngine.movementWeights.enumerated() {
            XCTAssertGreaterThan(w, 0, "第\(i)式权重应为正数")
        }
    }

    // MARK: - calculateTotalScore 测试

    /// 测试：8个满分得分，总分为100
    func test_calculateTotalScore_allMaxScores_returns100() {
        let scores = Array(repeating: 100.0, count: 8)
        let total = ScoringEngine.calculateTotalScore(movementScores: scores)
        XCTAssertEqual(total, 100.0, accuracy: 0.001)
    }

    /// 测试：8个零分，总分为0
    func test_calculateTotalScore_allZeroScores_returns0() {
        let scores = Array(repeating: 0.0, count: 8)
        let total = ScoringEngine.calculateTotalScore(movementScores: scores)
        XCTAssertEqual(total, 0.0, accuracy: 0.001)
    }

    /// 测试：空数组返回0
    func test_calculateTotalScore_emptyArray_returns0() {
        let total = ScoringEngine.calculateTotalScore(movementScores: [])
        XCTAssertEqual(total, 0.0, accuracy: 0.001)
    }

    /// 测试：只有前3个动作的分数（不足8个），按实际有的计算
    func test_calculateTotalScore_partialScores_usesAvailableWeights() {
        let scores = [100.0, 100.0, 100.0]
        let expected = ScoringEngine.movementWeights.prefix(3).reduce(0, +) * 100.0
        let total = ScoringEngine.calculateTotalScore(movementScores: scores)
        XCTAssertEqual(total, expected, accuracy: 0.001)
    }

    /// 测试：8个50分得分，总分为50
    func test_calculateTotalScore_allFiftyScores_returns50() {
        let scores = Array(repeating: 50.0, count: 8)
        let total = ScoringEngine.calculateTotalScore(movementScores: scores)
        XCTAssertEqual(total, 50.0, accuracy: 0.001)
    }

    /// 测试：加权计算的正确性（手动验证第一个动作满分的贡献）
    func test_calculateTotalScore_weightedCorrectly() {
        var scores = Array(repeating: 0.0, count: 8)
        scores[0] = 100.0
        let total = ScoringEngine.calculateTotalScore(movementScores: scores)
        XCTAssertEqual(total, ScoringEngine.movementWeights[0] * 100.0, accuracy: 0.001)
    }

    // MARK: - grade 测试

    /// 测试：100分 → 优秀
    func test_grade_score100_returnsExcellent() {
        XCTAssertEqual(ScoringEngine.grade(from: 100), "优秀")
    }

    /// 测试：90分（区间下限）→ 优秀
    func test_grade_score90_returnsExcellent() {
        XCTAssertEqual(ScoringEngine.grade(from: 90), "优秀")
    }

    /// 测试：89.9分 → 良好（不足90分）
    func test_grade_score89point9_returnsGood() {
        XCTAssertEqual(ScoringEngine.grade(from: 89.9), "良好")
    }

    /// 测试：75分（区间下限）→ 良好
    func test_grade_score75_returnsGood() {
        XCTAssertEqual(ScoringEngine.grade(from: 75), "良好")
    }

    /// 测试：74.9分 → 及格（不足75分）
    func test_grade_score74point9_returnsPass() {
        XCTAssertEqual(ScoringEngine.grade(from: 74.9), "及格")
    }

    /// 测试：60分（区间下限）→ 及格
    func test_grade_score60_returnsPass() {
        XCTAssertEqual(ScoringEngine.grade(from: 60), "及格")
    }

    /// 测试：59.9分 → 需加强
    func test_grade_score59point9_returnsNeedsWork() {
        XCTAssertEqual(ScoringEngine.grade(from: 59.9), "需加强")
    }

    /// 测试：0分 → 需加强
    func test_grade_score0_returnsNeedsWork() {
        XCTAssertEqual(ScoringEngine.grade(from: 0), "需加强")
    }

    // MARK: - comment 测试

    /// 测试：优秀对应正确评语
    func test_comment_excellent_returnsCorrectText() {
        XCTAssertEqual(ScoringEngine.comment(for: "优秀"), "动作非常标准，继续保持！")
    }

    /// 测试：良好对应正确评语
    func test_comment_good_returnsCorrectText() {
        XCTAssertEqual(ScoringEngine.comment(for: "良好"), "动作基本到位，细节上还可以更精准。")
    }

    /// 测试：及格对应正确评语
    func test_comment_pass_returnsCorrectText() {
        XCTAssertEqual(ScoringEngine.comment(for: "及格"), "整体框架对了，需要多加练习细节。")
    }

    /// 测试：需加强对应正确评语
    func test_comment_needsWork_returnsCorrectText() {
        XCTAssertEqual(ScoringEngine.comment(for: "需加强"), "八段锦需要慢慢体会，坚持练习会越来越好！")
    }

    /// 测试：未知等级返回默认评语（同"需加强"）
    func test_comment_unknownGrade_returnsDefaultText() {
        XCTAssertEqual(ScoringEngine.comment(for: ""), "八段锦需要慢慢体会，坚持练习会越来越好！")
    }

    // MARK: - gradeColorHex 测试

    /// 测试：优秀 → 金色
    func test_gradeColorHex_excellent_returnsGold() {
        XCTAssertEqual(ScoringEngine.gradeColorHex(for: "优秀"), "#FFD700")
    }

    /// 测试：良好 → 绿色
    func test_gradeColorHex_good_returnsGreen() {
        XCTAssertEqual(ScoringEngine.gradeColorHex(for: "良好"), "#4CAF50")
    }

    /// 测试：及格 → 蓝色
    func test_gradeColorHex_pass_returnsBlue() {
        XCTAssertEqual(ScoringEngine.gradeColorHex(for: "及格"), "#2196F3")
    }

    /// 测试：需加强 → 橙色
    func test_gradeColorHex_needsWork_returnsOrange() {
        XCTAssertEqual(ScoringEngine.gradeColorHex(for: "需加强"), "#FF9800")
    }

    // MARK: - movementScoreColorHex 测试

    /// 测试：85-100分段 → 绿色
    func test_movementScoreColorHex_85to100_returnsGreen() {
        XCTAssertEqual(ScoringEngine.movementScoreColorHex(for: 85), "#4CAF50")
        XCTAssertEqual(ScoringEngine.movementScoreColorHex(for: 100), "#4CAF50")
    }

    /// 测试：70-84分段 → 蓝色
    func test_movementScoreColorHex_70to84_returnsBlue() {
        XCTAssertEqual(ScoringEngine.movementScoreColorHex(for: 70), "#2196F3")
        XCTAssertEqual(ScoringEngine.movementScoreColorHex(for: 84), "#2196F3")
    }

    /// 测试：55-69分段 → 黄色
    func test_movementScoreColorHex_55to69_returnsYellow() {
        XCTAssertEqual(ScoringEngine.movementScoreColorHex(for: 55), "#FFC107")
        XCTAssertEqual(ScoringEngine.movementScoreColorHex(for: 69), "#FFC107")
    }

    /// 测试：54分以下 → 红色
    func test_movementScoreColorHex_below55_returnsRed() {
        XCTAssertEqual(ScoringEngine.movementScoreColorHex(for: 54), "#F44336")
        XCTAssertEqual(ScoringEngine.movementScoreColorHex(for: 0), "#F44336")
    }

    // MARK: - generateAdvice 测试

    /// 测试：所有动作得分高且无反馈时，建议列表为空
    func test_generateAdvice_allHighScoresNoFeedback_returnsEmpty() {
        let scores = Array(repeating: 95.0, count: 8)
        let feedbacks = Array(repeating: "", count: 8)
        let names = (0..<8).map { "第\($0+1)式" }
        let advice = ScoringEngine.generateAdvice(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
        XCTAssertTrue(advice.isEmpty)
    }

    /// 测试：有反馈时建议数量不超过2条
    func test_generateAdvice_withFeedback_returnsAtMostTwo() {
        let scores = [40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 85.0, 88.0]
        let feedbacks = (0..<8).map { "改进建议\($0)" }
        let names = (0..<8).map { "第\($0+1)式" }
        let advice = ScoringEngine.generateAdvice(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
        XCTAssertLessThanOrEqual(advice.count, 2)
    }

    /// 测试：选择分数最低的动作给出建议
    func test_generateAdvice_picksLowestScoringMovements() {
        let scores = [40.0, 50.0, 80.0, 80.0, 80.0, 80.0, 80.0, 80.0]
        let feedbacks = ["需改进A", "需改进B", "", "", "", "", "", ""]
        let names = (0..<8).map { "第\($0+1)式" }
        let advice = ScoringEngine.generateAdvice(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
        XCTAssertEqual(advice.count, 2)
        XCTAssertTrue(advice.contains { $0.body == "需改进A" }, "得分最低的第1式应包含在建议中")
        XCTAssertTrue(advice.contains { $0.body == "需改进B" }, "得分第二低的第2式应包含在建议中")
    }

    /// 测试：targetScore 等于当前分数+15
    func test_generateAdvice_targetScore_isCurrentPlusFifteen() {
        let scores = [70.0, 80.0, 80.0, 80.0, 80.0, 80.0, 80.0, 80.0]
        let feedbacks = ["需改进X", "", "", "", "", "", "", ""]
        let names = (0..<8).map { "第\($0+1)式" }
        let advice = ScoringEngine.generateAdvice(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
        XCTAssertEqual(advice.first?.targetScore ?? 0, 85.0, accuracy: 0.001)
    }

    /// 测试：targetScore 不超过100分
    func test_generateAdvice_targetScore_cappedAt100() {
        // 得分为90，+15=105，应上限到100
        let scores = [90.0, 95.0, 80.0, 80.0, 80.0, 80.0, 80.0, 80.0]
        let feedbacks = ["建议X", "建议Y", "", "", "", "", "", ""]
        let names = (0..<8).map { "第\($0+1)式" }
        let advice = ScoringEngine.generateAdvice(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
        for item in advice {
            XCTAssertLessThanOrEqual(item.targetScore, 100.0)
        }
    }

    /// 测试：建议的动作名称正确对应分数最低的动作
    func test_generateAdvice_movementName_matchesLowestScoring() {
        let scores = [30.0, 90.0, 90.0, 90.0, 90.0, 90.0, 90.0, 90.0]
        let feedbacks = ["需要加强第1式", "", "", "", "", "", "", ""]
        let names = ["双手托天理三焦", "左右开弓似射雕", "调理脾胃须单举", "五劳七伤往后瞧",
                     "摇头摆尾去心火", "两手攀足固肾腰", "攒拳怒目增气力", "背后七颠百病消"]
        let advice = ScoringEngine.generateAdvice(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
        XCTAssertEqual(advice.first?.movementName, "双手托天理三焦")
    }

    // MARK: - calculateResult 集成测试

    /// 测试：全部满分计算出优秀等级，正确评语
    func test_calculateResult_allExcellent_returnsExcellentGrade() {
        let scores = Array(repeating: 95.0, count: 8)
        let feedbacks = Array(repeating: "", count: 8)
        let names = (0..<8).map { "第\($0+1)式" }
        let result = ScoringEngine.calculateResult(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
        XCTAssertEqual(result.grade, "优秀")
        XCTAssertEqual(result.totalScore, 95.0, accuracy: 0.001)
        XCTAssertEqual(result.gradeComment, "动作非常标准，继续保持！")
    }

    /// 测试：结果包含所有8个动作的得分
    func test_calculateResult_returnsAllEightMovementScores() {
        let scores = (0..<8).map { Double($0) * 10 + 20 }
        let result = ScoringEngine.calculateResult(
            movementScores: scores,
            movementFeedbacks: Array(repeating: "", count: 8),
            movementNames: Array(repeating: "测试动作", count: 8)
        )
        XCTAssertEqual(result.movementScores.count, 8)
        for (i, score) in result.movementScores.enumerated() {
            XCTAssertEqual(score, scores[i], accuracy: 0.001)
        }
    }

    /// 测试：及格分数线（刚好60分）结果为及格
    func test_calculateResult_exactPassScore_returnsPass() {
        // 构造所有动作得分使总分刚好60
        // 所有动作给60分，权重之和=1 → 总分=60
        let scores = Array(repeating: 60.0, count: 8)
        let result = ScoringEngine.calculateResult(
            movementScores: scores,
            movementFeedbacks: Array(repeating: "", count: 8),
            movementNames: Array(repeating: "动作", count: 8)
        )
        XCTAssertEqual(result.grade, "及格")
    }

    /// 测试：calculateResult 的建议不超过2条
    func test_calculateResult_advice_atMostTwoItems() {
        let scores = [30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 85.0, 90.0]
        let feedbacks = (0..<8).map { "建议\($0)" }
        let names = (0..<8).map { "第\($0+1)式" }
        let result = ScoringEngine.calculateResult(
            movementScores: scores,
            movementFeedbacks: feedbacks,
            movementNames: names
        )
        XCTAssertLessThanOrEqual(result.advice.count, 2)
    }
}
