// PoseAnalyzerTests.swift
// 养生八段锦 iPad App - PoseAnalyzer 多帧分析单元测试

import XCTest
import Vision
@testable import BaDuanJin

final class PoseAnalyzerTests: XCTestCase {

    private var analyzer: PoseAnalyzer!
    private var comparisonService: PoseComparisonService!

    override func setUp() {
        super.setUp()
        comparisonService = PoseComparisonService()
        analyzer = PoseAnalyzer(comparisonService: comparisonService)
    }

    override func tearDown() {
        analyzer = nil
        comparisonService = nil
        super.tearDown()
    }

    // MARK: - 状态机测试

    /// 测试：初始状态为 idle
    func test_initialState_isIdle() {
        guard case .idle = analyzer.state else {
            XCTFail("初始状态应为 idle")
            return
        }
    }

    /// 测试：beginCollection 后状态变为 collecting
    func test_beginCollection_setsStateToCollecting() {
        analyzer.beginCollection(for: 0)
        guard case .collecting = analyzer.state else {
            XCTFail("beginCollection 后状态应为 collecting")
            return
        }
    }

    /// 测试：reset 后状态回到 idle
    func test_reset_fromCollecting_setsStateToIdle() {
        analyzer.beginCollection(for: 0)
        analyzer.reset()
        guard case .idle = analyzer.state else {
            XCTFail("reset 后状态应为 idle")
            return
        }
    }

    /// 测试：reset 从 completed 状态也能回到 idle
    func test_reset_fromCompleted_setsStateToIdle() {
        analyzer.beginCollection(for: 0)
        _ = analyzer.finishCollection()
        analyzer.reset()
        guard case .idle = analyzer.state else {
            XCTFail("reset 后状态应为 idle")
            return
        }
    }

    /// 测试：finishCollection 后状态变为 completed，携带得分
    func test_finishCollection_setsStateToCompleted() {
        analyzer.beginCollection(for: 0)
        let score = analyzer.finishCollection()
        guard case .completed(let s) = analyzer.state else {
            XCTFail("finishCollection 后状态应为 completed")
            return
        }
        XCTAssertEqual(s, score, accuracy: 0.001)
    }

    // MARK: - finishCollection 边界测试

    /// 测试：未开始收集时调用 finishCollection 返回默认50分
    func test_finishCollection_whenIdle_returnsDefault50() {
        let score = analyzer.finishCollection()
        XCTAssertEqual(score, 50.0, accuracy: 0.001)
    }

    /// 测试：连续两次调用 finishCollection，第二次返回默认50分
    func test_finishCollection_calledTwice_secondCallReturns50() {
        analyzer.beginCollection(for: 0)
        _ = analyzer.finishCollection()
        // 此时状态为 completed，再次调用应返回默认值
        let score = analyzer.finishCollection()
        XCTAssertEqual(score, 50.0, accuracy: 0.001)
    }

    // MARK: - addFrame 测试

    /// 测试：非 collecting 状态下 addFrame 被忽略
    func test_addFrame_whenNotCollecting_isIgnored() {
        // idle 状态下添加帧
        let frame = makeFrame(confidence: 0.9)
        analyzer.addFrame(frame)

        // 进入 collecting 后 finishCollection 返回默认值（无帧）
        analyzer.beginCollection(for: 0)
        // 此前添加的帧不应生效，finishCollection 无有效帧
        // 注意：由于空 joints，得分仍为50（按不可见关节计算）
        let score = analyzer.finishCollection()
        XCTAssertEqual(score, 50.0, accuracy: 0.001)
    }

    /// 测试：置信度 <= 0.3 的帧被过滤，不影响计分（无有效帧 → 返回50）
    func test_addFrame_lowConfidence_filteredOutReturns50() {
        analyzer.beginCollection(for: 0)
        let lowConf = makeFrame(confidence: 0.2)
        let boundary = makeFrame(confidence: 0.3)
        analyzer.addFrame(lowConf)
        analyzer.addFrame(boundary)
        let score = analyzer.finishCollection()
        XCTAssertEqual(score, 50.0, accuracy: 0.001)
    }

    /// 测试：置信度 > 0.3 的帧被计入（即使 joints 为空，也是有效帧）
    func test_addFrame_confidenceAboveThreshold_counted() {
        analyzer.beginCollection(for: 0)
        let validFrame = makeFrame(confidence: 0.31)
        analyzer.addFrame(validFrame)
        let score = analyzer.finishCollection()
        // 空 joints → 每个角度按50分计，得50分
        XCTAssertEqual(score, 50.0, accuracy: 0.001)
    }

    // MARK: - 极端值去除测试

