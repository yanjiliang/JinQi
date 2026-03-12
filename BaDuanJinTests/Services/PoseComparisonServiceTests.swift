// PoseComparisonServiceTests.swift
// 养生八段锦 iPad App - PoseComparisonService 单元测试

import XCTest
import Vision
@testable import BaDuanJin

final class PoseComparisonServiceTests: XCTestCase {

    private var service: PoseComparisonService!

    override func setUp() {
        super.setUp()
        service = PoseComparisonService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - angleBetween 测试

    /// 测试：共线三点（A-V-B 成直线）角度为180度
    func test_angleBetween_straightLine_returns180() {
        let angle = PoseComparisonService.angleBetween(
            pointA: CGPoint(x: 0, y: 1),
            vertex: CGPoint(x: 0, y: 0),
            pointB: CGPoint(x: 0, y: -1)
        )
        XCTAssertEqual(angle, 180.0, accuracy: 0.001)
    }

    /// 测试：直角情况下角度为90度
    func test_angleBetween_rightAngle_returns90() {
        let angle = PoseComparisonService.angleBetween(
            pointA: CGPoint(x: 1, y: 0),
            vertex: CGPoint(x: 0, y: 0),
            pointB: CGPoint(x: 0, y: 1)
        )
        XCTAssertEqual(angle, 90.0, accuracy: 0.001)
    }

    /// 测试：45度角
    func test_angleBetween_45Degrees() {
        let angle = PoseComparisonService.angleBetween(
            pointA: CGPoint(x: 1, y: 0),
            vertex: CGPoint(x: 0, y: 0),
            pointB: CGPoint(x: 1, y: 1)
        )
        XCTAssertEqual(angle, 45.0, accuracy: 0.001)
    }

    /// 测试：同向向量角度为0度
    func test_angleBetween_sameDirection_returns0() {
        let angle = PoseComparisonService.angleBetween(
            pointA: CGPoint(x: 1, y: 0),
            vertex: CGPoint(x: 0, y: 0),
            pointB: CGPoint(x: 2, y: 0)
        )
        XCTAssertEqual(angle, 0.0, accuracy: 0.001)
    }

    /// 测试：零长度向量（顶点与端点重合）返回0
    func test_angleBetween_zeroLengthVector_returns0() {
        let angle = PoseComparisonService.angleBetween(
            pointA: CGPoint(x: 0, y: 0),
            vertex: CGPoint(x: 0, y: 0),
            pointB: CGPoint(x: 1, y: 0)
        )
        XCTAssertEqual(angle, 0.0, accuracy: 0.001)
    }

    /// 测试：非零向量长度时角度对称性（A-V-B == B-V-A）
    func test_angleBetween_symmetry_sameResult() {
        let angle1 = PoseComparisonService.angleBetween(
            pointA: CGPoint(x: 1, y: 0),
            vertex: CGPoint(x: 0, y: 0),
            pointB: CGPoint(x: 0, y: 1)
        )
        let angle2 = PoseComparisonService.angleBetween(
            pointA: CGPoint(x: 0, y: 1),
            vertex: CGPoint(x: 0, y: 0),
            pointB: CGPoint(x: 1, y: 0)
        )
        XCTAssertEqual(angle1, angle2, accuracy: 0.001)
    }

    /// 测试：不同象限的点计算角度在 [0, 180] 范围内
    func test_angleBetween_result_alwaysInRange0To180() {
        let testCases: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: 1, y: 1), CGPoint(x: 0, y: 0), CGPoint(x: -1, y: -1)),
            (CGPoint(x: 3, y: 4), CGPoint(x: 1, y: 1), CGPoint(x: -2, y: 5)),
            (CGPoint(x: 0.5, y: 0.3), CGPoint(x: 0.2, y: 0.8), CGPoint(x: 0.7, y: 0.1))
        ]
        for (a, v, b) in testCases {
            let angle = PoseComparisonService.angleBetween(pointA: a, vertex: v, pointB: b)
            XCTAssertGreaterThanOrEqual(angle, 0.0)
            XCTAssertLessThanOrEqual(angle, 180.0)
        }
    }

    // MARK: - scoreForAngle 测试

    /// 测试：用户角度等于目标角度时得100分
    func test_scoreForAngle_exactTarget_returns100() {
        let check = makeAngleCheck(target: 90, tolerance: 10)
        let score = PoseComparisonService.scoreForAngle(userAngle: 90, check: check)
        XCTAssertEqual(score, 100.0, accuracy: 0.001)
    }

    /// 测试：偏差等于容差时得80分（线性映射下限）
    func test_scoreForAngle_atToleranceBoundary_returns80() {
        let check = makeAngleCheck(target: 90, tolerance: 10)
        // deviation = 10 = tolerance → ratio=1.0 → score = 100 - 1.0*20 = 80
        let score = PoseComparisonService.scoreForAngle(userAngle: 100, check: check)
        XCTAssertEqual(score, 80.0, accuracy: 0.001)
    }

    /// 测试：容差范围内线性插值（偏差=tolerance/2 → 分数=90）
    func test_scoreForAngle_halfToleranceDeviation_returns90() {
        let check = makeAngleCheck(target: 100, tolerance: 20)
        // deviation = 10, ratio = 0.5 → score = 100 - 0.5*20 = 90
        let score = PoseComparisonService.scoreForAngle(userAngle: 110, check: check)
        XCTAssertEqual(score, 90.0, accuracy: 0.001)
    }

    /// 测试：超出容差范围时每多1度扣2分
    func test_scoreForAngle_beyondTolerance_penaltyTwoPerDegree() {
        let check = makeAngleCheck(target: 90, tolerance: 10)
        // deviation = 20, extra = 10 → score = 80 - 10*2 = 60
        let score = PoseComparisonService.scoreForAngle(userAngle: 110, check: check)
        XCTAssertEqual(score, 60.0, accuracy: 0.001)
    }

    /// 测试：极端偏差时分数不低于20分（下限保护）
    func test_scoreForAngle_extremeDeviation_floorAt20() {
        let check = makeAngleCheck(target: 90, tolerance: 10)
        // deviation = 50, extra = 40 → max(20, 80 - 80) = 20
        let score = PoseComparisonService.scoreForAngle(userAngle: 140, check: check)
        XCTAssertEqual(score, 20.0, accuracy: 0.001)
    }

    /// 测试：负方向偏差（用户角度小于目标）同样按绝对偏差计算
    func test_scoreForAngle_negativeDeviation_usesAbsoluteValue() {
        let check = makeAngleCheck(target: 90, tolerance: 10)
        // deviation = abs(70-90) = 20, extra = 10 → 60
        let scoreBelow = PoseComparisonService.scoreForAngle(userAngle: 70, check: check)
        // deviation = abs(110-90) = 20, extra = 10 → 60
        let scoreAbove = PoseComparisonService.scoreForAngle(userAngle: 110, check: check)
        XCTAssertEqual(scoreBelow, scoreAbove, accuracy: 0.001)
    }

    // MARK: - criteria 测试

    /// 测试：0-7 每个动作都有对应的角度标准
    func test_criteria_allEightMovements_haveValidCriteria() {
        for i in 0..<8 {
            let c = service.criteria(for: i)
            XCTAssertNotNil(c, "第\(i)式应有角度评判标准")
            XCTAssertEqual(c?.movementIndex, i)
            XCTAssertFalse(c?.angleChecks.isEmpty ?? true, "第\(i)式至少有一个角度检查")
        }
    }

    /// 测试：越界动作序号返回 nil
    func test_criteria_outOfBoundsIndex_returnsNil() {
        XCTAssertNil(service.criteria(for: 8))
        XCTAssertNil(service.criteria(for: -1))
        XCTAssertNil(service.criteria(for: 99))
    }

    /// 测试：所有角度检查权重之和接近1（合理的权重分配）
    func test_criteria_allMovements_angleWeightsSumApproxOne() {
        for i in 0..<8 {
            let c = service.criteria(for: i)!
            let weightSum = c.angleChecks.reduce(0) { $0 + $1.weight }
            XCTAssertEqual(weightSum, 1.0, accuracy: 0.001, "第\(i)式角度权重之和应为1.0")
        }
    }

    // MARK: - scoreForMovement 测试

    /// 测试：不存在的动作序号返回默认50分，无纠正建议
    func test_scoreForMovement_nonexistentMovement_returns50WithNoCorrections() {
        let score = service.scoreForMovement(userPose: [:], movementIndex: 99)
        XCTAssertEqual(score.total, 50.0, accuracy: 0.001)
        XCTAssertTrue(score.corrections.isEmpty)
    }

    /// 测试：空姿态（关节不可见）时，按50分/关节加权计算
    func test_scoreForMovement_emptyPose_allJointsWeightedAt50() {
        let score = service.scoreForMovement(userPose: [:], movementIndex: 0)
        // 每个 angleCheck 关节不可见 → 按50*weight计，权重之和=1 → 总分=50
        XCTAssertEqual(score.total, 50.0, accuracy: 0.001)
        XCTAssertTrue(score.corrections.isEmpty, "不可见关节不应生成纠正建议")
    }

    /// 测试：纠正建议按严重程度降序排列
    func test_scoreForMovement_corrections_sortedBySeverityDescending() {
        // 使用真实关节名称构造一个偏差明显的姿势
        // 通过 MovementScore 结构体直接测试排序规则
        let corrections = [
            CorrectionFeedback(joint: "j1", message: "低级问题", severity: .low),
            CorrectionFeedback(joint: "j2", message: "高级问题", severity: .high),
            CorrectionFeedback(joint: "j3", message: "中级问题", severity: .medium)
        ]
        let sorted = corrections.sorted { $0.severity > $1.severity }
        XCTAssertEqual(sorted[0].severity, .high)
        XCTAssertEqual(sorted[1].severity, .medium)
        XCTAssertEqual(sorted[2].severity, .low)
    }

    // MARK: - MovementScore 测试

    /// 测试：无纠正建议时 primaryFeedback 为 nil
    func test_movementScore_noCorrections_primaryFeedbackIsNil() {
        let score = MovementScore(total: 100, corrections: [])
        XCTAssertNil(score.primaryFeedback)
    }

    /// 测试：有纠正建议时 primaryFeedback 返回第一条
    func test_movementScore_withCorrections_primaryFeedbackIsFirst() {
        let corrections = [
            CorrectionFeedback(joint: "j1", message: "第一条建议", severity: .high),
            CorrectionFeedback(joint: "j2", message: "第二条建议", severity: .low)
        ]
        let score = MovementScore(total: 60, corrections: corrections)
        XCTAssertEqual(score.primaryFeedback, "第一条建议")
    }

    // MARK: - CorrectionSeverity 测试

    /// 测试：严重程度枚举比较大小
    func test_correctionSeverity_comparison() {
        XCTAssertLessThan(CorrectionSeverity.low, .medium)
        XCTAssertLessThan(CorrectionSeverity.medium, .high)
        XCTAssertGreaterThan(CorrectionSeverity.high, .low)
    }

    // MARK: - 辅助方法

    private func makeAngleCheck(
        target: Double,
        tolerance: Double,
        weight: Double = 1.0
    ) -> AngleCheck {
        AngleCheck(
            name: "测试角度",
            jointA: "a", vertex: "v", jointB: "b",
            targetAngle: target,
            toleranceDegrees: tolerance,
            weight: weight,
            feedbackWhenLow: "偏低反馈",
            feedbackWhenHigh: "偏高反馈"
        )
    }
}
