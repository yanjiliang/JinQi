// PoseAnalyzer.swift
// 养生八段锦 iPad App - 姿态分析器（汇总多帧数据，生成动作评分）

import Vision
import Foundation

// MARK: - 分析状态
enum AnalyzerState {
    case idle                    // 未开始
    case collecting              // 收集帧数据中（保持阶段）
    case completed(Double)       // 分析完成，返回得分
}

// MARK: - 姿态分析器
class PoseAnalyzer {
    // MARK: - 依赖
    private let comparisonService: PoseComparisonService

    // MARK: - 内部状态
    private var collectedFrames: [PoseFrame] = []
    private(set) var state: AnalyzerState = .idle

    // 当前分析的动作序号
    private var currentMovementIndex: Int = 0

    init(comparisonService: PoseComparisonService) {
        self.comparisonService = comparisonService
    }

    // MARK: - 开始收集新动作帧数据
    func beginCollection(for movementIndex: Int) {
        currentMovementIndex = movementIndex
        collectedFrames = []
        state = .collecting
    }

    // MARK: - 添加一帧数据（只在姿态合格时调用）
    func addFrame(_ frame: PoseFrame) {
        guard case .collecting = state else { return }
        collectedFrames.append(frame)
    }

    // MARK: - 完成收集并计算最终得分
    func finishCollection() -> Double {
        guard case .collecting = state else { return 50.0 }

        let score = calculateMovementScore()
        state = .completed(score)
        return score
    }

    // MARK: - 重置状态
    func reset() {
        collectedFrames = []
        state = .idle
    }

    // MARK: - 计算动作得分（多帧平均，去除极端值）
    private func calculateMovementScore() -> Double {
        // 过滤低置信度帧
        let validFrames = collectedFrames.filter { $0.overallConfidence > 0.3 }

        guard !validFrames.isEmpty else {
            return 50.0  // 无有效帧给默认分
        }

        // 每帧计算得分
        let frameScores = validFrames.map { frame -> Double in
            comparisonService.scoreForMovement(
                userPose: frame.joints,
                movementIndex: currentMovementIndex
            ).total
        }

        // 去除最高最低各10%后取平均（移动平均）
        let sorted = frameScores.sorted()
        let trimCount = max(0, sorted.count / 10)
        let trimmed = Array(sorted.dropFirst(trimCount).dropLast(trimCount))

        if trimmed.isEmpty {
            return frameScores.reduce(0, +) / Double(frameScores.count)
        } else {
            return trimmed.reduce(0, +) / Double(trimmed.count)
        }
    }

    // MARK: - 生成该动作的主要反馈（用于存储）
    func generatePrimaryFeedback() -> String {
        guard !collectedFrames.isEmpty else { return "" }

        // 取最近几帧中最常见的反馈
        let recentFrames = collectedFrames.suffix(10)
        var feedbackCount: [String: Int] = [:]

        for frame in recentFrames {
            let result = comparisonService.scoreForMovement(
                userPose: frame.joints,
                movementIndex: currentMovementIndex
            )
            if let primary = result.primaryFeedback {
                feedbackCount[primary, default: 0] += 1
            }
        }

        return feedbackCount.max(by: { $0.value < $1.value })?.key ?? ""
    }

    // MARK: - 生成 keyPointsData（详细角度记录，用于存储）
    func generateKeyPointsData() -> Data? {
        guard let lastFrame = collectedFrames.last else { return nil }

        let result = comparisonService.scoreForMovement(
            userPose: lastFrame.joints,
            movementIndex: currentMovementIndex
        )

        // 构建简化的 keyPointsData
        let keyData = MovementKeyPointsData(
            angleScores: [],  // 完整实现时可从 result 提取
            sampleFrameCount: collectedFrames.count,
            detectionConfidence: Double(collectedFrames.map { $0.overallConfidence }.reduce(0, +) / Float(collectedFrames.count))
        )

        return try? JSONEncoder().encode(keyData)
    }
}