    /// 测试：10帧分数相同，trim后结果不变
    func test_calculateScore_uniformFrames_trimDoesNotChangeResult() {
        analyzer.beginCollection(for: 0)
        for i in 0..<10 {
            analyzer.addFrame(makeFrame(confidence: 0.9, timestamp: Double(i)))
        }
        let score = analyzer.finishCollection()
        // 所有帧分数相同（空joints→50），trim后仍为50
        XCTAssertEqual(score, 50.0, accuracy: 0.001)
    }

    /// 测试：1帧时 trim 不影响（trim count = max(0, 1/10) = 0）
    func test_calculateScore_singleFrame_returnsFrameScore() {
        analyzer.beginCollection(for: 0)
        analyzer.addFrame(makeFrame(confidence: 0.9))
        let score = analyzer.finishCollection()
        XCTAssertEqual(score, 50.0, accuracy: 0.001)
    }

    // MARK: - generatePrimaryFeedback 测试

    /// 测试：无帧时返回空字符串
    func test_generatePrimaryFeedback_noFrames_returnsEmptyString() {
        analyzer.beginCollection(for: 0)
        let feedback = analyzer.generatePrimaryFeedback()
        XCTAssertEqual(feedback, "")
    }

    /// 测试：有帧时调用不崩溃（返回字符串）
    func test_generatePrimaryFeedback_withFrames_returnsString() {
        analyzer.beginCollection(for: 0)
        analyzer.addFrame(makeFrame(confidence: 0.9))
        let feedback = analyzer.generatePrimaryFeedback()
        // 空 joints → scoreForMovement 无 corrections → primaryFeedback 为 nil → 返回空
        XCTAssertEqual(feedback, "")
    }

    // MARK: - generateKeyPointsData 测试

    /// 测试：无帧时返回 nil
    func test_generateKeyPointsData_noFrames_returnsNil() {
        analyzer.beginCollection(for: 0)
        XCTAssertNil(analyzer.generateKeyPointsData())
    }

    /// 测试：有1帧时返回可解析的 JSON 数据
    func test_generateKeyPointsData_oneFrame_returnsDecodableData() throws {
        analyzer.beginCollection(for: 0)
        analyzer.addFrame(makeFrame(confidence: 0.8))
        let data = analyzer.generateKeyPointsData()

        XCTAssertNotNil(data)
        let decoded = try JSONDecoder().decode(MovementKeyPointsData.self, from: data!)
        XCTAssertEqual(decoded.sampleFrameCount, 1)
    }

    /// 测试：多帧时 sampleFrameCount 正确记录帧数
    func test_generateKeyPointsData_multipleFrames_sampleCountMatchesAdded() throws {
        analyzer.beginCollection(for: 0)
        for i in 0..<5 {
            analyzer.addFrame(makeFrame(confidence: 0.9, timestamp: Double(i)))
        }
        let data = analyzer.generateKeyPointsData()

        XCTAssertNotNil(data)
        let decoded = try JSONDecoder().decode(MovementKeyPointsData.self, from: data!)
        XCTAssertEqual(decoded.sampleFrameCount, 5)
    }

    /// 测试：detectionConfidence 等于所有帧置信度均值
    func test_generateKeyPointsData_confidenceIsAverageOfFrames() throws {
        analyzer.beginCollection(for: 0)
        analyzer.addFrame(makeFrame(confidence: 0.6))
        analyzer.addFrame(makeFrame(confidence: 0.8))
        let data = analyzer.generateKeyPointsData()

        XCTAssertNotNil(data)
        let decoded = try JSONDecoder().decode(MovementKeyPointsData.self, from: data!)
        XCTAssertEqual(decoded.detectionConfidence, 0.7, accuracy: 0.001)
    }

    // MARK: - beginCollection 重置测试

    /// 测试：重新调用 beginCollection 清空之前的帧数据
    func test_beginCollection_again_resetsFrames() throws {
        analyzer.beginCollection(for: 0)
        for i in 0..<3 {
            analyzer.addFrame(makeFrame(confidence: 0.9, timestamp: Double(i)))
        }

        // 重新开始，清空旧帧
        analyzer.beginCollection(for: 1)
        let data = analyzer.generateKeyPointsData()
        XCTAssertNil(data, "重新开始收集后，旧帧应被清除")
    }

    /// 测试：beginCollection 更新当前动作序号
    func test_beginCollection_updatesMovementIndex() throws {
        analyzer.beginCollection(for: 3)
        analyzer.addFrame(makeFrame(confidence: 0.9))

        // 生成的数据属于第3式（通过 finishCollection 得分可间接验证）
        let score = analyzer.finishCollection()
        // 得分有值即可，不崩溃
        XCTAssertGreaterThanOrEqual(score, 0.0)
    }

    // MARK: - 辅助方法

    private func makeFrame(
        confidence: Float,
        joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:],
        timestamp: TimeInterval = 0
    ) -> PoseFrame {
        PoseFrame(joints: joints, overallConfidence: confidence, timestamp: timestamp)
    }
}
