// MovementResultTests.swift
// 养生八段锦 iPad App - MovementResult 数据模型单元测试

import XCTest
import SwiftData
@testable import BaDuanJin

final class MovementResultTests: XCTestCase {

    // MARK: - SwiftData 内存容器

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: PracticeSession.self, MovementResult.self, UserStats.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - MovementResult 初始化测试

    /// 测试：基本参数初始化时，所有字段正确存储
    func test_init_withBasicParams_storesAllFields() {
        let mr = MovementResult(
            movementIndex: 2,
            movementName: "调理脾胃须单举",
            score: 78.5,
            feedback: "上举手肘部弯曲"
        )

        XCTAssertEqual(mr.movementIndex, 2)
        XCTAssertEqual(mr.movementName, "调理脾胃须单举")
        XCTAssertEqual(mr.score, 78.5, accuracy: 0.001)
        XCTAssertEqual(mr.feedback, "上举手肘部弯曲")
        XCTAssertNil(mr.keyPointsData)
        XCTAssertNil(mr.session)
    }

    /// 测试：省略 id 参数时自动生成 UUID
    func test_init_withoutId_generatesUniqueIds() {
        let mr1 = MovementResult(movementIndex: 0, movementName: "第1式", score: 80, feedback: "")
        let mr2 = MovementResult(movementIndex: 0, movementName: "第1式", score: 80, feedback: "")
        XCTAssertNotEqual(mr1.id, mr2.id)
    }

    /// 测试：指定 id 时使用给定的 UUID
    func test_init_withExplicitId_usesProvidedId() {
        let id = UUID()
        let mr = MovementResult(id: id, movementIndex: 0, movementName: "第1式", score: 90, feedback: "")
        XCTAssertEqual(mr.id, id)
    }

    /// 测试：空 feedback 字符串正确存储
    func test_init_withEmptyFeedback_storesEmptyString() {
        let mr = MovementResult(movementIndex: 0, movementName: "双手托天理三焦", score: 95, feedback: "")
        XCTAssertEqual(mr.feedback, "")
    }

    /// 测试：边界分数0分
    func test_init_scoreZero_storesZero() {
        let mr = MovementResult(movementIndex: 7, movementName: "背后七颠百病消", score: 0, feedback: "需要更多练习")
        XCTAssertEqual(mr.score, 0.0, accuracy: 0.001)
    }

    /// 测试：边界分数100分
    func test_init_scoreHundred_storesHundred() {
        let mr = MovementResult(movementIndex: 7, movementName: "背后七颠百病消", score: 100, feedback: "")
        XCTAssertEqual(mr.score, 100.0, accuracy: 0.001)
    }

    /// 测试：movementIndex 边界值（0-7）
    func test_init_movementIndexRange_allValid() {
        for i in 0..<8 {
            let mr = MovementResult(movementIndex: i, movementName: "第\(i+1)式", score: 80, feedback: "")
            XCTAssertEqual(mr.movementIndex, i)
        }
    }

    // MARK: - keyPointsData 测试

    /// 测试：传入 keyPointsData 时正确存储
    func test_init_withKeyPointsData_storesData() throws {
        let keyData = MovementKeyPointsData(
            angleScores: [],
            sampleFrameCount: 30,
            detectionConfidence: 0.85
        )
        let encoded = try JSONEncoder().encode(keyData)

        let mr = MovementResult(movementIndex: 0, movementName: "第1式", score: 90, feedback: "", keyPointsData: encoded)
        XCTAssertNotNil(mr.keyPointsData)
    }

    // MARK: - AngleScoreDetail 编解码测试

    /// 测试：AngleScoreDetail 编码解码后数据一致
    func test_angleScoreDetail_encodeAndDecode_roundTrips() throws {
        let detail = AngleScoreDetail(name: "左臂上举角度", userAngle: 155.0, targetAngle: 170.0, score: 85.0)
        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(AngleScoreDetail.self, from: data)

        XCTAssertEqual(decoded.name, detail.name)
        XCTAssertEqual(decoded.userAngle, detail.userAngle, accuracy: 0.001)
        XCTAssertEqual(decoded.targetAngle, detail.targetAngle, accuracy: 0.001)
        XCTAssertEqual(decoded.score, detail.score, accuracy: 0.001)
    }

