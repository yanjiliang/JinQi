// PracticeSession.swift
// 养生八段锦 iPad App - 练习记录数据模型

import SwiftData
import Foundation

/// 一次完整的八段锦练习记录
@Model
final class PracticeSession {
    // MARK: - 主键
    @Attribute(.unique) var id: UUID

    // MARK: - 时间字段
    var startTime: Date       // 练习开始时间
    var endTime: Date         // 练习结束时间
    var duration: TimeInterval // 实际练习时长（秒）

    // MARK: - 评分字段
    var totalScore: Double    // 总评分（0-100）
    var grade: String         // 等级："优秀"|"良好"|"及格"|"需加强"

    // MARK: - 关系
    @Relationship(deleteRule: .cascade, inverse: \MovementResult.session)
    var movementResults: [MovementResult] = []

    // MARK: - 派生属性（不存储）
    var dateOnly: Date {
        Calendar.current.startOfDay(for: startTime)
    }

    // MARK: - 初始化
    init(id: UUID = UUID(),
         startTime: Date,
         endTime: Date,
         duration: TimeInterval,
         totalScore: Double,
         grade: String) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.totalScore = totalScore
        self.grade = grade
    }
}

// MARK: - 辅助方法
extension PracticeSession {
    /// 格式化练习时长
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)分\(seconds)秒"
    }

    /// 等级对应颜色（十六进制）
    var gradeColorHex: String {
        switch grade {
        case "优秀": return "#FFD700"
        case "良好": return "#4CAF50"
        case "及格": return "#2196F3"
        default:    return "#FF9800"
        }
    }
}
