// MovementResult.swift
// 养生八段锦 iPad App - 单动作练习结果模型

import SwiftData
import Foundation

/// 八段锦单个动作的练习结果
@Model
final class MovementResult {
    // MARK: - 主键
    @Attribute(.unique) var id: UUID

    // MARK: - 关联
    var session: PracticeSession?  // 所属练习记录

    // MARK: - 动作信息
    var movementIndex: Int         // 动作序号（0-7）
    var movementName: String       // 动作名称（冗余存储，便于查询）

    // MARK: - 评分信息
    var score: Double              // 单动作评分（0-100）
    var feedback: String           // 主要改进建议（单条，可为空串""）

    // MARK: - 详情数据
    @Attribute(.externalStorage)
    var keyPointsData: Data?       // JSON，角度评分详情（大数据外部存储）

    // MARK: - 初始化
    init(id: UUID = UUID(),
         movementIndex: Int,
         movementName: String,
         score: Double,
         feedback: String,
         keyPointsData: Data? = nil) {
        self.id = id
        self.movementIndex = movementIndex
        self.movementName = movementName
        self.score = score
        self.feedback = feedback
        self.keyPointsData = keyPointsData
    }
}

// MARK: - keyPointsData JSON 结构
/// 角度评分详情（存入 keyPointsData）
struct AngleScoreDetail: Codable {
    let name: String           // 角度名称
    let userAngle: Double      // 用户实测角度
    let targetAngle: Double    // 标准角度
    let score: Double          // 该角度得分
}

struct MovementKeyPointsData: Codable {
    let angleScores: [AngleScoreDetail]
    let sampleFrameCount: Int
    let detectionConfidence: Double
}
