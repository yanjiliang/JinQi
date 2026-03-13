// MovementKeyframes.swift
// 锦气 JinQi — 动作动画关键帧数据模型

import Foundation

/// 单个关节位置（归一化坐标，原点左下角，与 Vision 一致）
struct JointPosition: Codable {
    let jointName: String  // 对应 VNHumanBodyPoseObservation.JointName.rawValue.rawValue
    let x: CGFloat
    let y: CGFloat
}

/// 一步的全身姿态关键帧
struct StepKeyframe: Codable, Identifiable {
    let id: Int               // 对应 MovementStep.order (1-4)
    let joints: [JointPosition]
}

/// 一个动作的全部关键帧（4步）
struct MovementKeyframeSet: Codable, Identifiable {
    let id: Int               // 对应 MovementDefinition.id (0-7)
    let keyframes: [StepKeyframe]
}
