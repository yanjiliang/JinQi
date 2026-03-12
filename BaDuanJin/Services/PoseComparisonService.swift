// PoseComparisonService.swift
// 养生八段锦 iPad App - 姿态对比服务（用户姿态 vs 标准姿态）

import Vision
import Foundation

// MARK: - 角度检查定义
struct AngleCheck: Codable {
    let name: String              // 如 "左臂上举角度"
    let jointA: String            // 起点关节名
    let vertex: String            // 顶点关节名
    let jointB: String            // 终点关节名
    let targetAngle: Double       // 标准角度（度）
    let toleranceDegrees: Double  // 允许偏差范围（度）
    let weight: Double            // 该角度在总分中的权重
    let feedbackWhenLow: String   // 角度偏小时的提示
    let feedbackWhenHigh: String  // 角度偏大时的提示
}

// MARK: - 动作角度标准
struct MovementAngleCriteria: Codable {
    let movementIndex: Int
    let movementName: String
    let angleChecks: [AngleCheck]
}

// MARK: - 纠正反馈严重程度
enum CorrectionSeverity: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: CorrectionSeverity, rhs: CorrectionSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 单条纠正反馈
struct CorrectionFeedback {
    let joint: String           // 相关关节
    let message: String         // 提示文字
    let severity: CorrectionSeverity
}

// MARK: - 动作评分结果
struct MovementScore {
    let total: Double                      // 总分（0-100）
    let corrections: [CorrectionFeedback]  // 纠正建议（按严重程度排序）

    var primaryFeedback: String? {
        corrections.first?.message
    }
}

// MARK: - 姿态对比服务
class PoseComparisonService {
    // MARK: - 内置角度标准数据（8式）
    private let criteriaList: [MovementAngleCriteria]

    init() {
        criteriaList = Self.buildDefaultCriteria()
    }

    // MARK: - 获取指定动作的角度标准
    func criteria(for movementIndex: Int) -> MovementAngleCriteria? {
        criteriaList.first { $0.movementIndex == movementIndex }
    }

    // MARK: - 计算两向量夹角（度）
    static func angleBetween(pointA: CGPoint, vertex: CGPoint, pointB: CGPoint) -> Double {
        let vectorAX = Double(pointA.x - vertex.x)
        let vectorAY = Double(pointA.y - vertex.y)
        let vectorBX = Double(pointB.x - vertex.x)
        let vectorBY = Double(pointB.y - vertex.y)

        let dot = vectorAX * vectorBX + vectorAY * vectorBY
        let magA = sqrt(vectorAX * vectorAX + vectorAY * vectorAY)
        let magB = sqrt(vectorBX * vectorBX + vectorBY * vectorBY)

        guard magA > 0, magB > 0 else { return 0 }
        let cosAngle = max(-1.0, min(1.0, dot / (magA * magB)))
        return acos(cosAngle) * 180 / .pi
    }

    // MARK: - 单角度评分（0-100）
    static func scoreForAngle(userAngle: Double, check: AngleCheck) -> Double {
        let deviation = abs(userAngle - check.targetAngle)

        if deviation <= check.toleranceDegrees {
            // 在容差范围内：线性映射到 80-100 分
            let ratio = deviation / check.toleranceDegrees
            return 100 - ratio * 20
        } else {
            // 超出容差：每多1度扣2分，最低20分
            let extra = deviation - check.toleranceDegrees
            return max(20, 80 - extra * 2)
        }
    }

    // MARK: - 单帧动作评分
    func scoreForMovement(userPose: [VNHumanBodyPoseObservation.JointName: CGPoint],
                          movementIndex: Int) -> MovementScore {
        guard let criteria = criteria(for: movementIndex) else {
            return MovementScore(total: 50, corrections: [])
        }

        var weightedScore = 0.0
        var corrections: [CorrectionFeedback] = []

        for check in criteria.angleChecks {
            let jointAName = VNHumanBodyPoseObservation.JointName(rawValue: VNRecognizedPointKey(rawValue: check.jointA))
            let vertexName = VNHumanBodyPoseObservation.JointName(rawValue: VNRecognizedPointKey(rawValue: check.vertex))
            let jointBName = VNHumanBodyPoseObservation.JointName(rawValue: VNRecognizedPointKey(rawValue: check.jointB))
            guard let pointA = userPose[jointAName],
                  let vertexPoint = userPose[vertexName],
                  let pointB = userPose[jointBName] else {
                // 关节不可见：该角度按50分计
                weightedScore += 50 * check.weight
                continue
            }

            let userAngle = Self.angleBetween(pointA: pointA, vertex: vertexPoint, pointB: pointB)
            let score = Self.scoreForAngle(userAngle: userAngle, check: check)
            weightedScore += score * check.weight

            // 生成纠正反馈（分数低于75时）
            if score < 75 {
                let message = userAngle < check.targetAngle
                    ? check.feedbackWhenLow
                    : check.feedbackWhenHigh
                corrections.append(CorrectionFeedback(
                    joint: check.vertex,
                    message: message,
                    severity: score < 50 ? .high : .medium
                ))
            }
        }

        return MovementScore(
            total: weightedScore,
            corrections: corrections.sorted { $0.severity > $1.severity }
        )
    }