    /// 测试：边界值 userAngle=0 可正常编解码
    func test_angleScoreDetail_zeroAngle_encodesCorrectly() throws {
        let detail = AngleScoreDetail(name: "测试角度", userAngle: 0.0, targetAngle: 0.0, score: 100.0)
        let data = try JSONEncoder().encode(detail)
        let decoded = try JSONDecoder().decode(AngleScoreDetail.self, from: data)
        XCTAssertEqual(decoded.userAngle, 0.0, accuracy: 0.001)
    }

    // MARK: - MovementKeyPointsData 编解码测试

    /// 测试：包含角度详情的 MovementKeyPointsData 编解码后数据一致
    func test_movementKeyPointsData_withAngles_roundTrips() throws {
        let keyData = MovementKeyPointsData(
            angleScores: [
                AngleScoreDetail(name: "角度A", userAngle: 90.0, targetAngle: 95.0, score: 92.0),
                AngleScoreDetail(name: "角度B", userAngle: 170.0, targetAngle: 170.0, score: 100.0)
            ],
            sampleFrameCount: 30,
            detectionConfidence: 0.87
        )
        let data = try JSONEncoder().encode(keyData)
        let decoded = try JSONDecoder().decode(MovementKeyPointsData.self, from: data)

        XCTAssertEqual(decoded.sampleFrameCount, 30)
        XCTAssertEqual(decoded.detectionConfidence, 0.87, accuracy: 0.001)
        XCTAssertEqual(decoded.angleScores.count, 2)
        XCTAssertEqual(decoded.angleScores[0].name, "角度A")
    }

    /// 测试：空角度列表的 MovementKeyPointsData 编解码
    func test_movementKeyPointsData_emptyAngles_roundTrips() throws {
        let keyData = MovementKeyPointsData(angleScores: [], sampleFrameCount: 0, detectionConfidence: 0)
        let data = try JSONEncoder().encode(keyData)
        let decoded = try JSONDecoder().decode(MovementKeyPointsData.self, from: data)
        XCTAssertTrue(decoded.angleScores.isEmpty)
        XCTAssertEqual(decoded.sampleFrameCount, 0)
    }

    /// 测试：detectionConfidence 边界值（0.0 ~ 1.0）
    func test_movementKeyPointsData_confidenceBoundaries_preservedInCoding() throws {
        let lowConf = MovementKeyPointsData(angleScores: [], sampleFrameCount: 1, detectionConfidence: 0.0)
        let highConf = MovementKeyPointsData(angleScores: [], sampleFrameCount: 1, detectionConfidence: 1.0)

        let lowData = try JSONEncoder().encode(lowConf)
        let highData = try JSONEncoder().encode(highConf)

        let decodedLow = try JSONDecoder().decode(MovementKeyPointsData.self, from: lowData)
        let decodedHigh = try JSONDecoder().decode(MovementKeyPointsData.self, from: highData)

        XCTAssertEqual(decodedLow.detectionConfidence, 0.0, accuracy: 0.001)
        XCTAssertEqual(decodedHigh.detectionConfidence, 1.0, accuracy: 0.001)
    }

    // MARK: - SwiftData 持久化测试

    /// 测试：MovementResult 可以插入并关联到 PracticeSession
    func test_insertWithSession_associationPersists() throws {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 300, totalScore: 85, grade: "良好")
        let mr = MovementResult(movementIndex: 0, movementName: "双手托天理三焦", score: 85, feedback: "")
        mr.session = session
        session.movementResults.append(mr)

        context.insert(session)
        context.insert(mr)
        try context.save()

        let descriptor = FetchDescriptor<MovementResult>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.movementName, "双手托天理三焦")
    }

    /// 测试：8个 MovementResult 均可存储
    func test_insertAllEightMovements_allPersist() throws {
        let session = PracticeSession(startTime: Date(), endTime: Date(), duration: 600, totalScore: 80, grade: "良好")
        context.insert(session)

        for i in 0..<8 {
            let mr = MovementResult(movementIndex: i, movementName: "第\(i+1)式", score: Double(i * 10 + 20), feedback: "")
            mr.session = session
            context.insert(mr)
        }
        try context.save()

        let descriptor = FetchDescriptor<MovementResult>()
        let fetched = try context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 8)
    }
}
