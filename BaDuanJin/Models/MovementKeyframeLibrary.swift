// MovementKeyframeLibrary.swift
// 锦气 JinQi — 动画关键帧加载器

import Foundation
import Vision

/// 动画关键帧加载器（单例）
class MovementKeyframeLibrary {
    static let shared = MovementKeyframeLibrary()

    private(set) var keyframeSets: [MovementKeyframeSet] = []

    private init() {
        loadKeyframes()
    }

    private func loadKeyframes() {
        guard let url = Bundle.main.url(forResource: "animation_keyframes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        keyframeSets = (try? JSONDecoder().decode([MovementKeyframeSet].self, from: data)) ?? []
    }

    /// 获取指定动作的关键帧
    func keyframes(for movementIndex: Int) -> MovementKeyframeSet? {
        keyframeSets.first { $0.id == movementIndex }
    }

    // MARK: - JointPosition 数组 → PoseFrame joints 字典

    static func toPoseJoints(_ positions: [JointPosition]) -> [VNHumanBodyPoseObservation.JointName: CGPoint] {
        var dict: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
        for pos in positions {
            let key = VNHumanBodyPoseObservation.JointName(rawValue: VNRecognizedPointKey(rawValue: pos.jointName))
            dict[key] = CGPoint(x: pos.x, y: pos.y)
        }
        return dict
    }

    // MARK: - 水平镜像（左右互换）

    /// 用于 hasSides 动作，镜像关节位置以展示另一侧
    static func mirrored(_ positions: [JointPosition]) -> [JointPosition] {
        // 左右关节名映射
        let swapMap: [String: String] = [
            "left_shoulder_1_joint": "right_shoulder_1_joint",
            "right_shoulder_1_joint": "left_shoulder_1_joint",
            "left_forearm_joint": "right_forearm_joint",
            "right_forearm_joint": "left_forearm_joint",
            "left_hand_joint": "right_hand_joint",
            "right_hand_joint": "left_hand_joint",
            "left_upLeg_joint": "right_upLeg_joint",
            "right_upLeg_joint": "left_upLeg_joint",
            "left_leg_joint": "right_leg_joint",
            "right_leg_joint": "left_leg_joint",
            "left_foot_joint": "right_foot_joint",
            "right_foot_joint": "left_foot_joint",
        ]

        return positions.map { pos in
            let mirroredName = swapMap[pos.jointName] ?? pos.jointName
            return JointPosition(jointName: mirroredName, x: 1.0 - pos.x, y: pos.y)
        }
    }

    // MARK: - 两帧之间线性插值

    static func interpolate(from: [JointPosition], to: [JointPosition], progress: CGFloat) -> [JointPosition] {
        let toDict = Dictionary(uniqueKeysWithValues: to.map { ($0.jointName, $0) })
        return from.compactMap { fromPos in
            guard let toPos = toDict[fromPos.jointName] else { return fromPos }
            let x = fromPos.x + (toPos.x - fromPos.x) * progress
            let y = fromPos.y + (toPos.y - fromPos.y) * progress
            return JointPosition(jointName: fromPos.jointName, x: x, y: y)
        }
    }
}