    // MARK: - 内置8式角度标准数据
    private static func buildDefaultCriteria() -> [MovementAngleCriteria] {
        return [
            // 第1式 双手托天理三焦
            MovementAngleCriteria(
                movementIndex: 0,
                movementName: "双手托天理三焦",
                angleChecks: [
                    AngleCheck(
                        name: "左臂上举角度",
                        jointA: "left_elbow_joint", vertex: "left_shoulder_1_joint", jointB: "left_upLeg_joint",
                        targetAngle: 170, toleranceDegrees: 20, weight: 0.25,
                        feedbackWhenLow: "请将左臂继续向上举高",
                        feedbackWhenHigh: "左臂不必过度后仰，保持竖直向上"
                    ),
                    AngleCheck(
                        name: "右臂上举角度",
                        jointA: "right_elbow_joint", vertex: "right_shoulder_1_joint", jointB: "right_upLeg_joint",
                        targetAngle: 170, toleranceDegrees: 20, weight: 0.25,
                        feedbackWhenLow: "请将右臂继续向上举高",
                        feedbackWhenHigh: "右臂不必过度后仰，保持竖直向上"
                    ),
                    AngleCheck(
                        name: "左肘伸直角度",
                        jointA: "left_shoulder_1_joint", vertex: "left_elbow_joint", jointB: "left_wrist_joint",
                        targetAngle: 170, toleranceDegrees: 15, weight: 0.15,
                        feedbackWhenLow: "左肘要伸直，手臂充分延伸",
                        feedbackWhenHigh: "左肘保持自然伸直即可"
                    ),
                    AngleCheck(
                        name: "右肘伸直角度",
                        jointA: "right_shoulder_1_joint", vertex: "right_elbow_joint", jointB: "right_wrist_joint",
                        targetAngle: 170, toleranceDegrees: 15, weight: 0.15,
                        feedbackWhenLow: "右肘要伸直，手臂充分延伸",
                        feedbackWhenHigh: "右肘保持自然伸直即可"
                    ),
                    AngleCheck(
                        name: "背部挺直角度",
                        jointA: "neck_1_joint", vertex: "root", jointB: "left_upLeg_joint",
                        targetAngle: 175, toleranceDegrees: 10, weight: 0.20,
                        feedbackWhenLow: "请挺胸收腹，保持脊柱直立",
                        feedbackWhenHigh: "腰部不要过度后仰"
                    )
                ]
            ),
            // 第2式 左右开弓似射雕
            MovementAngleCriteria(
                movementIndex: 1,
                movementName: "左右开弓似射雕",
                angleChecks: [
                    AngleCheck(
                        name: "弓拉手肘角度",
                        jointA: "left_shoulder_1_joint", vertex: "left_elbow_joint", jointB: "left_wrist_joint",
                        targetAngle: 90, toleranceDegrees: 20, weight: 0.30,
                        feedbackWhenLow: "弓拉手肘部弯曲不够，用力向后拉",
                        feedbackWhenHigh: "弓拉手肘不必弯曲过多"
                    ),
                    AngleCheck(
                        name: "射箭手伸直角度",
                        jointA: "right_shoulder_1_joint", vertex: "right_elbow_joint", jointB: "right_wrist_joint",
                        targetAngle: 170, toleranceDegrees: 15, weight: 0.30,
                        feedbackWhenLow: "射箭手要充分伸直，指向远方",
                        feedbackWhenHigh: "射箭手保持自然伸直即可"
                    ),
                    AngleCheck(
                        name: "马步膝关节角度",
                        jointA: "left_upLeg_joint", vertex: "left_leg_joint", jointB: "left_foot_joint",
                        targetAngle: 100, toleranceDegrees: 20, weight: 0.40,
                        feedbackWhenLow: "马步要更低，膝盖弯曲约90度",
                        feedbackWhenHigh: "马步不必蹲太低"
                    )
                ]
            ),
            // 第3式 调理脾胃须单举
            MovementAngleCriteria(
                movementIndex: 2,
                movementName: "调理脾胃须单举",
                angleChecks: [
                    AngleCheck(
                        name: "上举手臂角度",
                        jointA: "left_elbow_joint", vertex: "left_shoulder_1_joint", jointB: "left_upLeg_joint",
                        targetAngle: 170, toleranceDegrees: 20, weight: 0.35,
                        feedbackWhenLow: "上举手要继续往上举，尽量贴近耳朵",
                        feedbackWhenHigh: "上举手保持竖直向上即可"
                    ),
                    AngleCheck(
                        name: "上举手肘伸直",
                        jointA: "left_shoulder_1_joint", vertex: "left_elbow_joint", jointB: "left_wrist_joint",
                        targetAngle: 170, toleranceDegrees: 15, weight: 0.25,
                        feedbackWhenLow: "上举手肘部要伸直",
                        feedbackWhenHigh: "手肘保持自然伸直"
                    ),
                    AngleCheck(
                        name: "下按手位置",
                        jointA: "right_elbow_joint", vertex: "right_shoulder_1_joint", jointB: "right_upLeg_joint",
                        targetAngle: 60, toleranceDegrees: 20, weight: 0.25,
                        feedbackWhenLow: "下按手用力向下按，掌心朝下",
                        feedbackWhenHigh: "下按手保持用力下按姿势"
                    ),
                    AngleCheck(
                        name: "脊柱直立",
                        jointA: "neck_1_joint", vertex: "root", jointB: "left_upLeg_joint",
                        targetAngle: 175, toleranceDegrees: 10, weight: 0.15,
                        feedbackWhenLow: "保持脊柱直立，不要侧弯",
                        feedbackWhenHigh: "保持脊柱直立，不要侧弯"
                    )
                ]
            ),
            // 第4式 五劳七伤往后瞧
            MovementAngleCriteria(
                movementIndex: 3,
                movementName: "五劳七伤往后瞧",
                angleChecks: [
                    AngleCheck(
                        name: "颈部转动角度",
                        jointA: "left_ear_joint", vertex: "neck_1_joint", jointB: "right_ear_joint",
                        targetAngle: 140, toleranceDegrees: 20, weight: 0.50,
                        feedbackWhenLow: "头部转动幅度不够，眼睛尽量看向正后方",
                        feedbackWhenHigh: "头部转动幅度适中，不要强行超范围"
                    ),
                    AngleCheck(
                        name: "肩部水平（不耸肩）",
                        jointA: "left_shoulder_1_joint", vertex: "neck_1_joint", jointB: "right_shoulder_1_joint",
                        targetAngle: 140, toleranceDegrees: 20, weight: 0.30,
                        feedbackWhenLow: "肩膀放松，不要耸肩",
                        feedbackWhenHigh: "肩膀放松，保持水平"
                    ),
                    AngleCheck(
                        name: "脊柱直立",
                        jointA: "neck_1_joint", vertex: "root", jointB: "left_upLeg_joint",
                        targetAngle: 175, toleranceDegrees: 10, weight: 0.20,
                        feedbackWhenLow: "保持脊柱直立，身体不要前倾",
                        feedbackWhenHigh: "保持脊柱直立，不要后仰"
                    )
                ]
            ),
            // 第5式 摇头摆尾去心火
            MovementAngleCriteria(
                movementIndex: 4,
                movementName: "摇头摆尾去心火",
                angleChecks: [
                    AngleCheck(
                        name: "左膝弯曲角度",
                        jointA: "left_upLeg_joint", vertex: "left_leg_joint", jointB: "left_foot_joint",
                        targetAngle: 100, toleranceDegrees: 20, weight: 0.30,
                        feedbackWhenLow: "马步要更低，左膝弯曲约90度",
                        feedbackWhenHigh: "马步不必过低，注意保护膝盖"
                    ),
                    AngleCheck(
                        name: "右膝弯曲角度",
                        jointA: "right_upLeg_joint", vertex: "right_leg_joint", jointB: "right_foot_joint",
                        targetAngle: 100, toleranceDegrees: 20, weight: 0.30,
                        feedbackWhenLow: "马步要更低，右膝弯曲约90度",
                        feedbackWhenHigh: "马步不必过低，注意保护膝盖"
                    ),
                    AngleCheck(
                        name: "上身侧倾角度",
                        jointA: "neck_1_joint", vertex: "root", jointB: "left_upLeg_joint",
                        targetAngle: 155, toleranceDegrees: 20, weight: 0.40,
                        feedbackWhenLow: "上身侧倾幅度不够，随头部倾斜",
                        feedbackWhenHigh: "侧倾幅度适中，保持马步稳定"
                    )
                ]
            ),
            // 第6式 两手攀足固肾腰
            MovementAngleCriteria(
                movementIndex: 5,
                movementName: "两手攀足固肾腰",
                angleChecks: [
                    AngleCheck(
                        name: "弯腰角度（躯干前倾）",
                        jointA: "neck_1_joint", vertex: "root", jointB: "left_upLeg_joint",
                        targetAngle: 60, toleranceDegrees: 20, weight: 0.40,
                        feedbackWhenLow: "继续向前弯腰，双手尽量触碰脚尖",
                        feedbackWhenHigh: "弯腰幅度适中即可"
                    ),
                    AngleCheck(
                        name: "左膝伸直角度",
                        jointA: "left_upLeg_joint", vertex: "left_leg_joint", jointB: "left_foot_joint",
                        targetAngle: 170, toleranceDegrees: 15, weight: 0.30,
                        feedbackWhenLow: "弯腰时膝盖要伸直，感受腿后侧拉伸",
                        feedbackWhenHigh: "膝盖保持伸直即可"
                    ),
                    AngleCheck(
                        name: "右膝伸直角度",
                        jointA: "right_upLeg_joint", vertex: "right_leg_joint", jointB: "right_foot_joint",
                        targetAngle: 170, toleranceDegrees: 15, weight: 0.30,
                        feedbackWhenLow: "弯腰时膝盖要伸直，感受腿后侧拉伸",
                        feedbackWhenHigh: "膝盖保持伸直即可"
                    )
                ]
            ),
            // 第7式 攒拳怒目增气力
            MovementAngleCriteria(
                movementIndex: 6,
                movementName: "攒拳怒目增气力",
                angleChecks: [
                    AngleCheck(
                        name: "出拳手臂伸直",
                        jointA: "left_shoulder_1_joint", vertex: "left_elbow_joint", jointB: "left_wrist_joint",
                        targetAngle: 170, toleranceDegrees: 15, weight: 0.40,
                        feedbackWhenLow: "出拳手要充分伸直，全力前推",
                        feedbackWhenHigh: "手臂保持自然伸直即可"
                    ),
                    AngleCheck(
                        name: "出拳高度（与肩同高）",
                        jointA: "left_elbow_joint", vertex: "left_shoulder_1_joint", jointB: "left_upLeg_joint",
                        targetAngle: 90, toleranceDegrees: 20, weight: 0.30,
                        feedbackWhenLow: "出拳高度不够，拳与肩同高",
                        feedbackWhenHigh: "出拳略微偏高，调整到与肩同高"
                    ),
                    AngleCheck(
                        name: "马步稳定",
                        jointA: "left_upLeg_joint", vertex: "left_leg_joint", jointB: "left_foot_joint",
                        targetAngle: 100, toleranceDegrees: 20, weight: 0.30,
                        feedbackWhenLow: "马步要更低更稳，出拳时下盘稳固",
                        feedbackWhenHigh: "马步保持稳定即可"
                    )
                ]
            ),
            // 第8式 背后七颠百病消
            MovementAngleCriteria(
                movementIndex: 7,
                movementName: "背后七颠百病消",
                angleChecks: [
                    AngleCheck(
                        name: "踝关节上提角度",
                        jointA: "left_leg_joint", vertex: "left_foot_joint", jointB: "left_toes_joint",
                        targetAngle: 130, toleranceDegrees: 20, weight: 0.40,
                        feedbackWhenLow: "踮脚高度不够，脚跟尽量离地",
                        feedbackWhenHigh: "踮脚幅度适中即可"
                    ),
                    AngleCheck(
                        name: "脊柱直立",
                        jointA: "neck_1_joint", vertex: "root", jointB: "left_upLeg_joint",
                        targetAngle: 175, toleranceDegrees: 10, weight: 0.35,
                        feedbackWhenLow: "踮脚时保持脊柱直立，不要前倾",
                        feedbackWhenHigh: "保持脊柱直立，不要后仰"
                    ),
                    AngleCheck(
                        name: "双臂自然下垂",
                        jointA: "left_elbow_joint", vertex: "left_shoulder_1_joint", jointB: "left_upLeg_joint",
                        targetAngle: 10, toleranceDegrees: 20, weight: 0.25,
                        feedbackWhenLow: "手臂自然下垂放松",
                        feedbackWhenHigh: "手臂不必举起，自然下垂即可"
                    )
                ]
            )
        ]
    }
}
